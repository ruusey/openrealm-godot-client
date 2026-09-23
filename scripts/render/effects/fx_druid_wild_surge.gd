class_name FxDruidWildSurge
extends RefCounted

## DRUID_WILD_SURGE (61): spiraling vines, bursting leaves, a verdant
## core. A deep green floor opening out by half way, three vine arms each
## winding one and a half turns from the centre to the radius while the
## whole spiral turns, eighteen leaves bursting outward and fading, and a
## pulsing yellow-green core.

const VINE := Color("40cc40")
const DEEP_GREEN := Color("1a661a")
const BRIGHT := Color("ccff4d")
const ARMS := 3
const SEGMENTS := 26
const LEAVES := 18


static func floor_radius(radius: float, progress: float) -> float:
	return radius * (0.6 + 0.4 * minf(1.0, progress * 2.0))


## Vine arm `arm`, from the centre (t = 0) out to the radius (t = 1).
static func vine(at: Vector2, radius: float, arm: int, elapsed_ms: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in SEGMENTS + 1:
		var t := float(s) / SEGMENTS
		points.append(Fx.polar(at, arm * TAU / ARMS + t * PI * 3.0 + elapsed_ms * 0.0014, radius * t))
	return points


## Leaf `i`: where it is and how bright. It flies from a fifth of the
## radius to the rim over each of its cycles.
static func leaf(at: Vector2, radius: float, i: int, progress: float, elapsed_ms: int) -> Array:
	var seed := i * 0.371
	var phase := fmod(progress * 1.3 + seed, 1.0)
	return [Fx.polar(at, seed * TAU + elapsed_ms * 0.0005, radius * (0.2 + 0.8 * phase)), sin(phase * PI)]


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, floor_radius(radius, progress), Color(DEEP_GREEN, alpha * 0.25))
	for arm in ARMS:
		canvas.draw_polyline(vine(at, radius, arm, elapsed_ms), Color(VINE, alpha * 0.9), 4.0 * Fx.S)
	for i in LEAVES:
		var l := leaf(at, radius, i, progress, elapsed_ms)
		var leaf_alpha: float = l[1] * alpha
		if leaf_alpha <= 0.05:
			continue
		Fx.dot(canvas, l[0], 5.0, Color(DEEP_GREEN, leaf_alpha * 0.85))
		Fx.dot(canvas, l[0], 2.5, Color(BRIGHT, leaf_alpha))
	var surge := 0.55 + 0.45 * sin(elapsed_ms * 0.006)
	Fx.dot(canvas, at, 14.0, Color("80f240", alpha * 0.7 * surge))
	Fx.dot(canvas, at, 7.0, Color("e6ff8c", alpha * surge))
