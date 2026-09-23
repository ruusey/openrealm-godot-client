class_name FxStormAura
extends RefCounted

## STORM_AURA (42): a crackling aura round the caster. A dark storm-blue
## disc, a yellow rim, five zigzag bolts from the centre to the rim that
## turn and lurch as a group while each joint jitters, and a white core.

const ELEC := Color("fff060")
const STORM := Color("202848")
const BOLTS := 5
const SEGMENTS := 5


## Bolt `i`: from the centre out to the rim in five joints, each bent off
## the bolt's heading by up to 0.16 rad (the web's 8 * 0.02).
static func bolt(at: Vector2, radius: float, i: int, elapsed_ms: int) -> PackedVector2Array:
	var heading := float(i) / BOLTS * TAU + elapsed_ms * 0.003 + sin(elapsed_ms * 0.01 + i)
	var points := PackedVector2Array([at])
	for s in range(1, SEGMENTS + 1):
		var wobble := sin(elapsed_ms * 0.03 + s + i) * 8.0
		points.append(Fx.polar(at, heading + wobble * 0.02, radius * float(s) / SEGMENTS))
	return points


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, radius, Color(STORM, alpha * 0.25))
	Fx.ring(canvas, at, radius, 2.0, Color(ELEC, alpha * 0.75))
	for i in BOLTS:
		canvas.draw_polyline(bolt(at, radius, i, elapsed_ms), Color(ELEC, alpha), 3.0 * Fx.S)
	Fx.dot(canvas, at, 5.0, Color(Color.WHITE, alpha))
