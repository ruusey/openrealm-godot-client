class_name FxBladeStorm
extends RefCounted

## BLADE_STORM (44): two long blades whirling about the caster, each a
## line through the centre reaching 0.85 of the radius either side, drawn
## as a dark trace, a steel blade and a white edge, round a white pivot.


static func orbit_radius(radius: float) -> float:
	return radius * 0.85


## The whirl: 25 radians a second.
static func spin(elapsed_ms: int) -> float:
	return elapsed_ms * 0.025


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var reach := orbit_radius(fx["radius"])
	for i in 2:
		var angle := spin(elapsed_ms) + i * PI
		var from := Fx.polar(at, angle, reach)
		var to := Fx.polar(at, angle + PI, reach)
		Fx.line(canvas, from, to, 7.0, Color("202028", alpha * 0.85))
		Fx.line(canvas, from, to, 4.0, Color("e0e0f0", alpha))
		Fx.line(canvas, from, to, 2.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 5.0, Color(Color.WHITE, alpha))
