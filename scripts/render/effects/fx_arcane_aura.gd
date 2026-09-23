class_name FxArcaneAura
extends RefCounted

## ARCANE_AURA (38): a violet aura round the caster. A faint disc, a pale
## violet rim, and eight sparks orbiting just inside it, each breathing in
## and out on its own phase, a white point in a violet glow.

const ARC := Color("9040ff")
const HOT := Color("c080ff")
const SPARKS := 8


static func spark_angle(i: int, elapsed_ms: int) -> float:
	return float(i) / SPARKS * TAU + elapsed_ms * 0.005


## Spark `i`'s orbit: 85% of the radius, give or take 15.
static func orbit_radius(radius: float, i: int, elapsed_ms: int) -> float:
	return radius * (0.85 + sin(elapsed_ms * 0.01 + i) * 0.15)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, radius, Color(ARC, alpha * 0.20))
	Fx.ring(canvas, at, radius, 3.0, Color(HOT, alpha * 0.9))
	for i in SPARKS:
		var spark := Fx.polar(at, spark_angle(i, elapsed_ms), orbit_radius(radius, i, elapsed_ms))
		Fx.dot(canvas, spark, 4.0, Color(HOT, alpha))
		Fx.dot(canvas, spark, 1.8, Color(Color.WHITE, alpha))
