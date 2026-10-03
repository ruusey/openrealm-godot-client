class_name FxPoisonCloud
extends RefCounted

## POISON_CLOUD (22): a sickly venom burst. A deep-green pool under a toxic
## one, rimmed dark over pale with a faint inner ring, nine bubbles
## drifting and swelling on their own beats with bright hearts, fumes
## curling off the top, and a sickly flash as it takes -- the Assassin's
## Imbue Poison igniting on the cast.

const TOXIC := Color("60c020")
const GLOW := Color("aaff80")
const DEEP := Color("305010")
const FUME := Color("86d84a")


## How far from the centre bubble `i` drifts, on its own slow orbit.
static func bubble_distance(radius: float, i: int) -> float:
	return radius * (0.2 + 0.55 * fposmod(i * 0.591 * 17.0, 1.0))


## Bubble `i`'s size in web px, swelling on a beat set by its index.
static func bubble_px(elapsed_ms: int, i: int) -> float:
	return 4.0 + 2.2 * sin(elapsed_ms * 0.008 + i * 1.4)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color(DEEP, alpha * 0.35))
	canvas.draw_circle(at, radius * 0.85, Color(TOXIC, alpha * 0.4))
	Fx.ring(canvas, at, radius, 4.0, Color(DEEP, alpha * 0.6))
	Fx.ring(canvas, at, radius, 2.0, Color(GLOW, alpha * 0.85))
	Fx.ring(canvas, at, radius * 0.6, 1.5, Color(GLOW, alpha * 0.4))
	for i in 9:
		var bubble := Fx.polar(at, i * 0.591 * TAU + elapsed_ms * 0.001, bubble_distance(radius, i))
		var size := bubble_px(elapsed_ms, i)
		Fx.dot(canvas, bubble, size + 1.0, Color(TOXIC, alpha * 0.75))
		Fx.dot(canvas, bubble, size * 0.55, Color(GLOW, alpha * 0.9))
	_fumes(canvas, at, radius, progress, alpha)
	if progress < 0.2:
		var t := 1.0 - progress / 0.2
		Fx.dot(canvas, at, radius * 0.5 * t + 4.0, Color(GLOW, t * 0.7))


## Fumes curling up off the cloud and thinning out, from a fixed scatter.
static func _fumes(canvas: CanvasItem, at: Vector2, radius: float, progress: float, alpha: float) -> void:
	for i in 5:
		var seed := i * 0.734
		var spread := (fposmod(seed * 9.0, 1.0) - 0.5) * radius * 1.2
		var climb := fposmod(progress + seed, 1.0)
		var pos := at + Vector2(spread, -radius * (0.4 + 1.3 * climb))
		Fx.dot(canvas, pos, 3.0 * (1.0 - climb), Color(FUME, alpha * 0.6))
