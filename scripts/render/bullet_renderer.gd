class_name BulletRenderer
extends Node2D

## Draws projectiles, after the ground pass and without sorting.
##
## Bullets read better over the top of everything, which is what the reference
## client does too. Separate from EntityRenderer because nothing here sorts,
## mirrors or animates -- a bullet is a sprite rotated onto its heading.
##
## Two exceptions: a MELEE_SWING is an invisible area effect that the wielder's
## swing animation stands in for, and a LINE_SEGMENT wall is a row of sprites
## rather than one.
##
## The sprites themselves are MultiMesh instances, one MultiMesh per sheet drawn
## into a canvas item of its own under bullet.gdshader, which also draws their
## silhouettes: a whole sheet's shots, outlined, are one draw call and two
## instance writes each, where drawing them one by one was six commands a shot.

## Silhouettes cost nothing per shot on the GPU path, so every shot gets one; this
## caps only shots drawn the slow way (a sheet too large for the MultiMesh path).
const OUTLINE_BUDGET := 256
## Instance custom data travels as half floats, which hold whole pixels exactly
## only up to here; a larger sheet's shots are drawn one by one instead.
const MAX_INSTANCED_SHEET := 2048
const BULLET_SHADER := preload("res://scripts/render/shaders/bullet.gdshader")
## An afterimage is five extra stamps per bullet; under a companion-crowd horde
## that dominates the native frame. Cap how many bullets trail per frame (nearest
## drawn first, so the closest keep their trail) — the rest still draw, just flat.
const AFTERIMAGE_BUDGET := 64
var _web := OS.has_feature("web")
const NO_ART: Array = []
const ART_TEXTURE := 0
const ART_OFFSET := 1
const ART_NO_ROTATE := 2
const ART_TURN := 3
const ART_ADDITIVE := 4
const ART_AFTERIMAGE := 5
## The sheet the art is cut from, which is what a draw batches on.
const ART_SHEET := 6
## The sprite's region of its sheet in pixels, as the shader reads it.
const ART_REGION := 7
## Whether its sheet goes through the MultiMesh path.
const ART_INSTANCED := 8
var _outline_budget := OUTLINE_BUDGET
var _afterimage_budget := 0 if OS.has_feature("web") else AFTERIMAGE_BUDGET

var state: RealmState
var content: GameData
## Spin is a function of the wall clock -- see ProjectileArt.spun -- so the
## renderer needs one, and a test needs to be able to stop it.
var clock: Callable = func() -> int: return Time.get_ticks_msec()
var drawn := 0
## How many projectiles got a silhouette last frame -- visible evidence that
## the budget is doing something when a horde arrives.
var outlined := 0
## And how many trailed copies of themselves.
var afterimaged := 0

static var _quad: ArrayMesh
## The canvas item the instanced sprites draw into, over this one's afterimages.
var _bodies := RID()
var _material: ShaderMaterial
var _meshes := {}   # sheet -> MultiMesh


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BULLET_SHADER
	_bodies = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_bodies, get_canvas_item())
	RenderingServer.canvas_item_set_material(_bodies, _material.get_rid())
	RenderingServer.canvas_item_set_default_texture_filter(_bodies,
		RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _bodies.is_valid():
		RenderingServer.free_rid(_bodies)


## Kept out of any group effect applied to the world: the web client makes
## bulletLayer a sibling of worldLayer for exactly this reason, because a
## filter haloes the alpha-faded edges of a projectile.
func _draw() -> void:
	if state == null or content == null:
		return
	drawn = paint(self, state, content, ViewRect.of(self))


func paint(canvas: CanvasItem, state: RealmState, content: GameData,
		view: Rect2) -> int:
	var drawn := 0
	outlined = 0
	afterimaged = 0
	# The wall clock drives the spin of every shot in phase, so it is read once
	# for the whole frame; and each group's art (texture, offset, spin turn,
	# afterimage) is resolved once per distinct group here, not re-looked-up for
	# every one of the hundreds of bullets that share it. Everything per bullet
	# stays inside these loops: a call into another script costs as much as ten
	# dictionary reads, which is the whole frame at bullet-hell counts.
	var now_ms: int = clock.call()
	var visibility := BulletVisibility.of(state)
	var any_hidden := visibility.any
	var groups := {}
	# What survives the cull, bucketed by sprite sheet: bullets need no order
	# among themselves, and drawn sheet by sheet they batch into a draw call
	# per sheet instead of one each time two neighbours' sheets differ.
	var sheets := {}
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		var traits: int = bullet.get("traits", -1)
		if traits < 0:
			traits = ProjectileKind.traits(bullet)
		# The swing animation stands in for a melee arc; both references
		# deliberately draw no sprite for it.
		if traits & ProjectileKind.TRAIT_MELEE_SWING:
			continue
		# Off-screen first: it is most of a bullet hell, and the cheapest test.
		# A wall anchored off-screen can still have its body on-screen.
		if traits & ProjectileKind.TRAIT_LINE_SEGMENT:
			if not view.grow(float(bullet.get("length", 0.0))).has_point(bullet["pos"]):
				continue
		elif not view.has_point(bullet["pos"]):
			continue
		if any_hidden and visibility.hides(bullet):
			continue
		drawn += 1
		var group_id := int(bullet.get("group_id", -1))
		var art: Array = groups.get(group_id, NO_ART)
		if art.is_empty():
			art = _resolve_group(content, group_id, now_ms)
			groups[group_id] = art
		var batch: Array = sheets.get(art[ART_SHEET], NO_ART)
		if batch.is_empty():
			batch = []
			sheets[art[ART_SHEET]] = batch
		batch.append(bullet)
		batch.append(art)
	var outlines := SpriteOutline.enabled
	if _bodies.is_valid():
		RenderingServer.canvas_item_clear(_bodies)
	for sheet in sheets:
		var batch: Array = sheets[sheet]
		if _bodies.is_valid() and canvas == self and batch[1][ART_INSTANCED]:
			_draw_instanced(sheet, batch, outlines)
			continue
		for i in range(0, batch.size(), 2):
			_draw_bullet(canvas, batch[i], batch[i + 1], outlines)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return drawn


## One sheet's shots into its MultiMesh: a transform and a region per sprite, a
## wall's tiles each a sprite of their own. Afterimages still stamp on this canvas
## item, which draws under the instanced bodies.
func _draw_instanced(sheet: Texture2D, batch: Array, outlines: bool) -> void:
	var needed := 0
	for i in range(0, batch.size(), 2):
		needed += _sprites_in(batch[i])
	var mesh := _mesh_for(sheet, needed)
	var outline_flag := Color(1.0 if outlines else 0.0, 1.0, 1.0, 1.0)
	var flat := Color(0.0, 1.0, 1.0, 1.0)
	var at := 0
	for i in range(0, batch.size(), 2):
		var bullet: Dictionary = batch[i]
		var art: Array = batch[i + 1]
		var size: float = maxf(float(bullet.get("size", 8)), 4.0)
		var half := size * 0.5
		var centre: Vector2 = bullet["pos"] + Vector2(half, half)
		var region: Color = art[ART_REGION]
		var angle: float = bullet["angle"]
		var offset: float = art[ART_OFFSET]
		var turn: float = art[ART_TURN]
		var additive: bool = art[ART_ADDITIVE]
		var length := float(bullet.get("length", 0.0))
		if length > 0.0 and ProjectileKind.traits(bullet) & ProjectileKind.TRAIT_LINE_SEGMENT:
			# _draw_wall's row of tiles, unoutlined (they overlap each other).
			var axis := Vector2(cos(angle), -sin(angle))
			var tiles := maxi(1, int(round(length / size)))
			var tile_rotation := -angle + offset + (turn if additive else 0.0)
			for k in tiles + 1:
				var along := -length * 0.5 + (float(k) / float(tiles)) * length
				mesh.set_instance_transform_2d(at, Transform2D(tile_rotation, Vector2(size, size), 0.0,
					centre + axis * along))
				mesh.set_instance_color(at, flat)
				mesh.set_instance_custom_data(at, region)
				at += 1
			continue
		var rotation: float = offset if art[ART_NO_ROTATE] \
			else ((-angle + PI * 0.5 + offset + turn) if additive else turn)
		var afterimage: Color = art[ART_AFTERIMAGE]
		if afterimage.a > 0.0 and afterimaged < _afterimage_budget:
			BulletAfterimage.stamp(self, art[ART_TEXTURE], centre, size, angle, rotation, afterimage)
			afterimaged += 1
		# An outlined quad is a unit wider each side, for the silhouette.
		var quad := size + 2.0 * SpriteOutline.OFFSET if outlines else size
		mesh.set_instance_transform_2d(at, Transform2D(rotation, Vector2(quad, quad), 0.0, centre))
		mesh.set_instance_color(at, outline_flag)
		mesh.set_instance_custom_data(at, region)
		at += 1
	if outlines:
		outlined += batch.size() / 2
	mesh.visible_instance_count = at
	RenderingServer.canvas_item_add_multimesh(_bodies, mesh.get_rid(), sheet.get_rid())


static func _sprites_in(bullet: Dictionary) -> int:
	var length := float(bullet.get("length", 0.0))
	if length > 0.0 and ProjectileKind.traits(bullet) & ProjectileKind.TRAIT_LINE_SEGMENT:
		return maxi(1, int(round(length / maxf(float(bullet.get("size", 8)), 4.0)))) + 1
	return 1


## The sheet's MultiMesh with room for `needed`; it only grows, by doubling, since
## a resize drops every instance.
func _mesh_for(sheet: Texture2D, needed: int) -> MultiMesh:
	var mesh: MultiMesh = _meshes.get(sheet)
	if mesh == null:
		mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_2D
		mesh.use_colors = true
		mesh.use_custom_data = true
		mesh.mesh = unit_quad()
		_meshes[sheet] = mesh
	if mesh.instance_count < needed:
		mesh.instance_count = maxi(16, nearest_po2(needed))
	return mesh


## A unit quad centred on the origin with UV (0, 0) at its top-left as the
## canvas draws it, y down. Built by hand: QuadMesh is laid out for 3D, y up.
static func unit_quad() -> ArrayMesh:
	if _quad != null:
		return _quad
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_quad = ArrayMesh.new()
	_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad


func _draw_bullet(canvas: CanvasItem, bullet: Dictionary, art: Array, outlines: bool) -> void:
	var size: float = maxf(float(bullet.get("size", 8)), 4.0)
	var texture: Texture2D = art[ART_TEXTURE]
	var half := size * 0.5
	var centre: Vector2 = bullet["pos"] + Vector2(half, half)
	if texture == null:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		canvas.draw_circle(centre, half, Color(1.0, 0.9, 0.35))
		return
	# Projectile art is drawn pointing diagonally, not up, which is why
	# most groups carry an angleOffset of PI/4. Rotating on the travel
	# angle alone leaves every shot 45 degrees off its heading. Mirrors
	# the web client: -angle + PI/2 + angleOffset.
	var angle: float = bullet["angle"]
	var offset: float = art[ART_OFFSET]
	# A continuous spin replaces the heading outright -- a shuriken does
	# not point where it is going -- while an additive one turns on top of
	# it. A wall's tiles only ever take the additive kind, because a
	# continuous one would break the line they are meant to form.
	var turn: float = art[ART_TURN]
	var additive: bool = art[ART_ADDITIVE]
	var length := float(bullet.get("length", 0.0))
	if length > 0.0 and ProjectileKind.traits(bullet) & ProjectileKind.TRAIT_LINE_SEGMENT:
		_draw_wall(canvas, texture, centre, size, angle, offset,
			length, turn if additive else 0.0)
		return
	# A no-rotate group pins its sprite to a fixed orientation (its
	# angleOffset) rather than turning onto its heading, so a wavy shot
	# stays easy to track instead of wobbling. Ally/summon bolts are NOT
	# pinned -- they face their heading exactly like the source enemy's shot.
	var rotation: float = offset if art[ART_NO_ROTATE] \
		else ((-angle + PI * 0.5 + offset + turn) if additive else turn)
	var afterimage: Color = art[ART_AFTERIMAGE]
	if afterimage.a > 0.0 and afterimaged < _afterimage_budget:
		BulletAfterimage.stamp(canvas, texture, centre, size, angle, rotation, afterimage)
		afterimaged += 1
	canvas.draw_set_transform(centre, rotation, Vector2.ONE)
	if outlines and outlined < _outline_budget:
		outlined += 1
		# SpriteOutline.stamp, inlined.
		canvas.draw_texture_rect(texture, Rect2(-half + SpriteOutline.OFFSET, -half, size, size),
			false, SpriteOutline.TINT)
		canvas.draw_texture_rect(texture, Rect2(-half - SpriteOutline.OFFSET, -half, size, size),
			false, SpriteOutline.TINT)
		canvas.draw_texture_rect(texture, Rect2(-half, -half + SpriteOutline.OFFSET, size, size),
			false, SpriteOutline.TINT)
		canvas.draw_texture_rect(texture, Rect2(-half, -half - SpriteOutline.OFFSET, size, size),
			false, SpriteOutline.TINT)
	canvas.draw_texture_rect(texture, Rect2(-half, -half, size, size), false)


## A group's render attributes resolved once per frame: the ProjectileArt getters
## are per-group memoized but still a call and a dict lookup each, and a bullet
## hell draws hundreds of bullets from a handful of groups -- so each group is
## resolved on first sight into a flat array (ART_* indices) reused for its every
## bullet that frame. Afterimages are a native-only trail (the web skips them for
## the draw-call budget).
func _resolve_group(content: GameData, group_id: int, now_ms: int) -> Array:
	var spin := content.projectiles_art.spin(group_id)
	var texture: Texture2D = content.projectile_texture(group_id)
	var sheet: Texture2D = texture.atlas if texture is AtlasTexture else texture
	var region := Color()
	if texture is AtlasTexture:
		var cut: Rect2 = (texture as AtlasTexture).region
		region = Color(cut.position.x, cut.position.y, cut.size.x, cut.size.y)
	elif texture != null:
		region = Color(0.0, 0.0, texture.get_width(), texture.get_height())
	var instanced := sheet != null and sheet.get_width() <= MAX_INSTANCED_SHEET \
		and sheet.get_height() <= MAX_INSTANCED_SHEET
	return [
		texture,
		content.projectiles_art.angle_offset(group_id),
		content.projectiles_art.no_rotate(group_id),
		ProjectileArt.spun(spin, now_ms),
		spin.is_empty() or spin["additive"],
		Color.TRANSPARENT if _web else content.projectiles_art.fx(group_id)["afterimage"],
		sheet,
		region,
		instanced,
	]


## Where a bullet points. An additive spin turns on top of the heading; a
## continuous one replaces it outright, which is why a shuriken does not point
## where it is going.
static func rotation_for(angle: float, offset: float, turn: float,
		additive: bool) -> float:
	return (-angle + PI * 0.5 + offset + turn) if additive else turn


static func _draw_one(canvas: CanvasItem, texture: Texture2D, centre: Vector2,
		size: float, rotation: float, outline := true) -> void:
	var body := Rect2(-size * 0.5, -size * 0.5, size, size)
	canvas.draw_set_transform(centre, rotation, Vector2.ONE)
	if outline:
		SpriteOutline.stamp(canvas, texture, body)
	canvas.draw_texture_rect(texture, body, false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A LINE_SEGMENT wall is a row of sprites stacked along the axis
## perpendicular to its facing -- the same geometry the server's lineHit uses
## -- not one stretched sprite. `size` is the wall's thickness and `length`
## its span.
##
## The tiles point ALONG that axis, so there is no PI/2 here: that term is
## what aligns a *travelling* bullet to its heading. Wall tiles carry no
## outline: they overlap each other, so a silhouette lands between them.
static func _draw_wall(canvas: CanvasItem, texture: Texture2D, centre: Vector2,
		size: float, angle: float, offset: float, length: float,
		turn := 0.0) -> void:
	var axis := Vector2(cos(angle), -sin(angle))
	var half := length * 0.5
	var tiles := maxi(1, int(round(length / size)))
	for i in tiles + 1:
		var along := -half + (float(i) / float(tiles)) * length
		_draw_one(canvas, texture, centre + axis * along, size,
			-angle + offset + turn, false)


## Whether a bullet is suppressed entirely (see BulletVisibility). A loop over
## many bullets takes one BulletVisibility for the frame instead.
static func _hidden(state: RealmState, bullet: Dictionary) -> bool:
	return BulletVisibility.of(state).hides(bullet)
