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


## An outline is eight extra commands per projectile, so a horde would pay
## nine times over for it. The web client caps it the same way (its
## BULLET_OUTLINE_BUDGET), and prioritises the shots nearest the camera; ours
## simply stops once the budget is spent.
const OUTLINE_BUDGET := 256

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
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		# The swing animation stands in for a melee arc; both references
		# deliberately draw no sprite for it.
		if ProjectileKind.has_flag(bullet, ProjectileKind.MELEE_SWING) or _hidden(state, bullet):
			continue

		var position: Vector2 = bullet["pos"]
		var length := float(bullet.get("length", 0.0))
		var is_wall: bool = length > 0.0 \
			and ProjectileKind.has_flag(bullet, ProjectileKind.LINE_SEGMENT)
		# A wall anchored off-screen can still have its body on-screen.
		if not (view.grow(length) if is_wall else view).has_point(position):
			continue
		drawn += 1

		var size: float = maxf(float(bullet.get("size", 8)), 4.0)
		var texture := content.projectile_texture(int(bullet.get("group_id", -1)))
		if texture == null:
			canvas.draw_circle(position + Vector2(size, size) * 0.5, size * 0.5,
				Color(1.0, 0.9, 0.35))
			continue

		# Projectile art is drawn pointing diagonally, not up, which is why
		# most groups carry an angleOffset of PI/4. Rotating on the travel
		# angle alone leaves every shot 45 degrees off its heading. Mirrors
		# the web client: -angle + PI/2 + angleOffset.
		var angle: float = bullet["angle"]
		var group_id := int(bullet.get("group_id", -1))
		var offset := content.projectiles_art.angle_offset(group_id)
		var centre := position + Vector2(size, size) * 0.5
		# A continuous spin replaces the heading outright -- a shuriken does
		# not point where it is going -- while an additive one turns on top of
		# it. A wall's tiles only ever take the additive kind, because a
		# continuous one would break the line they are meant to form.
		var spin := content.projectiles_art.spin(group_id)
		var turn := ProjectileArt.spun(spin, clock.call())
		var additive: bool = spin.is_empty() or spin["additive"]
		if is_wall:
			_draw_wall(canvas, texture, centre, size, angle, offset,
				length, turn if additive else 0.0)
		else:
			var rotation := rotation_for(angle, offset, turn, additive)
			var afterimage: Color = content.projectiles_art.fx(group_id)["afterimage"]
			if afterimage.a > 0.0:
				BulletAfterimage.stamp(canvas, texture, centre, size, angle, rotation, afterimage)
				afterimaged += 1
			_draw_one(canvas, texture, centre, size, rotation, _take_outline())
	return drawn


## Where a bullet points. An additive spin turns on top of the heading; a
## continuous one replaces it outright, which is why a shuriken does not point
## where it is going.
static func rotation_for(angle: float, offset: float, turn: float,
		additive: bool) -> float:
	return (-angle + PI * 0.5 + offset + turn) if additive else turn


func _take_outline() -> bool:
	if outlined >= OUTLINE_BUDGET:
		return false
	outlined += 1
	return true


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


## Another player's shot with "Show other players' bullets" off, or any
## not ours out of sight while blind (Blind); ours always draw.
static func _hidden(state: RealmState, bullet: Dictionary) -> bool:
	var src := int(bullet.get("src_entity_id", 0))
	return not state.settings.is_on("show_other_bullets") and src != state.local.id \
		and state.entities.players.has(src) or Blind.hides_bullet(state, bullet)
