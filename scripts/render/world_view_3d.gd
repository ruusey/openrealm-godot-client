class_name WorldView3D
extends Node3D

## A real-3D view of the realm, behind the ?3d=1 flag: the ground textured
## quads, the walls extruded boxes, and every prop, player, enemy, loot, portal
## and projectile a standing (Y-billboard) sprite with a ground shadow -- a
## 2.5D look, the sprites upright toward the angled camera. The 2D WorldRenderer
## and its pinned HUD overlay are hidden while this is up.
##
## World space is the 2D world's own pixels: a 2D (x, y) is 3D (x, 0, y), y up,
## so every position and tile carries over unscaled and a tile is TILE units.
##
## Performance: the ground and walls are MultiMesh -- one draw call per tile
## texture, not per cell -- and built once per map, not per move. The web
## (GL-compatibility, no threads) renderer does not batch thousands of separate
## MeshInstances, which is what made it choppy. Sprites (props, entities,
## projectiles) are pooled and updated in place, never reallocated per frame.
##
## A prototype: aim still reads the 2D camera, so shooting is off here, and the
## nameplates/health bars/loot labels are hidden rather than re-drawn in 3D.

const TILE := GameConstants.TILE_SIZE
const COLLISION_LAYER := GameConstants.COLLISION_LAYER
const WALL_HEIGHT := 44.0
## How far around the player entities and projectiles are gathered.
const ENTITY_RANGE := 900.0
## The height projectiles float at, roughly a body's middle.
const BULLET_HEIGHT := 22.0
## The soft shadow texture's resolution.
const SHADOW_SIZE := 32
## Camera framing: how high and how far back it sits from the player.
const CAM_HEIGHT := 620.0
const CAM_BACK := 430.0
const CAM_FOV := 48.0
## Orbit: [ and ] swing the camera around the player. The billboards are
## FIXED_Y, so they turn to keep facing it and the 2.5D look holds at any angle.
const ORBIT_SPEED := 1.8

var state: RealmState
var content: GameData

var _camera: Camera3D
var _backdrop: MeshInstance3D
var _map_root: Node3D
var _sprite_root: Node3D
var _entities: Array[Sprite3D] = []
var _projectiles: Array[Sprite3D] = []
var _entity_queue := EntityQueue.new()
var _floor_mesh := PlaneMesh.new()
var _wall_mesh := BoxMesh.new()
var _grey_wall := StandardMaterial3D.new()
var _floor_materials := {}
var _wall_materials := {}
var _shadow: ImageTexture
var _map_built := false
var _yaw := 0.0


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
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAM_FOV
	# A tight near/far so the depth buffer has the precision to keep the flat
	# ground layers from z-fighting into black bars across the screen.
	_camera.near = 1.0
	_camera.far = 5000.0
	_camera.current = true
	add_child(_camera)

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
	_grey_wall.albedo_color = Color(0.5, 0.48, 0.54)
	_grey_wall.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow = _make_shadow()

	_map_root = Node3D.new()
	add_child(_map_root)
	_sprite_root = Node3D.new()
	add_child(_sprite_root)


func _process(delta: float) -> void:
	if state == null or content == null or state.local == null:
		return
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		_yaw -= ORBIT_SPEED * delta
	if Input.is_key_pressed(KEY_BRACKETRIGHT):
		_yaw += ORBIT_SPEED * delta
	var centre := state.local.render_centre()
	_rebuild_map_if_changed()
	_follow_camera(centre)
	_backdrop.position = Vector3(centre.x, -2.0, centre.y)
	var used := _place_entities(centre)
	for i in range(used, _entities.size()):
		_entities[i].visible = false
	var shots := _place_projectiles(centre)
	for i in range(shots, _projectiles.size()):
		_projectiles[i].visible = false


# ── Map: ground + walls as MultiMesh, props as standing sprites ───────────────

## Built once per map (or on a live tile edit), not per move: the geometry does
## not move, and rebuilding it as the player walked was the movement hitch.
func _rebuild_map_if_changed() -> void:
	var tiles := state.tiles
	if _map_built and not tiles.cleared and tiles.changed_cells.is_empty():
		return
	tiles.cleared = false
	tiles.changed_cells.clear()
	for child in _map_root.get_children():
		child.queue_free()

	# Group cells by texture so each tile type is one MultiMesh draw call.
	var floor_cells := {}
	var wall_cells := {}
	var layers := tiles.layers.keys()
	layers.sort()
	for layer in layers:
		var cells: Dictionary = tiles.layers[layer]
		for cell in cells:
			var tile_id: int = cells[cell]
			if tile_id <= 0:
				continue
			var texture := content.tile_texture(tile_id)
			if content.tile_is_wall(tile_id):
				_group(wall_cells, texture, Vector3(cell.x * TILE + TILE * 0.5,
					WALL_HEIGHT * 0.5, cell.y * TILE + TILE * 0.5))
			elif layer == COLLISION_LAYER:
				_add_prop(cell, texture)
			elif texture != null:
				_group(floor_cells, texture, Vector3(cell.x * TILE + TILE * 0.5,
					0.5 * float(layer), cell.y * TILE + TILE * 0.5))

	for texture in floor_cells:
		_add_multimesh(_floor_mesh, _floor_material_for(texture), floor_cells[texture])
	for texture in wall_cells:
		_add_multimesh(_wall_mesh, _wall_material_for(texture), wall_cells[texture])
	_map_built = true


func _group(groups: Dictionary, texture: Texture2D, position: Vector3) -> void:
	if not groups.has(texture):
		groups[texture] = []
	groups[texture].append(position)


func _add_multimesh(mesh: Mesh, material: StandardMaterial3D, positions: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for i in positions.size():
		multi.set_instance_transform(i, Transform3D(Basis(), positions[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	_map_root.add_child(instance)


## A collision-layer tile that is not a wall -- a tree, a rock -- stands up as a
## billboard rather than lying flat, the 2.5D treatment the walls get.
func _add_prop(cell: Vector2i, texture: Texture2D) -> void:
	if texture == null or texture.get_width() <= 0:
		return
	var height := TILE * float(texture.get_height()) / float(texture.get_width())
	var sprite := _new_billboard()
	_map_root.add_child(sprite)
	_configure(sprite, texture, Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5),
		height * 0.5, height, TILE, false, Color.WHITE)


func _floor_material_for(texture: Texture2D) -> StandardMaterial3D:
	if _floor_materials.has(texture):
		return _floor_materials[texture]
	var material := StandardMaterial3D.new()
	_apply_atlas(material, texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	_floor_materials[texture] = material
	return material


## Walls are unshaded so the pixel art shows at full colour instead of washing
## out grey under the ambient light, and raised as boxes so they still read as
## solid and stand off the ground.
func _wall_material_for(texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		return _grey_wall
	if _wall_materials.has(texture):
		return _wall_materials[texture]
	var material := StandardMaterial3D.new()
	_apply_atlas(material, texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_materials[texture] = material
	return material


## Binds a (usually AtlasTexture) sprite to a material's albedo. A 3D material
## samples the whole atlas at UV 0..1 -- unlike Sprite2D/3D it ignores an
## AtlasTexture's region -- so the region is turned into a uv1 offset/scale and
## the full sheet bound underneath, so only the one clipped sprite shows.
func _apply_atlas(material: StandardMaterial3D, texture: Texture2D) -> void:
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture
		var sheet := atlas.atlas
		var size := sheet.get_size() if sheet != null else Vector2.ZERO
		material.albedo_texture = sheet
		if size.x > 0.0 and size.y > 0.0:
			material.uv1_offset = Vector3(atlas.region.position.x / size.x,
				atlas.region.position.y / size.y, 0.0)
			material.uv1_scale = Vector3(atlas.region.size.x / size.x,
				atlas.region.size.y / size.y, 1.0)
	else:
		material.albedo_texture = texture


# ── Camera + sprites ──────────────────────────────────────────────────────────

func _follow_camera(centre: Vector2) -> void:
	var target := Vector3(centre.x, 0.0, centre.y)
	var offset := Vector3(sin(_yaw) * CAM_BACK, CAM_HEIGHT, cos(_yaw) * CAM_BACK)
	_camera.position = target + offset
	_camera.look_at(target, Vector3.UP)


## Players, enemies, loot and portals from the same queue the 2D renderer uses,
## each standing upright and scaled to its DRAW size (not the raw 8px sprite).
func _place_entities(centre: Vector2) -> int:
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
		used = _place(_entities, used, texture, Vector2(pos.x + size * 0.5, pos.y + size * 0.5),
			draw.y * 0.5, draw.y, draw.x, bool(item["flip"]), item.get("modulate", Color.WHITE))
	return used


## Projectiles from state.projectiles, standing upright so their size reads the
## same whatever their heading (a flat sprite foreshortened by the camera angle
## was the confusing part). A LINE_SEGMENT is a row of them, as in 2D; the melee
## swing, which 2D leaves to the wielder's animation, is drawn here too.
func _place_projectiles(centre: Vector2) -> int:
	var used := 0
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		if BulletRenderer._hidden(state, bullet):
			continue
		var texture := content.projectile_texture(int(bullet.get("group_id", -1)))
		if texture == null or texture.get_height() <= 0:
			continue
		var size := maxf(float(bullet.get("size", 8)), 4.0)
		var pos: Vector2 = bullet["pos"]
		var mid := pos + Vector2(size, size) * 0.5
		var length := float(bullet.get("length", 0.0))
		if length > 0.0 and ProjectileKind.has_flag(bullet, ProjectileKind.LINE_SEGMENT):
			var angle: float = bullet.get("angle", 0.0)
			var axis := Vector2(cos(angle), -sin(angle))
			var half := length * 0.5
			var steps := maxi(1, int(round(length / size)))
			for s in steps + 1:
				var point := mid + axis * (-half + float(s) / float(steps) * length)
				used = _place(_projectiles, used, texture, point, BULLET_HEIGHT, size, size,
					false, Color.WHITE)
		elif mid.distance_to(centre) <= ENTITY_RANGE:
			used = _place(_projectiles, used, texture, mid, BULLET_HEIGHT, size, size,
				false, Color.WHITE)
	return used


## Configures a pooled billboard at slot `index` and returns the next slot.
func _place(pool: Array[Sprite3D], index: int, texture: Texture2D, xz: Vector2,
		center_y: float, height: float, width: float, flip: bool, modulate: Color) -> int:
	while pool.size() <= index:
		var made := _new_billboard()
		_sprite_root.add_child(made)
		pool.append(made)
	_configure(pool[index], texture, xz, center_y, height, width, flip, modulate)
	return index + 1


## A standing sprite (Y-billboard: upright, turning to face the camera) with a
## flat ground shadow as its first child, so nearest-filtered pixel art stays
## crisp and every body reads as planted on the floor.
func _new_billboard() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	var shadow := Sprite3D.new()
	shadow.texture = _shadow
	shadow.shaded = false
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
	shadow.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	sprite.add_child(shadow)
	return sprite


func _configure(sprite: Sprite3D, texture: Texture2D, xz: Vector2, center_y: float,
		height: float, width: float, flip: bool, modulate: Color) -> void:
	var tex_h := float(texture.get_height())
	sprite.texture = texture
	sprite.pixel_size = height / tex_h if tex_h > 0.0 else 1.0
	sprite.flip_h = flip
	sprite.modulate = modulate
	sprite.position = Vector3(xz.x, center_y, xz.y)
	sprite.visible = true
	var shadow: Sprite3D = sprite.get_child(0)
	shadow.pixel_size = width / float(SHADOW_SIZE)
	# Local, so it lands on the ground whatever height the body floats at.
	shadow.position = Vector3(0.0, 0.15 - center_y, 0.0)


## A soft round shadow, drawn once into a small texture: opaque-ish at the
## centre, fading to nothing at the rim.
func _make_shadow() -> ImageTexture:
	var image := Image.create(SHADOW_SIZE, SHADOW_SIZE, false, Image.FORMAT_RGBA8)
	var centre := float(SHADOW_SIZE) * 0.5
	for y in SHADOW_SIZE:
		for x in SHADOW_SIZE:
			var distance := Vector2(x + 0.5 - centre, y + 0.5 - centre).length() / centre
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, clampf(1.0 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
