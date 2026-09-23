class_name FxShieldDome
extends RefCounted

## SHIELD_DOME (16): the knight's parry bulwark, a brushed-steel bubble.
## Re-sent every ~240ms while it holds, so it is deliberately static -- no
## pulse, no rotation, no flash, nothing that would strobe on a refresh:
## a translucent silver interior, a three-layer steel rim (dark, bright,
## highlight) and twelve fixed rivets. It ignores the tier colour.

const STUDS := 12


## The three rim strokes' radii: the web's r, r - 7 and r - 12 screen px.
static func rim_radii(radius: float) -> Array:
	return [radius, radius - 7.0 * Fx.S, radius - 12.0 * Fx.S]


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("b8bec8", alpha * 0.30))
	canvas.draw_circle(at, radius * 0.70, Color("e0e4ec", alpha * 0.16))
	var rims := rim_radii(radius)
	Fx.ring(canvas, at, rims[0], 10.0, Color("8c93a3", alpha))
	Fx.ring(canvas, at, rims[1], 5.0, Color("d2d8e0", alpha))
	Fx.ring(canvas, at, rims[2], 2.0, Color(Color.WHITE, alpha * 0.85))
	for i in STUDS:
		var stud := Fx.polar(at, i * TAU / STUDS, radius - 6.0 * Fx.S)
		Fx.dot(canvas, stud, 3.2, Color("9aa0ad", alpha * 0.9))
		Fx.dot(canvas, stud, 1.4, Color(Color.WHITE, alpha * 0.8))
