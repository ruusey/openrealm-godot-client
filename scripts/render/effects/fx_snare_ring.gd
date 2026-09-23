class_name FxSnareRing
extends RefCounted

## The armed snare both trap effects lie as on the ground: TRAP_PLACED (7),
## and TRAP_THROW (6) once it has landed. The web client's _drawSnareRing.
##
## A tier wash with a darker centre, a chunky tier ring and a white one
## inside it, an amber inner ring, fourteen teeth on the rim pointing IN
## toward the trigger -- jaws, slowly turning -- a pulsing trigger dot and
## an amber cross through it. The whole pulses; it fades over its last 15%.

const TEETH := 14
const AMBER := Color("ffaa44")


## Full until 85% of the way, then down to nothing.
static func fade(progress: float) -> float:
	return (1.0 - progress) / 0.15 if progress > 0.85 else 1.0


## How far in from the rim a tooth's tip reaches: 14 web px at least, so a
## small trap still has teeth, and 18% of the radius on a big one.
static func tip_depth(radius: float) -> float:
	return maxf(14.0 * Fx.S, radius * 0.18)


## Half the angle a tooth's base spans on the rim.
static func base_half_angle() -> float:
	return PI / TEETH * 0.7


static func paint(canvas: CanvasItem, at: Vector2, radius: float, progress: float,
		colour: Color, elapsed_ms: int) -> void:
	var alpha := 1.0 - progress
	var fading := fade(progress)
	var a := fading * (0.7 + 0.3 * sin(elapsed_ms * 0.004)) * alpha
	var inner := radius * 0.7
	canvas.draw_circle(at, radius, Color(colour, fading * 0.22))
	canvas.draw_circle(at, inner, Color(Color.BLACK, fading * 0.18))
	Fx.ring(canvas, at, radius, 6.0, Color(colour, a * 0.95))
	Fx.ring(canvas, at, radius * 0.97, 3.0, Color(Color.WHITE, a * 0.9))
	Fx.ring(canvas, at, inner, 2.0, Color(AMBER, a * 0.85))
	var half := base_half_angle()
	var tip_r := radius - tip_depth(radius)
	var base_r := radius * 0.99
	var rot := elapsed_ms * 0.0015
	for i in TEETH:
		var angle := i * TAU / TEETH + rot
		var tip := Fx.polar(at, angle, tip_r)
		var halo_reach := base_r + 4.0 * Fx.S
		Fx.polygon(canvas, [Fx.polar(at, angle - half, halo_reach), tip,
			Fx.polar(at, angle + half, halo_reach)], Color(colour, a * 0.55))
		Fx.polygon(canvas, [Fx.polar(at, angle - half, base_r), tip,
			Fx.polar(at, angle + half, base_r)], Color("ffeecc", a * 0.95))
		Fx.dot(canvas, tip, 1.6, Color("442200", a * 0.85))
	var core := 0.6 + 0.4 * sin(elapsed_ms * 0.012)
	Fx.dot(canvas, at, 6.0, Color(colour, a * 0.7 * core))
	Fx.dot(canvas, at, 3.0, Color(Color.WHITE, a * 0.95))
	var cross := inner * 0.55
	Fx.line(canvas, at - Vector2(cross, cross), at + Vector2(cross, cross), 2.0, Color(AMBER, a * 0.55))
	Fx.line(canvas, at + Vector2(cross, -cross), at + Vector2(-cross, cross), 2.0, Color(AMBER, a * 0.55))
