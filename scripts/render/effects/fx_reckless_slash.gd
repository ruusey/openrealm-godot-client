class_name FxRecklessSlash
extends RefCounted

## RECKLESS_SLASH (32): the Barbarian's Butcher -- a wide forward cleave along the
## caster-to-strike axis (Fx.facing), not the old fixed rightward sweep. A dark gore
## trace, the red blade and a white leading edge sweep across the front over the first
## half; then the arc hangs and fades. Matches the reworked melee strikes' directional
## read, just wider and redder for a two-handed swing.

const SWEEP := 1.9
const GORE := Color("600010")
const BLADE := Color("ff2030")


static func reach(radius: float) -> float:
	return maxf(radius, 28.0) * 1.1


## How far the cleave has travelled, 0..1, across the first half of the life.
static func sweep_t(progress: float) -> float:
	return minf(1.0, progress / 0.5)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var r := reach(fx["radius"])
	var base := Fx.facing(fx).angle()
	var t := sweep_t(progress)
	var start_a := base - SWEEP * 0.5
	var lead_a := start_a + SWEEP * t
	var segments := maxi(2, int(16 * t))
	canvas.draw_arc(at, r, start_a, lead_a, segments + 1, Color(GORE, alpha * 0.85), 12.0 * Fx.S)
	canvas.draw_arc(at, r, start_a, lead_a, segments + 1, Color(BLADE, alpha), 7.0 * Fx.S)
	canvas.draw_arc(at, r, start_a, lead_a, segments + 1, Color(Color.WHITE, alpha * 0.9), 3.0 * Fx.S)
	if t < 1.0:
		# The leading edge: a bright blade standing across the arc as it cleaves.
		var lead := Fx.polar(at, lead_a, r)
		var tangent := Vector2(-sin(lead_a), cos(lead_a))
		Fx.line(canvas, lead - tangent * 11.0 * Fx.S, lead + tangent * 11.0 * Fx.S, 4.0, Color(Color.WHITE, alpha))
		Fx.dot(canvas, lead, 3.5, Color(Color.WHITE, alpha))
