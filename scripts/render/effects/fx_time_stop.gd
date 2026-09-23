class_name FxTimeStop
extends RefCounted

## TIME_STOP (27): a stopped clock face on the ground. A dim slate disc, a
## silver rim with a white one just inside it, twelve hour ticks, and two
## hands frozen at a fixed hour -- no rotation, time is stopped -- round a
## white pivot.

const SILVER := Color("c0d0e0")
const DEEP := Color("404858")


## Tick `i` of twelve: from 6 to 14 web px inside the rim.
static func tick(at: Vector2, radius: float, i: int) -> PackedVector2Array:
	var angle := float(i) / 12.0 * TAU
	return PackedVector2Array([Fx.polar(at, angle, radius - 6.0 * Fx.S), Fx.polar(at, angle, radius - 14.0 * Fx.S)])


## The hands' tips, hour then minute, as offsets from the centre.
static func hands(radius: float) -> Array:
	return [Vector2(0.0, -radius * 0.55), Vector2(radius * 0.7, radius * 0.1)]


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, radius, Color(DEEP, alpha * 0.20))
	Fx.ring(canvas, at, radius, 5.0, Color(SILVER, alpha * 0.95))
	Fx.ring(canvas, at, radius - 3.0 * Fx.S, 2.0, Color(Color.WHITE, alpha))
	for i in 12:
		var mark := tick(at, radius, i)
		Fx.line(canvas, mark[0], mark[1], 3.0, Color(SILVER, alpha))
	var tips := hands(radius)
	Fx.line(canvas, at, at + tips[0], 4.0, Color(Color.WHITE, alpha))
	Fx.line(canvas, at, at + tips[1], 3.0, Color(SILVER, alpha))
	Fx.dot(canvas, at, 5.0, Color(Color.WHITE, alpha))
