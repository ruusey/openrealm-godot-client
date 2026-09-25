class_name WorldView3D
extends Node3D

## A real-3D view of the realm, behind the ?3d=1 flag: the ground textured
## quads, the walls textured boxes, and every player, enemy, loot, portal and
## projectile a billboarded sprite -- the same art the 2D renderer draws,
## standing up in 3D. The 2D WorldRenderer is hidden while this is up; the HUD
## stays, on its own CanvasLayer over the top.
##
## World space is the 2D world's own pixels: a 2D (x, y) is 3D (x, 0, y), y up,
## so every position and tile carries over with no scaling and a tile is TILE
## units. The map is built around the player and rebuilt when the player crosses
## REBUILD_MOVE_TILES or the map changes -- bounded node count rather than the
## whole realm at once. Billboards and the camera follow every frame. A
## prototype: aim still reads the 2D camera, so shooting is off here.

const TILE := GameConstants.TILE_SIZE
const COLLISION_LAYER := GameConstants.COLLISION_LAYER
const WALL_HEIGHT := 44.0
## Tiles this far (in cells) around the player are built; beyond it nothing is.
const MAP_RADIUS_TILES := 48
## The player crossing this many cells from the last build rebuilds the map.
const REBUILD_MOVE_TILES := 16
## How far around the player entities and bullets are gathered into billboards.
const ENTITY_RANGE := 900.0
## The height projectiles float at, roughly a body's middle.
const BULLET_HEIGHT := 22.0
## Camera framing: how high and how far back it sits from the player.
const CAM_HEIGHT := 620.0
const CAM_BACK := 430.0
const CAM_FOV := 48.0

var state: RealmState
var content: GameData

var _camera: Camera3D
var _backdrop: MeshInstance3D
var _map_root: Node3D
var _billboard_root: Node3D
var _billboards: Array[Sprite3D] = []
var _entity_queue := EntityQueue.new()
var _floor_mesh := PlaneMesh.new()
var _wall_mesh := BoxMesh.new()
var _grey_wall := StandardMaterial3D.new()
var _floor_materials := {}
var _wall_materials := {}
var _map_built := false
var _built_centre := Vector2i(2147483647, 2147483647)


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.1
	add_child(light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.66)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAM_FOV
	_camera.far = 12000.0
	_camera.current = true
	add_child(_camera)

	# A dark plane under the tiles so gaps and the void read as ground, not sky.
	_backdrop = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000.0, 8000.0)
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.albedo_color = Color(0.08, 0.08, 0.10)
	backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = backdrop_material
	_backdrop.mesh = plane
	add_child(_backdrop)

	_floor_mesh.size = Vector2(TILE, TILE)
	_wall_mesh.size = Vector3(TILE, WALL_HEIGHT, TILE)
	_grey_wall.albedo_color = Color(0.42, 0.40, 0.46)
	_grey_wall.roughness = 0.9
	_grey_wall.emission_enabled = true
	_grey_wall.emission = Color(0.42, 0.40, 0.46)
	_grey_wall.emission_energy_multiplier = 0.3

	_map_root = Node3D.new()
	add_child(_map_root)
	_billboard_root = Node3D.new()
	add_child(_billboard_root)


func _process(_delta: float) -> void:
	if state == null or content == null or state.local == null:
		return
	var centre := state.local.render_centre()
	_rebuild_map_if_needed(centre)
	_follow_camera(centre)
	_backdrop.position = Vector3(centre.x, -0.5, centre.y)
	_refresh_billboards(centre)


## Stands the ground quads and wall boxes up around the player. Rebuilt only
## when the map changes or the player has walked far enough that the radius
## would miss tiles ahead -- not per frame; the geometry does not move.
func _rebuild_map_if_needed(centre: Vector2) -> void:
	var tiles := state.tiles
	var centre_cell := Vector2i(roundi(centre.x / TILE), roundi(centre.y / TILE))
	var moved := maxi(absi(centre_cell.x - _built_centre.x), absi(centre_cell.y - _built_centre.y))
	if _map_built and not tiles.cleared and tiles.changed_cells.is_empty() \
			and moved <= REBUILD_MOVE_TILES:
		return
	tiles.cleared = false
	tiles.changed_cells.clear()
	_built_centre = centre_cell
	for child in _map_root.get_children():
		child.queue_free()

	var layers := tiles.layers.keys()
	layers.sort()
	for layer in layers:
		var cells: Dictionary = tiles.layers[layer]
		for cell in cells:
			if maxi(absi(cell.x - centre_cell.x), absi(cell.y - centre_cell.y)) > MAP_RADIUS_TILES:
				continue
			var tile_id: int = cells[cell]
			if tile_id <= 0:
				continue
			if content.tile_is_wall(tile_id):
				_add_wall(cell, tile_id)
			else:
				_add_floor(cell, layer, tile_id)
	_map_built = true


func _add_wall(cell: Vector2i, tile_id: int) -> void:
	var box := MeshInstance3D.new()
	box.mesh = _wall_mesh
	box.material_override = _wall_material_for(content.tile_texture(tile_id))
	box.position = Vector3(cell.x * TILE + TILE * 0.5, WALL_HEIGHT * 0.5, cell.y * TILE + TILE * 0.5)
	_map_root.add_child(box)


## A flat, ground-lying quad with the tile's own texture. Higher layers sit a
## hair above the ones below so overlays (props, seams) do not z-fight the base.
func _add_floor(cell: Vector2i, layer: int, tile_id: int) -> void:
	var texture := content.tile_texture(tile_id)
	if texture == null:
		return
	var quad := MeshInstance3D.new()
	quad.mesh = _floor_mesh
	quad.material_override = _floor_material_for(texture)
	quad.position = Vector3(cell.x * TILE + TILE * 0.5, 0.02 * float(layer), cell.y * TILE + TILE * 0.5)
	_map_root.add_child(quad)


## One unshaded, alpha-clipped material per tile texture, reused across cells.
func _floor_material_for(texture: Texture2D) -> StandardMaterial3D:
	if _floor_materials.has(texture):
		return _floor_materials[texture]
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	_floor_materials[texture] = material
	return material


## Wall boxes take the tile's art on every face (the 8x16 top/front art is
## approximate on the sides, good enough for the prototype); shaded, so the
## light gives the faces depth. Grey where a wall has no texture.
func _wall_material_for(texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		return _grey_wall
	if _wall_materials.has(texture):
		return _wall_materials[texture]
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	# A faint self-glow of the wall's own art, so collision tiles read as raised
	# and lit against the flat, unshaded ground rather than melting into it.
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = texture
	material.emission_energy_multiplier = 0.35
	_wall_materials[texture] = material
	return material


func _follow_camera(centre: Vector2) -> void:
	var target := Vector3(centre.x, 0.0, centre.y)
	_camera.position = target + Vector3(0.0, CAM_HEIGHT, CAM_BACK)
	_camera.look_at(target, Vector3.UP)


## Rebuilds the billboards each frame from the same data the 2D renderer draws:
## the entity queue first, then the projectiles. Slots are pooled; the unused
## tail is hidden, not freed.
func _refresh_billboards(centre: Vector2) -> void:
	var view := Rect2(centre - Vector2(ENTITY_RANGE, ENTITY_RANGE),
		Vector2(ENTITY_RANGE, ENTITY_RANGE) * 2.0)
	var used := 0
	for item in _entity_queue.build(state, content, view):
		var texture: Texture2D = item.get("texture")
		if texture == null or texture.get_height() <= 0:
			continue
		var pos: Vector2 = item["pos"]
		var size := float(item["size"])
		var draw: Vector2 = item["draw"]
		# Scaled to the DRAW size, not the raw sprite pixels: the art is small
		# (an 8px hero) and the 2D renderer blows it up to the cell, so pixel_size
		# must undo that or every character stands an eighth of its height.
		used = _place(used, texture, Vector3(pos.x + size * 0.5, draw.y * 0.5, pos.y + size * 0.5),
			draw.y / float(texture.get_height()), bool(item["flip"]), item.get("modulate", Color.WHITE))
	used = _place_bullets(used, centre)
	for i in range(used, _billboards.size()):
		_billboards[i].visible = false


func _place_bullets(used: int, centre: Vector2) -> int:
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		if ProjectileKind.has_flag(bullet, ProjectileKind.MELEE_SWING) or BulletRenderer._hidden(state, bullet):
			continue
		var texture := content.projectile_texture(int(bullet.get("group_id", -1)))
		if texture == null or texture.get_height() <= 0:
			continue
		var size := maxf(float(bullet.get("size", 8)), 4.0)
		var pos: Vector2 = bullet["pos"]
		var mid := pos + Vector2(size, size) * 0.5
		if mid.distance_to(centre) > ENTITY_RANGE:
			continue
		used = _place(used, texture, Vector3(mid.x, BULLET_HEIGHT, mid.y),
			size / float(texture.get_height()), false, Color.WHITE)
	return used


## Places one pooled billboard and returns the next free slot.
func _place(index: int, texture: Texture2D, position: Vector3, pixel_size: float,
		flip: bool, modulate: Color) -> int:
	var sprite := _billboard_at(index)
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.flip_h = flip
	sprite.modulate = modulate
	sprite.position = position
	sprite.visible = true
	return index + 1


## A pooled Sprite3D for slot `index`, made on first use. Billboarded so it
## always faces the camera, nearest-filtered and alpha-clipped so the pixel art
## stays crisp and its transparent border never blocks what stands behind it.
func _billboard_at(index: int) -> Sprite3D:
	while _billboards.size() <= index:
		var sprite := Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = false
		sprite.pixel_size = 1.0
		_billboard_root.add_child(sprite)
		_billboards.append(sprite)
	return _billboards[index]
