class_name SceneLighting
extends Node2D

## Smooth light over pixel-art tiles: a dark ambient across the world canvas, a
## light carried by the player, and one at each glowing tile near it. Which
## tiles glow, and in what colour and reach, is data -- a tile's data.light in
## tiles.json -- not a guess from its name. Walls and solid props occlude the
## light, so a lit room throws shadows past its walls.
##
## The UI sits on its own CanvasLayers, so none of it is darkened. Governed by
## the "lighting" graphics setting (Options > Graphics, or F3), on by default.

const AMBIENT := Color(0.62, 0.64, 0.72)
## Additive over the darkened world; a candle reads as a warm pool without
## blowing out the tiles around it.
const TILE_LIGHT_ENERGY := 2.0
const PLAYER_ENERGY := 1.1
## Projectiles whose group carries a data.light get a travelling glow; a small
## pool follows the nearest of them, coloured and sized from that data. Not
## shadow-casting -- a fast mover flickering shadows is noise, and cheaper.
const MAX_BULLET_LIGHTS := 20
const BULLET_LIGHT_ENERGY := 1.6
const MAX_TILE_LIGHTS := 24
## Only the few nearest tile lights cast shadows -- a shadow pass runs per caster
## per frame, so casting from all 24 is the dominant 2D cost; the eye reads the
## nearest few and the player's own light, not a distant candle's cast shadow.
const TILE_SHADOW_CASTERS := 3
## The merge collapses wall runs into a handful of rects, so this cap is only ever
## approached by a huge open field; 96 covers any room without leaking light.
const MAX_OCCLUDERS := 96
## Tiles do not move, so the view is rescanned every Nth frame, not every frame.
const SCAN_EVERY := 20

var _state: RealmState
var _content: GameData
var _ambient := CanvasModulate.new()
var _player := PointLight2D.new()
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


func setup(state: RealmState, content: GameData) -> void:
	_state = state
	_content = content
	_ambient.color = AMBIENT
	add_child(_ambient)
	var glow_mul := 1.0 if _web else 1.5
	_tile_energy = TILE_LIGHT_ENERGY * glow_mul
	_bullet_energy = BULLET_LIGHT_ENERGY * glow_mul
	var glow := _soft_texture()
	_light(_player, glow, Color(1.0, 0.88, 0.7), PLAYER_ENERGY * glow_mul, _scale_for(3.5))
	# The player's light is the one soft caster (native only) -- it moves, so its
	# shadows are what the eye follows; the few tile casters use the cheap hard filter.
	if not _web:
		_player.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		_player.shadow_filter_smooth = 1.5
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
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	add_child(light)


func _process(delta: float) -> void:
	var live := _state != null and _state.settings.is_on("lighting") \
		and _state.local != null and _state.tiles.width > 0
	if _ambient.visible != live:
		_ambient.visible = live
		_player.visible = live
		for light in _pool:
			light.visible = false
		for light in _bullet_lights:
			light.visible = false
		for occluder in _occluders:
			occluder.visible = false
		_frames = 0
	if not live:
		return
	# Dungeons (not the vault) read a third darker than the overworld.
	var dark := _in_dungeon()
	if dark != _dungeon_dark:
		_dungeon_dark = dark
		_ambient.color = AMBIENT.darkened(0.33) if dark else AMBIENT
	_time += delta
	_player.position = _state.local.render_centre()
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
			# found is distance-sorted, so the nearest few are the casters (native only).
			light.shadow_enabled = not _web and i < TILE_SHADOW_CASTERS
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


## A wall, or a solid prop on the collision layer, casts a shadow. Base-layer
## collision -- deep water, the void -- is not a wall and does not, and a tile
## that emits its own light is not made to shadow itself.
func _occludes(tile_id: int) -> bool:
	return tile_id > 0 and not _emitters.has(tile_id) \
		and (_content.tile_is_wall(tile_id) or _content.tile_has_collision(tile_id))


## In an assembled dungeon that isn't the personal vault -- where the ambient dims.
func _in_dungeon() -> bool:
	return _state.tiles.dungeon_id >= 0 and not _content.maps.is_vault(_state.tiles.map_id)


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
