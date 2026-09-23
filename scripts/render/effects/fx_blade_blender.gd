class_name FxBladeBlender
extends RefCounted

## BLADE_BLENDER (47): a field of nine shurikens on a turning spiral over a
## dark disc ringed in red. Like the blade orbit, the server re-sends it
## while it runs and only the newest draws, so the spiral's turn comes from
## the clock (started + elapsed) and sweeps on across refreshes; the disc
## and its ring fade with the packet, the blades stay at full strength.
## The web client draws the tier's shuriken sprite; this is FxBladeShapes'
## vector star.

const BLADES := 9
## The web's 20 * SCALE screen pixels: 20 world units across.
const SIZE := 20.0
const TURNS := 1.4


## Where blade `i` sits from the centre: out along an Archimedean spiral
## of 1.4 turns from 0.15 of the radius to nearly all of it, the whole
## spiral turning about 1.8 radians a second.
static func blade_offset(i: int, radius: float, clock_ms: int) -> Vector2:
	var t := float(i + 1) / (BLADES + 1)
	var angle := clock_ms * 0.0018 + t * TAU * TURNS
	return Vector2(cos(angle), sin(angle)) * radius * (0.15 + 0.85 * t)


## A blade's own spin: ten radians a second, each one set apart.
static func spin(i: int, clock_ms: int) -> float:
	return clock_ms * 0.010 + i * 0.9


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var radius: float = fx["radius"]
	var now := FxBladeOrbit.clock(fx, elapsed_ms)
	canvas.draw_circle(at, radius, Color("100808", alpha * 0.45))
	Fx.ring(canvas, at, radius, 2.0, Color("c02030", alpha * 0.6))
	for i in BLADES:
		FxBladeShapes.shuriken(canvas, at + blade_offset(i, radius, now), spin(i, now), SIZE, colour, 1.0)
