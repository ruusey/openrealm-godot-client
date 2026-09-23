class_name FxCombustionTrap
extends RefCounted

## COMBUSTION_TRAP (35): an orange explosion ring swelling from 40% of the
## radius to 110%, filled with fire, rimmed dark, orange and hot yellow
## from the outside in, with twelve embers scattered through it and
## turning, and a bright flash at the centre.

const FIRE := Color("ff6020")
const HOT := Color("ffe040")
const DARK := Color("804020")
const EMBERS := 12


static func ring_radius(radius: float, progress: float) -> float:
	return radius * (0.4 + 0.7 * progress)


## How far out ember `i` sits, as a share of the ring: fixed per ember,
## scattered by the web client's (seed * 13) mod 1.
static func ember_reach(i: int) -> float:
	return fmod(i * 0.491 * 13.0, 1.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var ring := ring_radius(fx["radius"], progress)
	canvas.draw_circle(at, ring, Color(FIRE, alpha * 0.45))
	Fx.ring(canvas, at, ring, 8.0, Color(DARK, alpha * 0.9))
	Fx.ring(canvas, at, ring - 4.0 * Fx.S, 5.0, Color(FIRE, alpha))
	Fx.ring(canvas, at, ring - 9.0 * Fx.S, 2.0, Color(HOT, alpha))
	for i in EMBERS:
		var angle := i * 0.491 * TAU + elapsed_ms * 0.002
		Fx.dot(canvas, Fx.polar(at, angle, ring * ember_reach(i)), 3.0, Color(HOT, alpha))
	canvas.draw_circle(at, ring * 0.2, Color(HOT, alpha * 0.85))
