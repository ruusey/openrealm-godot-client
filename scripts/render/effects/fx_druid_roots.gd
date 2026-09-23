class_name FxDruidRoots
extends RefCounted

## DRUID_ROOTS (59): writhing roots erupt outward. A dark green floor,
## eleven bark tendrils that grow to the radius by 45% of the way and
## writhe as a sine wave travels along them, a leaf bud at each tip, a
## pulsing green ensnare ring, and a green knot at the centre.

const BARK := Color("52340f")
const LEAF := Color("4ad828")
const DEEP := Color("1a2e0c")
const TENDRILS := 11
const SEGMENTS := 9


static func grow(progress: float) -> float:
	return minf(1.0, progress * 2.2)


static func ensnare_radius(radius: float, progress: float) -> float:
	return radius * (0.6 + 0.4 * grow(progress))


## Tendril `i` from the centre to its tip. It sways sideways by up to 10
## web pixels, more toward the tip.
static func tendril(at: Vector2, radius: float, i: int, reach: float, elapsed_ms: int) -> PackedVector2Array:
	var angle := i * TAU / TENDRILS + i * 0.37
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var phase := elapsed_ms * 0.0016 + i
	var points := PackedVector2Array([at])
	for s in range(1, SEGMENTS + 1):
		var t := float(s) / SEGMENTS
		var wave := sin(phase + t * PI * 2.4) * 10.0 * Fx.S * t
		points.append(at + dir * radius * t * reach + perp * wave)
	return points


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, radius, Color(DEEP, alpha * 0.30))
	for i in TENDRILS:
		var points := tendril(at, radius, i, grow(progress), elapsed_ms)
		canvas.draw_polyline(points, Color(BARK, alpha * 0.9), 5.0 * Fx.S)
		var tip := points[points.size() - 1]
		Fx.dot(canvas, tip, 5.0, Color("2f8c28", alpha * 0.9))
		Fx.dot(canvas, tip, 2.5, Color(LEAF, alpha))
	var pulse := 0.55 + 0.45 * sin(elapsed_ms * 0.004)
	Fx.ring(canvas, at, ensnare_radius(radius, progress), 3.0, Color(LEAF, alpha * 0.7 * pulse))
	Fx.dot(canvas, at, 11.0, Color("2f7320", alpha * 0.8))
	Fx.dot(canvas, at, 6.0, Color("8cf266", alpha))
