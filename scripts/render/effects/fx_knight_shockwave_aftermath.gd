class_name FxKnightShockwaveAftermath
extends RefCounted

## What KNIGHT_SHOCKWAVE's slam leaves behind: from the thrust's end, two
## shock rings a beat apart and fourteen chunks of debris sprayed forward
## in earth and the tier colour; from the wind-up's end to 85%, five
## jagged brown fissures fanning forward. All deterministic on the index,
## as the web's are -- nothing here is rolled.

const DEBRIS := 14
const CRACKS := 5
const CRACKS_END := 0.85


## How far the aftermath has run, 0..1, or -1 before the thrust ends.
static func after(progress: float) -> float:
	var end := FxKnightShockwave.THRUST_END
	return (progress - end) / (1.0 - end) if progress >= end else -1.0


## The two rings' radii in world units at aftermath `t`; the second is 0
## until 30% in.
static func ring_radii(t: float) -> Vector2:
	var second := 0.0
	if t > 0.30:
		second = (24.0 + (t - 0.30) / 0.70 * 78.0) * Fx.S
	return Vector2((30.0 + t * 100.0) * Fx.S, second)


## Where debris chunk `i` is at aftermath `t`, relative to the slam: a
## cubic ease out along a forward-biased spread, sagging as it flies.
static func debris_offset(dir: Vector2, i: int, t: float) -> Vector2:
	var angle := dir.angle() + (float(i) / DEBRIS - 0.5) * PI * 1.5 + i * 1.3 * 0.02
	var distance := (70.0 + (0.7 + fmod(i * 0.193, 1.0) * 0.6) * 60.0) * Fx.S
	var eased := 1.0 - pow(1.0 - minf(1.0, t * 1.3), 3.0)
	return Vector2(cos(angle), sin(angle)) * distance * eased + Vector2(0.0, eased * eased * 14.0 * Fx.S)


static func draw(canvas: CanvasItem, slam: Vector2, dir: Vector2, progress: float, alpha: float,
		colour: Color) -> void:
	var t := after(progress)
	if t >= 0.0:
		_rings(canvas, slam, t, alpha, colour)
		_debris(canvas, slam, dir, t, alpha, colour)
	if progress >= FxKnightShockwave.WINDUP_END and progress <= CRACKS_END:
		_fissures(canvas, slam, dir, progress, alpha)


static func _rings(canvas: CanvasItem, slam: Vector2, t: float, alpha: float, colour: Color) -> void:
	var radii := ring_radii(t)
	var first := alpha * (1.0 - t) * 0.95
	Fx.ring(canvas, slam, radii.x, 7.0, Color(colour, first))
	Fx.ring(canvas, slam, radii.x * 0.93, 3.0, Color(Color.WHITE, first))
	if radii.y > 0.0:
		Fx.ring(canvas, slam, radii.y, 4.0, Color(colour, alpha * (1.0 - (t - 0.30) / 0.70) * 0.70))


static func _debris(canvas: CanvasItem, slam: Vector2, dir: Vector2, t: float, alpha: float,
		colour: Color) -> void:
	var eased := 1.0 - pow(1.0 - minf(1.0, t * 1.3), 3.0)
	var chunk_alpha := alpha * (1.0 - eased) * 0.9
	for i in DEBRIS:
		var chunk := slam + debris_offset(dir, i, t)
		var size := 2.5 + (i % 3) * 1.5
		var even := i % 2 == 0
		Fx.dot(canvas, chunk, size, Color(colour if even else Color("6b4423"), chunk_alpha))
		if even:
			Fx.dot(canvas, chunk - Vector2.ONE * size * 0.3 * Fx.S, size * 0.4, Color(Color.WHITE, chunk_alpha * 0.6))


static func _fissures(canvas: CanvasItem, slam: Vector2, dir: Vector2, progress: float, alpha: float) -> void:
	var start := FxKnightShockwave.WINDUP_END
	var ct := (progress - start) / (CRACKS_END - start)
	var length := (40.0 + ct * 50.0) * Fx.S
	var tint := Color("2a1810", alpha * (1.0 - ct * 0.8) * 0.55)
	for i in CRACKS:
		var angle := dir.angle() + (float(i) / (CRACKS - 1) - 0.5) * PI * 0.7
		var across := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
		var previous := slam
		for s in range(1, 4):
			var jag := sin(i * 4.3 + s * 1.7) * 5.0 * Fx.S
			var point := Fx.polar(slam, angle, length * s / 3.0) + across * jag
			Fx.line(canvas, previous, point, 3.0, tint)
			previous = point
