class_name FxCaltrops
extends RefCounted

## CALTROPS (37): ten metal spikes scattered over a faint dark disc with a
## steel rim. Each is a small eight-armed star, dark with a white cross
## over it and a steel stud at the centre. They do not move: the places
## are fixed per spike, so the field is the same every frame.

const COUNT := 10
const STEEL := Color("b0b8c0")
const DARK := Color("404850")
## An arm's length, 6 web px.
const ARM := 6.0 * Fx.S


## Where caltrop `i` lies from the centre: its own angle, and out to at
## most 85% of the radius by the web client's (seed * 11) mod 0.85.
static func offset(radius: float, i: int) -> Vector2:
	var seed := i * 0.421
	var angle := seed * TAU
	return Vector2(cos(angle), sin(angle)) * radius * fmod(seed * 11.0, 0.85)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color(DARK, alpha * 0.18))
	Fx.ring(canvas, at, radius, 2.0, Color(STEEL, alpha * 0.5))
	var across := Vector2(ARM, 0.0)
	var down := Vector2(0.0, ARM)
	var diagonal := Vector2(ARM, ARM) * 0.7
	var anti := Vector2(ARM, -ARM) * 0.7
	for i in COUNT:
		var c := at + offset(radius, i)
		for arm in [across, down, diagonal, anti]:
			Fx.line(canvas, c - arm, c + arm, 3.0, Color(DARK, alpha))
		for arm in [across, down]:
			Fx.line(canvas, c - arm, c + arm, 1.0, Color(Color.WHITE, alpha))
		Fx.dot(canvas, c, 2.0, Color(STEEL, alpha))
