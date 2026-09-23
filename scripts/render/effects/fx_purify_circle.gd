class_name FxPurifyCircle
extends RefCounted

## PURIFY_CIRCLE (63): spawn protection, a white and gold cleansing ring.
## Snaps out to the radius, holds, and fades; a shockwave races ahead of it
## and twenty motes orbit the rim.


static func grow(progress: float) -> float:
	return minf(progress * 2.2, 1.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"] * grow(progress)
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("ffec8c", alpha * 0.18))
	var core := (0.5 + (0.3 - progress) * 1.5) if progress < 0.3 else 0.35
	canvas.draw_circle(at, radius * 0.45, Color("fffce0", alpha * maxf(0.0, core) * 0.5))
	Fx.ring(canvas, at, radius, 5.0, Color("ffd95a", alpha))
	Fx.ring(canvas, at, radius * 0.88, 2.5, Color("fffad9", alpha * 0.9))
	var shock: float = fx["radius"] * minf(progress * 1.6, 1.15)
	Fx.ring(canvas, at, shock, 3.0, Color("fff099", alpha * 0.5 * (1.0 - minf(progress * 1.4, 1.0))))
	var spin := progress * 3.2
	for i in 20:
		var angle := i * TAU / 20.0 + spin
		var reach := radius * (0.98 + 0.05 * sin(elapsed_ms * 0.01 + i))
		var twinkle := 0.6 + 0.4 * sin(elapsed_ms * 0.014 + i * 1.7)
		Fx.dot(canvas, Fx.polar(at, angle, reach), 2.2, Color("ffe680", alpha * twinkle))
