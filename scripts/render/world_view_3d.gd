class_name WorldView3D
extends Node3D

## A real-3D view of the realm, behind the ?3d=1 flag: the ground textured
## quads (MultiMesh), the walls extruded boxes (MultiMesh), and every prop,
## player, enemy, loot, portal and projectile a sprite in 3D -- the same art the
## 2D renderer draws. Standing things (props, characters) are upright Y-billboards
## with a ground shadow; projectiles lie flat on the ground
## rotated to their heading; the ability effects are the real 2D EffectRenderer
## projected onto the floor. The pinned overlay (names, bars, damage numbers,
## bubbles, loot) is the real EntityOverlay, driven through this view's 3D camera
## rather than re-drawn -- see _update_overlay. The 2D WorldRenderer is hidden.
##
## World space is the 2D world's own pixels: 2D (x, y) is 3D (x, 0, y), y up.
## Performance: ground/walls are MultiMesh (one draw call per tile texture) built
## once per map, not per move; sprites are pooled and updated in place.
##
## A prototype: aim/movement still read the 2D camera, so they are not yet
## relative to the orbit angle.

const TILE := GameConstants.TILE_SIZE
const COLLISION_LAYER := GameConstants.COLLISION_LAYER
# Walls are perfect cubes, one tile on every edge.
const WALL_HEIGHT := float(TILE)
const ENTITY_RANGE := 900.0
const BULLET_HEIGHT := 12.0
const SHADOW_SIZE := 32
## Camera distance from the player. Pitch (degrees above the ground) rides the
## mouse wheel; yaw rides Q/E. Sprites are full billboards, so they always face
## the camera and tilt to match whatever pitch is chosen -- no foreshortening,
## the art stays fully preserved instead of squished.
const CAM_DIST := 755.0
const PITCH_DEFAULT := 55.0
const PITCH_MIN := 25.0
const PITCH_MAX := 80.0
const PITCH_STEP := 6.0
## Orthographic vertical extent in world units (the zoom); ~720 base rows.
const CAM_ORTHO_SIZE := 720.0
const ORBIT_SPEED := 1.8
# The effect layer renders the 2D EffectRenderer into a SubViewport and projects
# it onto the ground, so its texel density (PX / REGION) is what the effects read
# at. The region is centred on the player each frame, so it only has to cover the
# visible ground -- kept tight, and the resolution high, so effects stay crisp
# instead of magnified into a blur.
const FX_REGION := 1600.0
const FX_VIEWPORT_PX := 2048
## The world span used to fit the overlay's affine projector to the 3D camera.
const OVERLAY_PROBE := 120.0

## Dynamic lighting (the "lighting" setting, shared data.light emitters with the
## 2D SceneLighting). Off restores the old full-bright look; on darkens the scene
## and lets torches, lava and crystals pool real 3D light the walls occlude.
const MAX_LIGHTS_3D := 24
const LIGHT_SCAN_EVERY := 10
const LIGHT_HEIGHT := float(TILE) * 0.6
const TORCH_ENERGY := 4.8
const PLAYER_LIGHT_RANGE := float(TILE) * 4.0
const PLAYER_LIGHT_ENERGY := 3.0
const AMBIENT_LIT := Color(0.32, 0.33, 0.42)
const AMBIENT_LIT_ENERGY := 0.45
## Enough that the sun's wall shadows read while the torches still carry the mood.
const SUN_LIT_ENERGY := 0.5
## Wand/staff/tome bullets carry a travelling arcane glow.
const MAX_BULLET_LIGHTS_3D := 20
const BULLET_LIGHT_COLOR := Color(0.72, 0.62, 1.0)
const BULLET_LIGHT_ENERGY := 3.0
const BULLET_LIGHT_RANGE := float(TILE) * 1.7

var state: RealmState
var content: GameData
## The real pinned overlay, driven through this camera while 3D is up.
var overlay: EntityOverlay
## Player input, told the orbit angle so WASD stays screen-relative.
var input: PlayerInput

var _camera: Camera3D
var _backdrop: MeshInstance3D
var _map_root: Node3D
var _sprite_root: Node3D
var _entities: Array[Sprite3D] = []
var _projectiles: Array[Sprite3D] = []
var _projectile_shadows: Array[Sprite3D] = []
var _entity_queue := EntityQueue.new()
var _floor_mesh := PlaneMesh.new()
var _wall_mesh: ArrayMesh
var _grey_wall := StandardMaterial3D.new()
var _floor_materials := {}
var _wall_materials := {}
var _shadow: ImageTexture
var _map_built := false
var _yaw := 0.0
var _pitch := PITCH_DEFAULT

var _sun: DirectionalLight3D
var _env: Environment
var _player_light: OmniLight3D
var _lights: Array[OmniLight3D] = []
var _bullet_lights: Array[OmniLight3D] = []
var _light_frames := 0
var _light_time := 0.0
var _lit := false
var _lit_applied := false

var _fx_viewport: SubViewport
var _fx_renderer: EffectRenderer
var _fx_camera: Camera2D
var _fx_ground: MeshInstance3D


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	_sun.light_energy = 1.1
	# The key light the walls actually cast from: directional shadows are the ones
	# the GL-compatibility (web) renderer supports, unlike positional/omni shadows.
	_sun.shadow_enabled = true
	add_child(_sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 1.0
	# No glow/bloom: it blurred the bright ability effects (and pixel art in
	# general) into a fuzzy haze. Effects must read crisp like the rest of the scene.
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Orthographic, not perspective: it keeps the angled 2.5D look, but world ->
	# screen is then an exact affine, so the overlay's affine projector pins
	# names, bars, portal captions and loot precisely at any position and any
	# orbit -- perspective made a single affine drift for far entities.
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAM_ORTHO_SIZE
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
	_wall_mesh = _make_wall_mesh()
	_grey_wall.albedo_color = Color(0.5, 0.48, 0.54)
	_grey_wall.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_grey_wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow = _make_shadow()

	_map_root = Node3D.new()
	add_child(_map_root)
	_sprite_root = Node3D.new()
	add_child(_sprite_root)
	_build_effect_ground()
	_build_lights()


func _process(delta: float) -> void:
	if state == null or content == null or state.local == null:
		return
	# Q swings the view left of the player, E right.
	if Input.is_key_pressed(KEY_Q):
		_yaw += ORBIT_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		_yaw -= ORBIT_SPEED * delta
	if input != null:
		input.view_yaw = _yaw
		input.world_mouse = _mouse_world
	var centre := state.local.render_centre()
	_rebuild_map_if_changed()
	_follow_camera(centre)
	_backdrop.position = Vector3(centre.x, -2.0, centre.y)
	var used := _place_entities(centre)
	for i in range(used, _entities.size()):
		_entities[i].visible = false
	_place_projectiles(centre)
	_update_effects(centre)
	_update_overlay(centre)
	_update_lighting(delta, centre)


## The mouse's world point on the ground (y=0) through the 3D camera, as a 2D
## (x, z), so shooting aims where the cursor is at any orbit. Null off-plane.
func _mouse_world() -> Variant:
	if _camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return null
	var hit := origin + direction * distance
	return Vector2(hit.x, hit.z)


## Mouse wheel tilts the camera: up raises the angle toward top-down, down drops
## it toward a more acute, side-on angle. Full-billboard sprites follow suit.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_pitch = clampf(_pitch + PITCH_STEP, PITCH_MIN, PITCH_MAX)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_pitch = clampf(_pitch - PITCH_STEP, PITCH_MIN, PITCH_MAX)


func _follow_camera(centre: Vector2) -> void:
	var target := Vector3(centre.x, 0.0, centre.y)
	var pitch := deg_to_rad(_pitch)
	var horizontal := CAM_DIST * cos(pitch)
	var offset := Vector3(sin(_yaw) * horizontal, CAM_DIST * sin(pitch), cos(_yaw) * horizontal)
	_camera.position = target + offset
	_camera.look_at(target, Vector3.UP)


## Fits the overlay an affine world->screen transform to the 3D camera at the
## player's feet -- exact for points on the ground near the player, close enough
## for the tags around them -- so the real EntityOverlay (names, bars, damage
## numbers, bubbles, loot) pins to the 3D bodies. Its own _process reads these.
func _update_overlay(centre: Vector2) -> void:
	if overlay == null:
		return
	var origin_screen := _camera.unproject_position(Vector3(centre.x, 0.0, centre.y))
	var along_x := (_camera.unproject_position(Vector3(centre.x + OVERLAY_PROBE, 0.0, centre.y)) - origin_screen) / OVERLAY_PROBE
	var along_z := (_camera.unproject_position(Vector3(centre.x, 0.0, centre.y + OVERLAY_PROBE)) - origin_screen) / OVERLAY_PROBE
	overlay.world_projector = Transform2D(along_x, along_z, origin_screen - along_x * centre.x - along_z * centre.y)
	overlay.world_view = Rect2(centre - Vector2(ENTITY_RANGE, ENTITY_RANGE), Vector2(ENTITY_RANGE, ENTITY_RANGE) * 2.0)
	overlay.project_3d = true
	# Refresh here, after the projector is set for THIS frame, rather than letting
	# the overlay's own _process run a frame behind -- that lag is what made the
	# tags/pills lag and jitter while rotating. Its own _process is off in 3D.
	overlay.refresh()


# ── Map: ground + walls as MultiMesh, props as standing sprites ───────────────

func _rebuild_map_if_changed() -> void:
	var tiles := state.tiles
	if _map_built and not tiles.cleared and tiles.changed_cells.is_empty():
		return
	tiles.cleared = false
	tiles.changed_cells.clear()
	for child in _map_root.get_children():
		child.queue_free()

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
				# Every collision-layer tile stands up as a 2.5D billboard.
				_add_prop(cell, texture)
			elif texture != null:
				_group(floor_cells, texture, Vector3(cell.x * TILE + TILE * 0.5,
					0.5 * float(layer), cell.y * TILE + TILE * 0.5))

	for texture in floor_cells:
		_add_multimesh(_floor_mesh, _floor_material_for(texture), floor_cells[texture], false)
	for texture in wall_cells:
		_add_multimesh(_wall_mesh, _wall_material_for(texture), wall_cells[texture])
	_map_built = true


func _group(groups: Dictionary, texture: Texture2D, position: Vector3) -> void:
	if not groups.has(texture):
		groups[texture] = []
	groups[texture].append(position)


func _add_multimesh(mesh: Mesh, material: StandardMaterial3D, positions: Array,
		casts_shadow := true) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for i in positions.size():
		multi.set_instance_transform(i, Transform3D(Basis(), positions[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	# The floor lies flat and would only self-shadow; walls are what cast.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map_root.add_child(instance)


func _add_prop(cell: Vector2i, texture: Texture2D) -> void:
	if texture == null or texture.get_width() <= 0:
		return
	var height := TILE * float(texture.get_height()) / float(texture.get_width())
	var sprite := _new_billboard()
	_map_root.add_child(sprite)
	_configure(sprite, texture, Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5),
		height, TILE, TILE, false, Color.WHITE)


func _floor_material_for(texture: Texture2D) -> StandardMaterial3D:
	if _floor_materials.has(texture):
		return _floor_materials[texture]
	var material := StandardMaterial3D.new()
	_apply_atlas(material, texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Lit, so the dynamic lights pool on the ground; the floor plane faces up.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	_floor_materials[texture] = material
	return material


func _wall_material_for(texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		return _grey_wall
	if _wall_materials.has(texture):
		return _wall_materials[texture]
	var material := StandardMaterial3D.new()
	_apply_atlas(material, texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Lit, so lights fall on the wall faces; the mesh carries generated normals.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# The cube's faces are drawn from one side each; two-sided keeps a face lit
	# even when the orbit looks at its back.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_materials[texture] = material
	return material


## A one-tile cube whose UVs split the 8x16 wall art the way the sprite is
## authored: the upper half (mesh v 0..0.5) is the top face, the lower half
## (v 0.5..1) the front face, repeated on all four sides. The wall material's
## atlas offset/scale then maps that 0..1 onto the tile's region, so each face
## gets the correct 8x8 half instead of the whole sprite squished onto it.
func _make_wall_mesh() -> ArrayMesh:
	var h := TILE * 0.5
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sides: top edge -> v 0.5 (top of the front face), bottom edge -> v 1.0.
	_wall_quad(builder, Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(-h, -h, h), 0.5, 1.0)
	_wall_quad(builder, Vector3(h, h, -h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(h, -h, -h), 0.5, 1.0)
	_wall_quad(builder, Vector3(h, h, h), Vector3(h, h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), 0.5, 1.0)
	_wall_quad(builder, Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(-h, -h, h), Vector3(-h, -h, -h), 0.5, 1.0)
	# Top: the upper half of the sprite.
	_wall_quad(builder, Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h), 0.0, 0.5)
	builder.generate_normals()
	return builder.commit()


## A quad (top-left, top-right, bottom-right, bottom-left) with u across 0..1 and
## v spanning the given band of the sprite.
func _wall_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		v_top: float, v_bottom: float) -> void:
	builder.set_uv(Vector2(0.0, v_top)); builder.add_vertex(a)
	builder.set_uv(Vector2(1.0, v_top)); builder.add_vertex(b)
	builder.set_uv(Vector2(1.0, v_bottom)); builder.add_vertex(c)
	builder.set_uv(Vector2(0.0, v_top)); builder.add_vertex(a)
	builder.set_uv(Vector2(1.0, v_bottom)); builder.add_vertex(c)
	builder.set_uv(Vector2(0.0, v_bottom)); builder.add_vertex(d)


## A 3D material samples the whole atlas at UV 0..1 -- unlike Sprite2D/3D it
## ignores an AtlasTexture's region -- so the region becomes a uv1 offset/scale
## and the full sheet is bound underneath, so only the one clipped sprite shows.
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


# ── Standing sprites: entities and props ──────────────────────────────────────

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
		used = _place(used, texture, Vector2(pos.x + size * 0.5, pos.y + size * 0.5),
			draw.y, draw.x, size, bool(item["flip"]), item.get("modulate", Color.WHITE))
	return used


func _place(index: int, texture: Texture2D, xz: Vector2, height: float, width: float,
		cell: float, flip: bool, modulate: Color) -> int:
	while _entities.size() <= index:
		var made := _new_billboard()
		_sprite_root.add_child(made)
		_entities.append(made)
	_configure(_entities[index], texture, xz, height, width, cell, flip, modulate)
	return index + 1


## A standing sprite (full billboard) with a ground shadow (child 0).
func _new_billboard() -> Sprite3D:
	var sprite := _sprite_node(BaseMaterial3D.BILLBOARD_ENABLED)
	sprite.add_child(_new_shadow())
	return sprite


## The pivot is pinned to the body's ground point -- which is exactly the
## camera's target -- so animation frames of different sizes never move it and
## jitter the sprite (the earlier per-frame position shift is what caused the
## jitter). The art is placed WITHIN the sprite by `offset`, not by moving the
## node: bottom-anchored so the feet sit on the ground, and side-anchored so a
## wide attack frame's overhang falls on the facing side.
func _configure(sprite: Sprite3D, texture: Texture2D, xz: Vector2, height: float,
		width: float, cell: float, flip: bool, modulate: Color) -> void:
	var tex_h := float(texture.get_height())
	var tex_w := float(texture.get_width())
	sprite.texture = texture
	sprite.pixel_size = height / tex_h if tex_h > 0.0 else 1.0
	sprite.flip_h = flip
	sprite.modulate = modulate
	sprite.position = Vector3(xz.x, 0.0, xz.y)
	sprite.visible = true
	# Body pixels within the frame; the overhang is the rest, on the facing side.
	var body_px := tex_w * cell / width if width > 0.0 else tex_w
	var side := (tex_w - body_px) * 0.5
	sprite.offset = Vector2(-side if flip else side, tex_h * 0.5)
	var shadow: Sprite3D = sprite.get_child(0)
	shadow.pixel_size = width / float(SHADOW_SIZE)
	shadow.scale = Vector3.ONE
	shadow.position = Vector3(0.0, 0.15, 0.0)


# ── Projectiles: flat on the ground, turned to their heading ──────────────────

func _place_projectiles(centre: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var used := 0
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		if BulletRenderer._hidden(state, bullet):
			continue
		var group_id := int(bullet.get("group_id", -1))
		var texture := content.projectile_texture(group_id)
		if texture == null or texture.get_height() <= 0:
			continue
		var size := maxf(float(bullet.get("size", 8)), 4.0)
		var pos: Vector2 = bullet["pos"]
		var mid := pos + Vector2(size, size) * 0.5
		var angle: float = bullet.get("angle", 0.0)
		var offset := content.projectiles_art.angle_offset(group_id)
		var spin := content.projectiles_art.spin(group_id)
		var turn := ProjectileArt.spun(spin, now)
		var additive: bool = spin.is_empty() or spin["additive"]
		var heading := BulletRenderer.rotation_for(angle, offset, turn, additive)
		var length := float(bullet.get("length", 0.0))
		if length > 0.0 and ProjectileKind.has_flag(bullet, ProjectileKind.LINE_SEGMENT):
			var axis := Vector2(cos(angle), -sin(angle))
			var half := length * 0.5
			var steps := maxi(1, int(round(length / size)))
			for s in steps + 1:
				var point := mid + axis * (-half + float(s) / float(steps) * length)
				used = _emit_projectile(used, texture, point, size, heading)
		elif mid.distance_to(centre) <= ENTITY_RANGE:
			used = _emit_projectile(used, texture, mid, size, heading)
	for i in range(used, _projectiles.size()):
		_projectiles[i].visible = false
		_projectile_shadows[i].visible = false


func _emit_projectile(index: int, texture: Texture2D, xz: Vector2, size: float, heading: float) -> int:
	while _projectiles.size() <= index:
		var made := _sprite_node(BaseMaterial3D.BILLBOARD_DISABLED)
		_sprite_root.add_child(made)
		_projectiles.append(made)
		var shade := _new_shadow()
		_sprite_root.add_child(shade)
		_projectile_shadows.append(shade)
	var tex_h := float(texture.get_height())
	var sprite := _projectiles[index]
	sprite.texture = texture
	sprite.pixel_size = size / tex_h if tex_h > 0.0 else 1.0
	sprite.modulate = Color.WHITE
	# Lay flat, then turn about the vertical to the heading. The 2D rotation is a
	# screen angle, so its sign flips for the 3D Z axis.
	sprite.transform = Transform3D(
		Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3(xz.x, BULLET_HEIGHT, xz.y))
	sprite.visible = true
	var shadow := _projectile_shadows[index]
	shadow.pixel_size = size / float(SHADOW_SIZE)
	shadow.position = Vector3(xz.x, 0.2, xz.y)
	shadow.visible = true
	return index + 1


# ── Ability effects: the 2D renderer, projected on the ground ─────────────────

func _build_effect_ground() -> void:
	_fx_viewport = SubViewport.new()
	_fx_viewport.size = Vector2i(FX_VIEWPORT_PX, FX_VIEWPORT_PX)
	_fx_viewport.transparent_bg = true
	_fx_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_fx_viewport)
	_fx_camera = Camera2D.new()
	_fx_camera.zoom = Vector2(float(FX_VIEWPORT_PX) / FX_REGION, float(FX_VIEWPORT_PX) / FX_REGION)
	_fx_viewport.add_child(_fx_camera)
	_fx_renderer = EffectRenderer.new()
	_fx_renderer.state = state
	_fx_viewport.add_child(_fx_renderer)

	_fx_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FX_REGION, FX_REGION)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _fx_viewport.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Plain linear, no mipmaps: the ground is viewed at a grazing angle, and the
	# default mipmapped filter drops to blurry, shimmering low mip levels there --
	# that was the grain. Linear keeps the anti-aliased vector effects smooth.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	plane.material = material
	_fx_ground.mesh = plane
	add_child(_fx_ground)


func _update_effects(centre: Vector2) -> void:
	_fx_camera.position = centre
	_fx_ground.position = Vector3(centre.x, 1.5, centre.y)
	_fx_renderer.queue_redraw()


# ── Dynamic lighting: an omni per glowing tile, plus one on the player ─────────

func _build_lights() -> void:
	_player_light = OmniLight3D.new()
	_player_light.light_color = Color(1.0, 0.88, 0.7)
	_player_light.omni_range = PLAYER_LIGHT_RANGE
	_player_light.light_energy = PLAYER_LIGHT_ENERGY
	_player_light.shadow_enabled = true
	_player_light.visible = false
	add_child(_player_light)
	for i in MAX_LIGHTS_3D:
		var light := OmniLight3D.new()
		light.shadow_enabled = true
		light.visible = false
		_lights.append(light)
		add_child(light)
	for i in MAX_BULLET_LIGHTS_3D:
		var light := OmniLight3D.new()
		light.light_color = BULLET_LIGHT_COLOR
		light.light_energy = BULLET_LIGHT_ENERGY
		light.omni_range = BULLET_LIGHT_RANGE
		light.visible = false
		_bullet_lights.append(light)
		add_child(light)


func _update_lighting(delta: float, centre: Vector2) -> void:
	var on := state.settings.is_on("lighting")
	if not _lit_applied or on != _lit:
		_lit = on
		_lit_applied = true
		_apply_lighting(on)
	if not on:
		return
	_light_time += delta
	_player_light.position = Vector3(centre.x, LIGHT_HEIGHT, centre.y)
	if _light_frames % LIGHT_SCAN_EVERY == 0:
		_place_lights(centre)
	_light_frames += 1
	_place_bullet_lights(centre)
	for i in _lights.size():
		var light := _lights[i]
		if light.visible and light.get_meta("flickers", false):
			light.light_energy = TORCH_ENERGY \
				* (1.0 + 0.12 * sin(_light_time * 9.0 + i * 1.7) + 0.06 * sin(_light_time * 23.0 + i))


## Dark ambient and a low sun when lit; the old full-bright albedo when off.
func _apply_lighting(on: bool) -> void:
	_env.ambient_light_color = AMBIENT_LIT if on else Color.WHITE
	_env.ambient_light_energy = AMBIENT_LIT_ENERGY if on else 1.0
	_sun.light_energy = SUN_LIT_ENERGY if on else 0.0
	_player_light.visible = on
	if not on:
		for light in _lights:
			light.visible = false
		for light in _bullet_lights:
			light.visible = false


## The glowing tiles near the player, nearest first, one omni each.
func _place_lights(centre: Vector2) -> void:
	var emitters := content.light_emitters()
	var tile := float(TILE)
	var reach := ceili(ENTITY_RANGE / tile)
	var origin := Vector2i(floori(centre.x / tile), floori(centre.y / tile))
	var found := []
	for gy in range(origin.y - reach, origin.y + reach + 1):
		for gx in range(origin.x - reach, origin.x + reach + 1):
			var cell := Vector2i(gx, gy)
			for layer in state.tiles.layers:
				var kind: Variant = emitters.get(state.tiles.layers[layer].get(cell, -1))
				if kind != null:
					var at := Vector2(gx + 0.5, gy + 0.5) * tile
					found.append([at.distance_squared_to(centre), at, kind])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for i in _lights.size():
		var light := _lights[i]
		light.visible = i < found.size()
		if light.visible:
			var kind: Dictionary = found[i][2]
			var at: Vector2 = found[i][1]
			light.position = Vector3(at.x, LIGHT_HEIGHT, at.y)
			light.light_color = kind["color"]
			light.omni_range = float(kind["radius"]) * tile * 2.0
			light.set_meta("flickers", kind["flickers"])
			light.light_energy = TORCH_ENERGY


## The nearest wand/staff/tome bullets in flight, one travelling omni each.
func _place_bullet_lights(centre: Vector2) -> void:
	var magic := content.magic_projectile_groups()
	var found := []
	if not magic.is_empty():
		for id in state.projectiles.bullets:
			var bullet: Dictionary = state.projectiles.bullets[id]
			if not magic.has(int(bullet.get("group_id", -1))):
				continue
			var size := maxf(float(bullet.get("size", 8)), 4.0)
			var mid: Vector2 = bullet["pos"] + Vector2(size, size) * 0.5
			if mid.distance_to(centre) <= ENTITY_RANGE:
				found.append([mid.distance_squared_to(centre), mid])
		found.sort_custom(func(a, b): return a[0] < b[0])
	for i in _bullet_lights.size():
		var light := _bullet_lights[i]
		light.visible = i < found.size()
		if light.visible:
			var mid: Vector2 = found[i][1]
			light.position = Vector3(mid.x, BULLET_HEIGHT, mid.y)


# ── Shared sprite + texture helpers ───────────────────────────────────────────

func _sprite_node(billboard: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.billboard = billboard
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Standing bodies (billboards) take the light so they darken away from it and
	# warm up by a torch; flat projectiles stay self-bright.
	sprite.shaded = billboard == BaseMaterial3D.BILLBOARD_ENABLED
	return sprite


func _new_shadow() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = _shadow
	sprite.shaded = false
	sprite.modulate = Color(0.0, 0.0, 0.0, 0.5)
	sprite.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	return sprite


func _make_shadow() -> ImageTexture:
	var image := Image.create(SHADOW_SIZE, SHADOW_SIZE, false, Image.FORMAT_RGBA8)
	var centre := float(SHADOW_SIZE) * 0.5
	for y in SHADOW_SIZE:
		for x in SHADOW_SIZE:
			var distance := Vector2(x + 0.5 - centre, y + 0.5 - centre).length() / centre
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, clampf(1.0 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
