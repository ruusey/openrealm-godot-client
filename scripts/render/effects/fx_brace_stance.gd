class_name FxBraceStance
extends RefCounted

## BRACE_STANCE (18): a dark circle spreading out from the player with a
## steel rim, a white inner rim, eight spokes across the rim and four
## white studs on it, the decoration turning a quarter over its life. It
## ignores the tier colour.

const SPOKES := 8


static func brace_radius(radius: float, progress: float) -> float:
	return radius * (0.35 + 0.95 * progress)


## How far the decoration has turned: a quarter turn over the effect.
static func turn(progress: float) -> float:
	return progress * PI * 0.5


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var radius := brace_radius(fx["radius"], progress)
	var accent := Color("c8c8d4")
	canvas.draw_circle(at, radius, Color("101012", alpha * 0.70))
	Fx.ring(canvas, at, radius, 5.0, Color(accent, alpha))
	Fx.ring(canvas, at, radius - 4.0 * Fx.S, 2.0, Color(Color.WHITE, alpha * 0.8))
	for i in SPOKES:
		var angle := i * TAU / SPOKES + turn(progress)
		Fx.line(canvas, Fx.polar(at, angle, radius - 8.0 * Fx.S), Fx.polar(at, angle, radius + 6.0 * Fx.S),
			3.0, Color(accent, alpha * 0.95))
	for i in 4:
		Fx.dot(canvas, Fx.polar(at, i * TAU / 4.0 + turn(progress), radius), 3.0, Color(Color.WHITE, alpha))
