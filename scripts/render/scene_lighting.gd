class_name SceneLighting
extends Node2D

## Smooth light over pixel-art tiles: an ambient across the world canvas and a
## light at each glowing tile near the player. Which tiles glow, and in what colour
## and reach, is data -- a tile's data.light in tiles.json -- not a guess from its
## name. Walls and solid props occlude the light, so a lit room throws shadows past
## its walls. The player carries no light of their own (they don't emit) -- a
## lantern item may add one later.
##
## The UI sits on its own CanvasLayers, so none of it is darkened. Governed by
## the "lighting" graphics setting (Options > Graphics, or F3), on by default.

## Overworld/hub ambient: a daylit scene reads on its own, so this stays high and
## the tile lights are warm ACCENTS over it, not the only illumination. A dark base
## with bright pools reads as a cave -- wrong for a town. Dungeons get the drama via
## DUNGEON_DARKEN. Slight cool tint so the warm candles pop against it.
const AMBIENT := Color(0.78, 0.79, 0.85)
## How much a (non-vault) dungeon drops the ambient below the overworld -- this is
## where real darkness and light-pool contrast belong, not the hub.
const DUNGEON_DARKEN := 0.5
## Additive over the darkened world; a candle reads as a warm pool without
## blowing out the tiles around it.
const TILE_LIGHT_ENERGY := 2.0
## Projectiles whose group carries a data.light get a travelling glow; a small
## pool follows the nearest of them, coloured and sized from that data. Not
## shadow-casting -- a fast mover flickering shadows is noise, and cheaper.
const MAX_BULLET_LIGHTS := 20
const BULLET_LIGHT_ENERGY := 1.6
const MAX_TILE_LIGHTS := 24
## Shadow casting is per-platform (see _shadow_casters): a shadow pass runs per
## caster per frame, so web casts none and native casts from every visible light.
## The merge collapses wall runs into a handful of rects, so this cap is only ever
## approached by a huge open field; 192 covers a native viewport without leaking.
const MAX_OCCLUDERS := 192
## Penumbra width for the PCF13 filter. Wide so a shadow edge fades over many
## pixels into an organic gradient rather than a hard-lined wedge.
const SHADOW_SMOOTH := 11.0
## Shadows are drawn as a translucent WARM dark rather than opaque black, so light
## bleeds through behind an object (it never goes pitch black) and the shaded side
## reads warm and inviting instead of a cold, cut-out silhouette. Lower the alpha
## for even gentler shadows; raise it toward 1.0 for deeper ones.
const SHADOW_COLOR := Color(0.14, 0.11, 0.10, 0.5)
## Tiles do not move, so the view is rescanned every Nth frame, not every frame.
const SCAN_EVERY := 20

var _state: RealmState
var _content: GameData
var _ambient := CanvasModulate.new()
## A viewport glow that blooms only what the HDR 2D buffer lets exceed 1.0 -- the
## additive light pools -- so the candles/torches/glowing shots halo while the
## pixel art under the ambient stays crisp. Held off (environment null) until the
## lighting is live AND the bloom setting is on. (The 3D view runs its own
## glow-less environment on purpose -- full-screen glow hazed its effects.)
var _world_env := WorldEnvironment.new()
var _glow: Environment
var _bloom_active := false
var _pool: Array[PointLight2D] = []
var _bullet_lights: Array[PointLight2D] = []
var _occluders: Array[LightOccluder2D] = []
var _emitters := {}   # GameData.light_emitters(): tile id -> {color, radius, flickers}
var _frames := 0
var _time := 0.0
## Whether the ambient is currently dimmed for a dungeon, so it only re-sets the
## CanvasModulate colour when that changes rather than every frame.
var _dungeon_dark := false
## Web GL-compat can't afford the 2D shadow passes, so on web every light is
## non-casting and no occluders are built (the ambient + additive pools stay).
## Native has the headroom, so it keeps shadows AND runs the glows 50% brighter.
var _web := OS.has_feature("web")
var _tile_energy := TILE_LIGHT_ENERGY
var _bullet_energy := BULLET_LIGHT_ENERGY
## The 2D scan already covers the whole viewport; this is how many of the emitters
## in it get a light. Native lights them all; web keeps the tighter cap.
var _max_tile_lights := MAX_TILE_LIGHTS if OS.has_feature("web") else 64
## How many of the nearest tile lights cast wall shadows. Web: 0 (no shadow passes
## at all). Native: all of them, so a light's occlusion doesn't cut off with range
## -- a distant candle's glow is still blocked by the wall in front of it.
var _shadow_casters := 0 if OS.has_feature("web") else 64
## Native ambient runs 10% brighter (overworld and dungeon alike) than web.
var _ambient_mul := 1.0 if OS.has_feature("web") else 1.1


func setup(state: RealmState, content: GameData) -> void:
	_state = state
	_content = content
	_ambient.color = _ambient_color(false)
	add_child(_ambient)
	_glow = _glow_environment()
	add_child(_world_env)
	var glow_mul := 1.0 if _web else 1.5
	_tile_energy = TILE_LIGHT_ENERGY * glow_mul
	_bullet_energy = BULLET_LIGHT_ENERGY * glow_mul
	var glow := _soft_texture()
	for i in _max_tile_lights:
		var light := PointLight2D.new()
		_light(light, glow, Color.WHITE, _tile_energy, 1.0)
		light.visible = false
		_pool.append(light)
	for i in MAX_BULLET_LIGHTS:
		var light := PointLight2D.new()
		_light(light, glow, Color.WHITE, _bullet_energy, 1.0)
		light.shadow_enabled = false
		light.visible = false
		_bullet_lights.append(light)
	# Occluders only matter for shadow-casting lights, which web has none of.
	if not _web:
		for i in MAX_OCCLUDERS:
			var occluder := LightOccluder2D.new()
			var polygon := OccluderPolygon2D.new()
			polygon.closed = true
			occluder.occluder = polygon
			occluder.visible = false
			_occluders.append(occluder)
			add_child(occluder)


## A shadow-casting point light, added as a child.
func _light(light: PointLight2D, glow: GradientTexture2D, colour: Color, energy: float,
		scale: float) -> void:
	light.texture = glow
	light.color = colour
	light.energy = energy
	light.texture_scale = scale
	light.shadow_enabled = not _web
	if not _web:
		# PCF13 + a wide smooth gives a soft penumbra -- the shadow edge fades and
		# light bleeds gradually behind an object, instead of a hard black wedge. A
		# translucent warm shadow_color keeps the shaded side from going cold-black.
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		light.shadow_filter_smooth = SHADOW_SMOOTH
		light.shadow_color = SHADOW_COLOR
	add_child(light)


func _process(delta: float) -> void:
	var live := _state != null and _state.settings.is_on("lighting") \
		and _state.local != null and _state.tiles.width > 0
	if _ambient.visible != live:
		_ambient.visible = live
		for light in _pool:
			light.visible = false
		for light in _bullet_lights:
			light.visible = false
		for occluder in _occluders:
			occluder.visible = false
		_frames = 0
	if not live:
		_set_bloom(false)
		return
	_set_bloom(_state.settings.is_on("bloom"))
	# Dungeons (not the vault) read a third darker than the overworld.
	var dark := _in_dungeon()
	if dark != _dungeon_dark:
		_dungeon_dark = dark
		_ambient.color = _ambient_color(dark)
	_time += delta
	if _frames % SCAN_EVERY == 0:
		_rescan()
	_frames += 1
	for i in _pool.size():
		var light := _pool[i]
		if light.visible and light.get_meta("flickers", false):
			light.energy = _tile_energy \
				* (1.0 + 0.12 * sin(_time * 9.0 + i * 1.7) + 0.06 * sin(_time * 23.0 + i))
	# Bullets move every frame, so this is not on the tile scan's cadence.
	_place_bullet_lights()


## The nearest light-emitting bullets in flight, one travelling light each,
## coloured and sized from the projectile group's data.light.
func _place_bullet_lights() -> void:
	# Opt-out sub-toggle of Dynamic lighting: skip the travelling bullet glows (and
	# their per-frame scan) when the player turns projectile lighting off.
	if not _state.settings.is_on("projectile_lighting"):
		for light in _bullet_lights:
			light.visible = false
		return
	var found := []
	var centre := _state.local.render_centre()
	for id in _state.projectiles.bullets:
		var bullet: Dictionary = _state.projectiles.bullets[id]
		var light_def := _content.projectile_light(int(bullet.get("group_id", -1)))
		var strength := float(light_def.get("strength", 0.0))
		if strength <= 0.0:
			continue
		var size := float(bullet.get("size", 8))
		var at: Vector2 = bullet["pos"] + Vector2(size, size) * 0.5
		var hex := str(light_def.get("color", "#ffffff"))
		var colour := Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE
		found.append([at.distance_squared_to(centre), at, colour, strength])
	found.sort_custom(_nearer)
	for i in _bullet_lights.size():
		var light := _bullet_lights[i]
		light.visible = i < found.size()
		if light.visible:
			light.position = found[i][1]
			light.color = found[i][2]
			light.texture_scale = _scale_for(found[i][3])


## The glowing tiles in view get a light each (nearest the player first), and the
## walls and solid props an occluder each, so those lights throw shadows.
func _rescan() -> void:
	_emitters = _content.light_emitters()
	var tile := float(GameConstants.TILE_SIZE)
	var solid: Dictionary = _state.tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	var view := ViewRect.of(self)
	var centre := _state.local.render_centre()
	var found := []
	var walls := []
	for y in range(floori(view.position.y / tile), ceili(view.end.y / tile)):
		for x in range(floori(view.position.x / tile), ceili(view.end.x / tile)):
			var cell := Vector2i(x, y)
			for layer in _state.tiles.layers:
				var kind: Variant = _emitters.get(_state.tiles.layers[layer].get(cell, -1))
				if kind != null:
					var at := Vector2(x + 0.5, y + 0.5) * tile
					found.append([at.distance_squared_to(centre), at, kind])
			if not _web and _occludes(solid.get(cell, -1)):
				walls.append(cell)
	found.sort_custom(_nearer)
	for i in _pool.size():
		var light := _pool[i]
		light.visible = i < found.size()
		if light.visible:
			var kind: Dictionary = found[i][2]
			light.position = found[i][1]
			light.color = kind["color"]
			light.texture_scale = _scale_for(kind["radius"])
			light.set_meta("flickers", kind["flickers"])
			light.energy = _tile_energy
			# found is distance-sorted; the nearest _shadow_casters cast (all on native).
			light.shadow_enabled = i < _shadow_casters
	var rects := _merge_wall_rects(walls)
	for i in _occluders.size():
		var occluder := _occluders[i]
		occluder.visible = i < rects.size()
		if occluder.visible:
			var rect: Rect2i = rects[i]
			occluder.position = Vector2(rect.position) * tile
			var wide := float(rect.size.x) * tile
			var tall := float(rect.size.y) * tile
			occluder.occluder.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(wide, 0), Vector2(wide, tall), Vector2(0, tall)])


## Only WALLS cast shadows. Solid decorations (trees, bushes -- hasCollision but
## not isWall) used to occlude too, which threw hard trapezoidal wedge shadows off
## every large tree; the web client casts no object shadows and reads far smoother.
## Now a decoration just gets the soft radial bloom, while walls still block light.
## A tile that emits its own light is never made to shadow itself.
func _occludes(tile_id: int) -> bool:
	return tile_id > 0 and not _emitters.has(tile_id) and _content.tile_is_wall(tile_id)


## The CanvasModulate colour: the base ambient (a third darker in a dungeon),
## scaled by the platform ambient multiplier, alpha kept at 1.
func _ambient_color(dark: bool) -> Color:
	var c := AMBIENT.darkened(DUNGEON_DARKEN) if dark else AMBIENT
	return Color(c.r * _ambient_mul, c.g * _ambient_mul, c.b * _ambient_mul, 1.0)


## In an assembled dungeon that isn't the personal vault -- where the ambient dims.
func _in_dungeon() -> bool:
	return _state.tiles.dungeon_id >= 0 and not _content.maps.is_vault(_state.tiles.map_id)


## Attach or detach the glow environment; a null environment on the WorldEnvironment
## is the off state, so the glow pass only runs while bloom is wanted.
func _set_bloom(on: bool) -> void:
	if on == _bloom_active:
		return
	_bloom_active = on
	_world_env.environment = _glow if on else null


## Glow tuned to bloom only the over-bright light pools: the HDR threshold sits at
## 1.0 so nothing under the ambient (all <= 1.0) blooms, and glow_bloom stays 0 so
## there is no flat haze added to every pixel -- only what the additive lights push
## past 1.0 halos. The mid levels give a soft, wide falloff without a hard ring.
func _glow_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	for level in 7:
		env.set_glow_level(level, 0.0)
	env.set_glow_level(1, 0.4)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	return env


## Distance-first comparator, hoisted so a fresh closure isn't allocated every
## scan and every bullet-light pass.
static func _nearer(a: Array, b: Array) -> bool:
	return a[0] < b[0]


## A light `radius` tiles across its bright half, on the 256px texture.
func _scale_for(radius_tiles: float) -> float:
	return radius_tiles * 2.0 * GameConstants.TILE_SIZE / 256.0


## Contiguous wall/prop cells merged into maximal rectangles, so a wall run casts
## one clean shadow rather than a stripe of per-tile ones -- and a walled room
## fits in a handful of occluders instead of blowing the pool's cap and leaking
## light through the tiles that didn't fit. Cells arrive row-major, so the first
## unclaimed one is always a rectangle's top-left.
func _merge_wall_rects(cells: Array) -> Array:
	var solid := {}
	for cell in cells:
		solid[cell] = true
	var claimed := {}
	var rects := []
	for cell in cells:
		if claimed.has(cell):
			continue
		var wide := 1
		while solid.has(Vector2i(cell.x + wide, cell.y)) \
				and not claimed.has(Vector2i(cell.x + wide, cell.y)):
			wide += 1
		var tall := 1
		while _row_solid(solid, claimed, cell, wide, tall):
			tall += 1
		for dy in tall:
			for dx in wide:
				claimed[Vector2i(cell.x + dx, cell.y + dy)] = true
		rects.append(Rect2i(cell.x, cell.y, wide, tall))
	return rects


func _row_solid(solid: Dictionary, claimed: Dictionary, origin: Vector2i, wide: int, row: int) -> bool:
	for dx in wide:
		var cell := Vector2i(origin.x + dx, origin.y + row)
		if not solid.has(cell) or claimed.has(cell):
			return false
	return true


## White at the centre to nothing at the edge, eased so the fall-off has no
## visible ring.
static func _soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
