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

const AMBIENT := Color(0.6, 0.62, 0.72)
const MAX_TILE_LIGHTS := 24
## The most solid cells in view we cast shadows from at once; a whole walled
## room's perimeter fits well inside this.
const MAX_OCCLUDERS := 384
## Tiles do not move, so the view is rescanned every Nth frame, not every frame.
const SCAN_EVERY := 10

var _state: RealmState
var _content: GameData
var _ambient := CanvasModulate.new()
var _player := PointLight2D.new()
var _pool: Array[PointLight2D] = []
var _occluders: Array[LightOccluder2D] = []
var _emitters := {}   # tile id -> [colour, radius in tiles, flickers]
var _frames := 0
var _time := 0.0


func setup(state: RealmState, content: GameData) -> void:
	_state = state
	_content = content
	_ambient.color = AMBIENT
	add_child(_ambient)
	var glow := _soft_texture()
	_light(_player, glow, Color(1.0, 0.88, 0.7), 0.85, _scale_for(3.5))
	for i in MAX_TILE_LIGHTS:
		var light := PointLight2D.new()
		_light(light, glow, Color.WHITE, 1.0, 1.0)
		light.visible = false
		_pool.append(light)
	var square := _square_occluder()
	for i in MAX_OCCLUDERS:
		var occluder := LightOccluder2D.new()
		occluder.occluder = square
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
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 1.5
	add_child(light)


func _process(delta: float) -> void:
	var live := _state != null and _state.settings.is_on("lighting") \
		and _state.local != null and _state.tiles.width > 0
	if _ambient.visible != live:
		_ambient.visible = live
		_player.visible = live
		for light in _pool:
			light.visible = false
		for occluder in _occluders:
			occluder.visible = false
		_frames = 0
	if not live:
		return
	_time += delta
	_player.position = _state.local.render_centre()
	if _frames % SCAN_EVERY == 0:
		_rescan()
	_frames += 1
	for i in _pool.size():
		var light := _pool[i]
		if light.visible and light.get_meta("flickers", false):
			light.energy = 1.0 + 0.12 * sin(_time * 9.0 + i * 1.7) + 0.06 * sin(_time * 23.0 + i)


## The glowing tiles in view get a light each (nearest the player first), and the
## walls and solid props an occluder each, so those lights throw shadows.
func _rescan() -> void:
	if _emitters.is_empty():
		_index_emitters()
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
			if _occludes(solid.get(cell, -1)):
				walls.append(cell)
	found.sort_custom(func(a, b): return a[0] < b[0])
	for i in _pool.size():
		var light := _pool[i]
		light.visible = i < found.size()
		if light.visible:
			var kind: Array = found[i][2]
			light.position = found[i][1]
			light.color = kind[0]
			light.texture_scale = _scale_for(kind[1])
			light.set_meta("flickers", kind[2])
			light.energy = 1.0
	for i in _occluders.size():
		var occluder := _occluders[i]
		occluder.visible = i < walls.size()
		if occluder.visible:
			occluder.position = Vector2(walls[i]) * tile


## A wall, or a solid prop on the collision layer, casts a shadow. Base-layer
## collision -- deep water, the void -- is not a wall and does not, and a tile
## that emits its own light is not made to shadow itself.
func _occludes(tile_id: int) -> bool:
	return tile_id > 0 and not _emitters.has(tile_id) \
		and (_content.tile_is_wall(tile_id) or _content.tile_has_collision(tile_id))


## Tiles carrying a data.light block, read once the content is in.
func _index_emitters() -> void:
	for id in _content.library.tiles:
		var light := _content.tile_light(id)
		var strength := float(light.get("strength", 0.0))
		if strength <= 0.0:
			continue
		var colour := _colour_of(str(light.get("color", "#ffffff")))
		var flickers := str(light.get("style", "steady")) == "flicker"
		_emitters[id] = [colour, strength, flickers]


static func _colour_of(hex: String) -> Color:
	return Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE


## A light `radius` tiles across its bright half, on the 256px texture.
func _scale_for(radius_tiles: float) -> float:
	return radius_tiles * 2.0 * GameConstants.TILE_SIZE / 256.0


## A single tile-sized square, shared by every occluder in the pool; each is
## moved onto its own solid cell.
static func _square_occluder() -> OccluderPolygon2D:
	var tile := float(GameConstants.TILE_SIZE)
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(tile, 0), Vector2(tile, tile), Vector2(0, tile)])
	polygon.closed = true
	return polygon


## White at the centre to nothing at the edge, eased so the fall-off has no
## visible ring.
static func _soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
