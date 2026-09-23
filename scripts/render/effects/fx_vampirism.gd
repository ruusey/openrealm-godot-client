class_name FxVampirism
extends RefCounted

## VAMPIRISM (1): the necromancer's life-drain spiral. A dark-purple pool
## inside a ring in the tier's colour, a pulsing magenta inner ring over a
## necrotic core, thirty-two magenta motes on two rings closing on the
## caster as it runs, six soul tendrils wobbling in from the rim, a
## breathing skull glyph at the centre and a throbbing blood-red core.

const MAGENTA := Color("ff60ff")
## The web draws no skull under 4 of its pixels.
const SKULL_MIN := 4.0 * Fx.S


## How far out mote `i` of the thirty-two is: even ones ride the outer
## ring, odd ones the inner, and both close on the centre as it runs.
static func mote_distance(radius: float, progress: float, i: int) -> float:
	return radius * (1.0 - progress) * (0.4 + 0.6 * (1.0 if i % 2 == 0 else 0.65))


## A tendril's sideways wobble `tt` of the way in, in world units: 6 web
## px at most, dying to nothing at the centre.
static func tendril_wobble(tt: float, phase: float) -> float:
	return sin(tt * TAU + phase) * 6.0 * Fx.S * (1.0 - tt)


static func skull_size(radius: float, elapsed_ms: int) -> float:
	return radius * 0.16 * (0.9 + 0.15 * sin(elapsed_ms * 0.018))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("4a0a4a", alpha * 0.18))
	Fx.ring(canvas, at, radius, 3.0, Color(colour, alpha * 0.9))
	var inner := 0.55 + 0.45 * sin(elapsed_ms * 0.014)
	Fx.ring(canvas, at, radius * 0.65, 2.0, Color(MAGENTA, alpha * 0.5 * inner))
	canvas.draw_circle(at, radius * 0.55, Color("1a0008", alpha * 0.25 * inner))
	for i in 32:
		var mote := Fx.polar(at, i * TAU / 32.0 + elapsed_ms * 0.005, mote_distance(radius, progress, i))
		Fx.dot(canvas, mote, 4.0 + (1.0 - progress) * 3.0, Color(MAGENTA, alpha * 0.85))
		Fx.dot(canvas, mote, 7.0 + (1.0 - progress) * 4.0, Color("cc20cc", alpha * 0.35))
	for t in 6:
		var start_angle := t * TAU / 6.0 + elapsed_ms * 0.002
		var start := Fx.polar(at, start_angle, radius * 0.95)
		var side := Vector2(cos(start_angle + PI * 0.5), sin(start_angle + PI * 0.5))
		var strand := Color("ff80ff", alpha * (0.55 + 0.35 * sin(elapsed_ms * 0.01 + t)) * (1.0 - progress * 0.3))
		var previous := start
		for s in range(1, 7):
			var tt := s / 6.0
			var point := at + (start - at) * (1.0 - tt) + side * tendril_wobble(tt, elapsed_ms * 0.012 + t * 1.3)
			Fx.line(canvas, previous, point, 3.0, strand)
			previous = point
	var skull := skull_size(radius, elapsed_ms)
	if skull > SKULL_MIN:
		var bone := Color("e0c0e8", alpha * 0.85)
		canvas.draw_circle(at + Vector2(0.0, -skull * 0.25), skull, bone)
		canvas.draw_rect(Rect2(at.x - skull * 0.7, at.y + skull * 0.35, skull * 1.4, skull * 0.55), bone)
		for x in [-0.4, 0.4]:
			canvas.draw_circle(at + Vector2(skull * x, -skull * 0.2), skull * 0.22, Color("100008", alpha * 0.95))
	var core := 0.6 + 0.4 * sin(elapsed_ms * 0.02)
	canvas.draw_circle(at, radius * 0.35 * (1.0 - progress * 0.6), Color("ff2030", alpha * 0.5 * core))
	canvas.draw_circle(at, radius * 0.18 * (1.0 - progress * 0.5), Color("ffa0a0", alpha * 0.7))
