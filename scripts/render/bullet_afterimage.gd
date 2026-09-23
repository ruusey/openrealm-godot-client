class_name BulletAfterimage
extends RefCounted

## The sticky trail behind a shot: five copies of its own sprite back along
## the flight line, each smaller, dimmer and tinted the group's trailColor.
##
## The web client's TRAIL_SEGMENTS, which its comment says match the native
## client's. Only straight, non-spinning shots carry one, so straight back
## along the heading -- minus (sin a, cos a) -- is exact.

const SEGMENTS := 5
## Spacing between copies, shrink per copy and the alpha of the nearest,
## all as fractions of the bullet's size or of one.
const SPACING := 0.34
const SHRINK := 0.12
const ALPHA := 0.55


## Where each copy goes, farthest first so the nearest is drawn on top:
## [{at, size, alpha}].
static func plan(centre: Vector2, size: float, angle: float, tint: Color) -> Array:
	var back := -Vector2(sin(angle), cos(angle))
	var copies: Array = []
	for i in range(SEGMENTS, 0, -1):
		var colour := tint
		colour.a = ALPHA * (1.0 - float(i) / SEGMENTS)
		copies.append({"at": centre + back * size * SPACING * i,
			"size": size * (1.0 - SHRINK * i), "colour": colour})
	return copies


static func stamp(canvas: CanvasItem, texture: Texture2D, centre: Vector2, size: float,
		angle: float, rotation: float, tint: Color) -> void:
	for copy in plan(centre, size, angle, tint):
		var half: float = copy["size"] * 0.5
		canvas.draw_set_transform(copy["at"], rotation, Vector2.ONE)
		canvas.draw_texture_rect(texture, Rect2(-half, -half, copy["size"], copy["size"]),
			false, copy["colour"])
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
