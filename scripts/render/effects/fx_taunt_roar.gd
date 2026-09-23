class_name FxTauntRoar
extends RefCounted

## TAUNT_ROAR (17): a brief red blink around the player -- a translucent
## red disc tightening a quarter as it fades, a bright red rim with a
## white one just inside it, and a small white highlight at the centre.
## No expanding rings, deliberately. It ignores the tier colour.


static func taunt_radius(radius: float, progress: float) -> float:
	return radius * (1.0 - 0.25 * progress)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var radius := taunt_radius(fx["radius"], progress)
	canvas.draw_circle(at, radius, Color("ff2030", alpha * 0.55))
	Fx.ring(canvas, at, radius, 4.0, Color("ff5060", alpha))
	Fx.ring(canvas, at, radius - 3.0 * Fx.S, 2.0, Color(Color.WHITE, alpha * 0.7))
	canvas.draw_circle(at, radius * 0.18, Color(Color.WHITE, alpha * 0.6))
