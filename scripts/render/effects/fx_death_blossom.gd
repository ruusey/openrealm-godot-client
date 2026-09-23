class_name FxDeathBlossom
extends RefCounted

## DEATH_BLOSSOM (30): the ninja's ultimate. Eight slash arcs just beyond
## the radius, evenly round the caster and turning a quarter turn over the
## effect's life, each a dark stroke under a bright blade, with a red dot
## at the centre.

const SLASHES := 8
const SWEEP := 0.42
const SEGMENTS := 6


static func reach(radius: float) -> float:
	return radius * 1.1


## Where slash `i` is centred: an eighth of a turn apart, and a quarter
## turn further round by the end.
static func slash_angle(i: int, progress: float) -> float:
	return float(i) / SLASHES * TAU + progress * PI * 0.5


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var r := reach(fx["radius"])
	for i in SLASHES:
		var centre := slash_angle(i, progress)
		FxBladeShapes.arc(canvas, at, centre, SWEEP, r, SEGMENTS, 6.0, Color("2a2030", alpha * 0.85))
		FxBladeShapes.arc(canvas, at, centre, SWEEP, r, SEGMENTS, 3.0, Color("e0e0f0", alpha))
	Fx.dot(canvas, at, 6.0, Color("ff4060", alpha))
