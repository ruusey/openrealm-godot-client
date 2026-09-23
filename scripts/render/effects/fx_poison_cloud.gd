class_name FxPoisonCloud
extends RefCounted

## POISON_CLOUD (22): a sickly green cloud. A deep-green pool under a
## toxic one, a pale glowing rim, and nine bubbles drifting slowly round
## inside it, each swelling and shrinking with a bright heart.

const TOXIC := Color("60c020")
const GLOW := Color("aaff80")


## How far from the centre bubble `i` of the nine drifts.
static func bubble_distance(radius: float, i: int) -> float:
	return radius * (0.2 + 0.55 * fposmod(i * 0.591 * 17.0, 1.0))


## Bubble `i`'s size in web px, 2 to 6, swelling on its own beat.
static func bubble_px(elapsed_ms: int, i: int) -> float:
	return 4.0 + 2.0 * sin(elapsed_ms * 0.008 + i * 0.591 * 7.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("305010", alpha * 0.35))
	canvas.draw_circle(at, radius * 0.85, Color(TOXIC, alpha * 0.40))
	Fx.ring(canvas, at, radius, 2.0, Color(GLOW, alpha * 0.85))
	for i in 9:
		var bubble := Fx.polar(at, i * 0.591 * TAU + elapsed_ms * 0.001, bubble_distance(radius, i))
		var size := bubble_px(elapsed_ms, i)
		Fx.dot(canvas, bubble, size + 1.0, Color(TOXIC, alpha * 0.75))
		Fx.dot(canvas, bubble, size * 0.55, Color(GLOW, alpha * 0.9))
