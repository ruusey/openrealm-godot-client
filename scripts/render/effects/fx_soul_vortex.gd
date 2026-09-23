class_name FxSoulVortex
extends RefCounted

## SOUL_VORTEX (45): the necromancer's ultimate, a swirling drain. A dark
## disc washed violet inside a crimson rim and a violet inner ring, three
## pink soul-streamers spiralling from the rim to the centre with a
## crimson trailing edge, the whole churning; fourteen motes orbiting and
## pulsing as they sink, and a bright core everything spirals into.

const VIOLET := Color("8030c0")
const CRIMSON := Color("c01040")
const WISP := Color("ff80ff")
const SEGMENTS := 28


## How far out an arm is `t` of the way in: the rim (plus 2 web px) at 0,
## a twentieth of the radius at 1.
static func arm_radius(radius: float, t: float) -> float:
	return radius * (1.0 - t * 0.95) + 2.0 * Fx.S


## Mote `i`'s phase in its rise-and-sink, 0..1.
static func mote_phase(progress: float, i: int) -> float:
	return fmod(progress * 1.2 + i * 0.421 + 0.137, 1.0)


## How far out mote `i` orbits: its own band, drawn inward as it sinks.
static func mote_orbit(radius: float, progress: float, i: int) -> float:
	var seed := i * 0.421 + 0.137
	return radius * (0.15 + 0.7 * fposmod(seed * 17.0, 1.0)) * (1.0 - mote_phase(progress, i) * 0.4)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("200818", alpha * 0.55))
	canvas.draw_circle(at, radius * 0.92, Color(VIOLET, alpha * 0.25))
	Fx.ring(canvas, at, radius, 3.0, Color(CRIMSON, alpha * 0.9))
	Fx.ring(canvas, at, radius * 0.78, 2.0, Color(VIOLET, alpha * 0.85))
	for arm in 3:
		var turn := arm * TAU / 3.0 + elapsed_ms * 0.006
		_spiral(canvas, at, radius, turn, 3.0, Color(WISP, alpha * 0.95))
		_spiral(canvas, at, radius, turn - 0.18, 2.0, Color(CRIMSON, alpha * 0.7))
	for i in 14:
		var phase := mote_phase(progress, i)
		var mote_alpha := sin(phase * PI) * alpha
		if mote_alpha <= 0.05:
			continue
		var angle := (i * 0.421 + 0.137) * TAU + elapsed_ms * 0.004 + phase * 2.0
		var mote := Fx.polar(at, angle, mote_orbit(radius, progress, i))
		Fx.dot(canvas, mote, 5.0, Color(VIOLET, mote_alpha * 0.8))
		Fx.dot(canvas, mote, 2.2, Color(WISP, mote_alpha))
	Fx.dot(canvas, at, 9.0, Color(CRIMSON, alpha * 0.8))
	Fx.dot(canvas, at, 4.0, Color(WISP, alpha))


## One arm from rim to centre, 2.8 half-turns round.
static func _spiral(canvas: CanvasItem, at: Vector2, radius: float, turn: float, width_px: float, colour: Color) -> void:
	var previous := Fx.polar(at, turn, arm_radius(radius, 0.0))
	for s in range(1, SEGMENTS + 1):
		var t := float(s) / SEGMENTS
		var point := Fx.polar(at, turn + t * PI * 2.8, arm_radius(radius, t))
		Fx.line(canvas, previous, point, width_px, colour)
		previous = point
