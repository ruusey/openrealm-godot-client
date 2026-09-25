class_name WorldView3D
extends Node3D

## A real-3D view of the realm, behind the ?3d=1 flag: the floor a plane, the
## walls extruded boxes from the collision layer, and every player, enemy, loot
## and portal a billboarded sprite -- the same entities EntityQueue hands the 2D
## renderer, standing up in 3D instead of drawn flat. The 2D WorldRenderer is
## hidden while this is up; the HUD stays, on its own CanvasLayer over the top.
##
## World space is the 2D world's own pixels: a 2D (x, y) is 3D (x, 0, y), y up.
## So a tile is TILE_SIZE units and every existing position carries over with no
## scaling. Walls are static per map and built once; billboards and the camera
## follow every frame. A prototype -- aim still reads the 2D camera, so shooting
## is off in this mode; movement and the look are what it is for.

const TILE := GameConstants.TILE_SIZE
const COLLISION_LAYER := GameConstants.COLLISION_LAYER
const WALL_HEIGHT := 44.0
## How far around the player entities are gathered into billboards.
const ENTITY_RANGE := 900.0
## Camera framing: how high and how far back it sits from the player.
const CAM_HEIGHT := 620.0
const CAM_BACK := 430.0
const CAM_FOV := 48.0

var state: RealmState
var content: GameData

var _camera: Camera3D
var _floor: MeshInstance3D
var _walls: Node3D
var _billboard_root: Node3D
var _billboards: Array[Sprite3D] = []
var _entity_queue := EntityQueue.new()
var _wall_material := StandardMaterial3D.new()
var _walls_built := false


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
	env.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAM_FOV
	_camera.current = true
	add_child(_camera)

	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000.0, 6000.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.14, 0.16)
	plane.material = floor_material
	_floor.mesh = plane
	add_child(_floor)

	_wall_material.albedo_color = Color(0.42, 0.40, 0.46)
	_wall_material.roughness = 0.9

	_walls = Node3D.new()
	add_child(_walls)
	_billboard_root = Node3D.new()
	add_child(_billboard_root)


func _process(_delta: float) -> void:
	if state == null or content == null or state.local == null:
		return
	_rebuild_walls_if_changed()
	var centre := state.local.render_centre()
	_follow_camera(centre)
	_floor.position = Vector3(centre.x, 0.0, centre.y)
	_refresh_billboards(centre)


## A new map clears the wall boxes and stands them up again; a live tile edit
## (changed_cells) does the same. Walls do not move, so nothing rebuilds them
## per frame.
func _rebuild_walls_if_changed() -> void:
	var tiles := state.tiles
	if _walls_built and not tiles.cleared and tiles.changed_cells.is_empty():
		return
	tiles.cleared = false
	tiles.changed_cells.clear()
	for child in _walls.get_children():
		child.queue_free()
	if not tiles.layers.has(COLLISION_LAYER):
		_walls_built = true
		return
	var cells: Dictionary = tiles.layers[COLLISION_LAYER]
	for cell in cells:
		var tile_id: int = cells[cell]
		if tile_id <= 0 or not content.tile_is_wall(tile_id):
			continue
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(TILE, WALL_HEIGHT, TILE)
		box.mesh = mesh
		box.material_override = _wall_material
		box.position = Vector3(cell.x * TILE + TILE * 0.5, WALL_HEIGHT * 0.5,
			cell.y * TILE + TILE * 0.5)
		_walls.add_child(box)
	_walls_built = true


func _follow_camera(centre: Vector2) -> void:
	var target := Vector3(centre.x, 0.0, centre.y)
	_camera.position = target + Vector3(0.0, CAM_HEIGHT, CAM_BACK)
	_camera.look_at(target, Vector3.UP)


## Rebuilds the billboards from the same queue the 2D renderer draws, so a
## sprite that shows there shows here. Sprite3D nodes are pooled: the ones a
## frame does not use are hidden, not freed.
func _refresh_billboards(centre: Vector2) -> void:
	var view := Rect2(centre - Vector2(ENTITY_RANGE, ENTITY_RANGE),
		Vector2(ENTITY_RANGE, ENTITY_RANGE) * 2.0)
	var items := _entity_queue.build(state, content, view)
	var used := 0
	for item in items:
		var texture: Texture2D = item.get("texture")
		if texture == null:
			continue
		var sprite := _billboard_at(used)
		used += 1
		var pos: Vector2 = item["pos"]
		var size := float(item["size"])
		var draw: Vector2 = item["draw"]
		sprite.texture = texture
		sprite.flip_h = bool(item["flip"])
		sprite.modulate = item.get("modulate", Color.WHITE)
		sprite.position = Vector3(pos.x + size * 0.5, draw.y * 0.5, pos.y + size * 0.5)
		sprite.visible = true
	for i in range(used, _billboards.size()):
		_billboards[i].visible = false


## A pooled Sprite3D for slot `i`, made on first use. Billboarded so it always
## faces the camera, nearest-filtered and alpha-clipped so the pixel art stays
## crisp and its transparent border never blocks what stands behind it.
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
