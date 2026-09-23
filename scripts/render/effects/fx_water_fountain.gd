class_name FxWaterFountain
extends RefCounted

## WATER_FOUNTAIN (15): the priest's cleanse, a blue purifying splash. A
## pale cast ring snapping out to the range, three staggered ripples
## spreading past the boundary, an aqua boundary with a faint fill and a
## cyan inner ring, six arcing streams of droplets fountaining out from
## the centre, twenty-four droplets rising inside, a deep-blue shock rim
## and cyan flash at the cast, and an eight-point white star at the heart
## that swells and dies over the life.

const AQUA := Color("40bfff")
const CYAN := Color("aaeeff")


## The splash's boundary: 0.7 of the radius at the cast, full by a third.
static func base_radius(radius: float, progress: float) -> float:
	return radius * (0.7 + 0.3 * minf(1.0, progress * 3.0))


## Where a droplet `t` of the way along a stream at `angle` is, from the
## centre: out along the stream, lifted by a parabola peaking at 0.55 of
## the boundary halfway out.
static func stream_point(base: float, angle: float, t: float) -> Vector2:
	var arc := -(4.0 * t * (1.0 - t)) * base * 0.55
	return Vector2(cos(angle), sin(angle)) * t * base * 0.95 + Vector2(0.0, arc)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var base := base_radius(radius, progress)
	Fx.ring(canvas, at, radius * sqrt(minf(1.0, progress * 4.0)), 4.0, Color("bfe6ff", alpha * 0.85 * (1.0 - progress)))
	Fx.ring(canvas, at, radius, 2.0, Color(Color.WHITE, alpha * 0.5))
	for w in 3:
		var t := Fx.wave(progress, w * 0.18)
		if t < 0.0:
			continue
		var ripple_alpha := alpha * (1.0 - t) * 0.55
		Fx.ring(canvas, at, base * (1.0 + t * 0.6), 2.0, Color(AQUA, ripple_alpha))
		Fx.ring(canvas, at, base * (1.0 + t * 0.6) * 0.96, 1.0, Color(CYAN, ripple_alpha * 0.85))
	Fx.ring(canvas, at, base, 3.0, Color(AQUA, alpha * 0.95))
	if base > 0.0:
		canvas.draw_circle(at, base, Color(AQUA, alpha * 0.10))
	Fx.ring(canvas, at, base * 0.62, 2.0, Color(CYAN, alpha * 0.85))
	for s in 6:
		var angle := s * TAU / 6.0 + elapsed_ms * 0.0008
		var stream_phase := fmod(progress * 1.3 + s * 0.166, 1.0)
		for d in 5:
			var t := fmod(d / 5.0 + stream_phase, 1.0)
			var drop_alpha := alpha * (1.0 - t) * 0.85
			if drop_alpha <= 0.05:
				continue
			var point := at + stream_point(base, angle, t)
			Fx.dot(canvas, point, 3.5, Color(AQUA, drop_alpha * 0.7))
			Fx.dot(canvas, point, 1.8, Color(CYAN, drop_alpha * 0.95))
	for i in 24:
		var seed := i * 0.5371 + 0.137
		var phase := fmod(progress * 1.4 + seed, 1.0)
		var mote_alpha := sin(phase * PI) * alpha
		if mote_alpha <= 0.04:
			continue
		var point := at + Vector2(fmod(seed * 2.0 - 1.0, 1.0) * base * 0.85, -phase * base * 1.6)
		var drop := 2.5 + 1.5 * sin(seed * 9.0 + phase * 6.0)
		Fx.dot(canvas, point, drop + 1.5, Color(AQUA, mote_alpha * 0.6))
		Fx.dot(canvas, point, drop * 0.65, Color(CYAN, minf(1.0, mote_alpha * 0.95)))
	if progress < 0.25:
		var flash := 1.0 - progress / 0.25
		Fx.ring(canvas, at, base * 0.75 * (1.0 + progress), 4.0, Color("1080d0", flash * 0.8))
		canvas.draw_circle(at, base * 0.50, Color(CYAN, flash * 0.9))
		canvas.draw_circle(at, base * 0.25, Color(Color.WHITE, flash * 0.7))
	var star := sin(progress * PI) * alpha
	if star > 0.05:
		for i in 8:
			var ray := i * TAU / 8.0 + progress * PI
			Fx.line(canvas, Fx.polar(at, ray, base * 0.10), Fx.polar(at, ray, base * 0.34), 2.0, Color(Color.WHITE, star * 0.9))
