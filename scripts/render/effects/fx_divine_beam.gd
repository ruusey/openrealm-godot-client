class_name FxDivineBeam
extends RefCounted

## DIVINE_BEAM (56): the heavy buffer's pillar of light. A golden column
## rising from the ground, taller than it is wide, in three layers -- a
## pale glow, a gold core and a white spine -- over a ground halo of a
## gold ring, a white one and a pale fill, with eight sparkles rising.
## The column fades slower than the halo.


## The column's height: 2.2 of the radius.
static func beam_height(radius: float) -> float:
	return radius * 2.2


## The column's half-width: 0.35 of the radius, never under the web's
## 12 screen px (6 world).
static func beam_width(radius: float) -> float:
	return maxf(12.0 * Fx.S, radius * 0.35)


## Sparkle `i` of eight (x, y) and how far its rise has got (z, 0..1).
static func sparkle(at: Vector2, radius: float, i: int, progress: float) -> Vector3:
	var seed := i * 0.713
	var t := fmod(progress + seed, 1.0)
	var point := Fx.polar(at, seed * TAU, radius * (0.25 + 0.6 * fmod(seed * 11.0, 1.0)))
	return Vector3(point.x, point.y - t * radius * 0.7, t)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var gold := Color("ffd44c")
	var pale := Color("fff0a0")
	var height := beam_height(radius)
	var width := beam_width(radius)
	var column := alpha * (1.0 - progress * 0.4)
	canvas.draw_rect(Rect2(at.x - width, at.y - height, width * 2.0, height), Color(pale, column * 0.35))
	canvas.draw_rect(Rect2(at.x - width * 0.5, at.y - height, width, height), Color(gold, column * 0.65))
	canvas.draw_rect(Rect2(at.x - 3.0 * Fx.S, at.y - height, 6.0 * Fx.S, height), Color(Color.WHITE, column))
	Fx.ring(canvas, at, radius, 5.0, Color(gold, alpha * 0.9))
	Fx.ring(canvas, at, radius * 0.85, 3.0, Color(Color.WHITE, alpha))
	if radius > 0.0:
		canvas.draw_circle(at, radius * 0.7, Color(pale, alpha * 0.45))
	for i in 8:
		var s := sparkle(at, radius, i, progress)
		var point := Vector2(s.x, s.y)
		Fx.dot(canvas, point, 3.0, Color(Color.WHITE, alpha * (1.0 - s.z)))
		Fx.dot(canvas, point, 5.0, Color(gold, alpha * (1.0 - s.z) * 0.8))
