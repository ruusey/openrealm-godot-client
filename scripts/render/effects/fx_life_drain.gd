class_name FxLifeDrain
extends RefCounted

## LIFE_DRAIN (23): red ribbons spiralling inward to the caster. A faint
## blood pool inside a dark rim, three streams winding from the rim to
## the centre as they turn, and a core -- a white spark under a red one,
## in the web client's order, so the white shows only as the core fades.

const BLOOD := Color("c00020")
const SEGMENTS := 20


## How far out a stream is `t` of the way along it: the rim at 0, and 4
## web px short of the centre at 1.
static func stream_radius(radius: float, t: float) -> float:
	return radius * (1.0 - t) + 4.0 * Fx.S


## The stream's angle `t` along arm `arm` of three: it turns four radians
## on the way in, and the whole spiral turns with time.
static func stream_angle(arm: int, t: float, elapsed_ms: int) -> float:
	return arm * TAU / 3.0 + t * 4.0 + elapsed_ms * 0.004


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color(BLOOD, alpha * 0.20))
	Fx.ring(canvas, at, radius, 2.0, Color("500010", alpha * 0.95))
	for arm in 3:
		# The web stops a segment short of the centre: nineteen of twenty.
		for s in SEGMENTS - 1:
			var t0 := float(s) / SEGMENTS
			var t1 := float(s + 1) / SEGMENTS
			Fx.line(canvas, Fx.polar(at, stream_angle(arm, t0, elapsed_ms), stream_radius(radius, t0)),
				Fx.polar(at, stream_angle(arm, t1, elapsed_ms), stream_radius(radius, t1)), 3.0, Color(BLOOD, alpha))
	Fx.dot(canvas, at, 4.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 8.0, Color(BLOOD, alpha))
