class_name FxDeathPactAura
extends RefCounted

## DEATH_PACT_AURA (43): dark red wisps circling the caster. A dark pool
## inside a blood-red rim, and ten wisps -- a misty glow round a blood
## spark -- orbiting at their own distances.

const BLOOD := Color("a00020")


## How far out wisp `i` of the ten orbits: 40% to 100% of the radius.
static func wisp_orbit(radius: float, i: int) -> float:
	return radius * (0.4 + fmod(i * 0.671 * 7.0, 0.6))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("300010", alpha * 0.40))
	Fx.ring(canvas, at, radius, 2.0, Color(BLOOD, alpha * 0.85))
	for i in 10:
		var wisp := Fx.polar(at, i * 0.671 * TAU + elapsed_ms * 0.004, wisp_orbit(radius, i))
		Fx.dot(canvas, wisp, 5.0, Color("602030", alpha * 0.85))
		Fx.dot(canvas, wisp, 2.5, Color(BLOOD, alpha))
