class_name FxBeastClaws
extends RefCounted

## BEAST_CLAWS (28): three claw slashes raked around the caster, a third
## of a turn apart and slowly wheeling, each a short arc beyond the radius
## drawn three times over -- a dark shadow, the tan claw, a white edge.

const SLASHES := 3
const SWEEP := 0.55
const SEGMENTS := 8


static func reach(radius: float) -> float:
	return radius * 1.4


## Where slash `i` is centred, turning a radian a second.
static func slash_angle(i: int, elapsed_ms: int) -> float:
	return float(i) / SLASHES * TAU + elapsed_ms * 0.001


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var r := reach(fx["radius"])
	for i in SLASHES:
		var centre := slash_angle(i, elapsed_ms)
		FxBladeShapes.arc(canvas, at, centre, SWEEP, r, SEGMENTS, 7.0, Color("402010", alpha * 0.85))
		FxBladeShapes.arc(canvas, at, centre, SWEEP, r, SEGMENTS, 4.0, Color("d0a060", alpha))
		FxBladeShapes.arc(canvas, at, centre, SWEEP, r, SEGMENTS, 2.0, Color(Color.WHITE, alpha * 0.9))
