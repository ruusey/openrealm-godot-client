class_name FxHealRadius
extends RefCounted

## HEAL_RADIUS (0): the priest's Healing Word. A soft green-white burst
## snapping out to the range by a quarter of the way in, a pulsing gold
## ring pinned at the heal radius with a pale green inner edge, eight
## slowly sweeping light beams, twelve healing motes rising, and a white
## flash at the cast.


## The burst's reach: full radius by 25%, easing out as a square root.
static func burst_radius(radius: float, progress: float) -> float:
	return radius * sqrt(minf(1.0, progress * 4.0))


## Where mote `i` of twelve is (x, y) and how far its rise has got (z,
## 0..1, looping about every 1.1 s): on its own spoke, at a distance fixed
## by its seed, lifted by up to half the radius.
static func mote(at: Vector2, radius: float, i: int, elapsed_ms: int) -> Vector3:
	var seed := i * 0.53
	var phase := fmod(elapsed_ms * 0.0009 + seed, 1.0)
	var distance := radius * (0.2 + 0.6 * fmod(seed * 17.0, 1.0))
	var point := Fx.polar(at, i * TAU / 12.0, distance) - Vector2(0.0, phase * radius * 0.5)
	return Vector3(point.x, point.y, phase)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var burst := burst_radius(radius, progress)
	if burst > 0.0:
		canvas.draw_circle(at, burst, Color("d8ffb0", alpha * 0.16))
		canvas.draw_circle(at, burst * 0.6, Color("80ff80", alpha * 0.12))
	var pulse := 0.8 + 0.2 * sin(elapsed_ms * 0.006)
	Fx.ring(canvas, at, radius, 5.0, Color("ffe64d", alpha * 0.9 * pulse))
	Fx.ring(canvas, at, radius * 0.97, 2.0, Color("bfffbf", alpha * 0.8))
	var beam := Color("ffffcc", alpha * 0.6)
	for i in 8:
		var angle := i * TAU / 8.0 + elapsed_ms * 0.0012
		Fx.line(canvas, Fx.polar(at, angle, burst * 0.2), Fx.polar(at, angle, burst * 0.95), 2.0, beam)
	for i in 12:
		var m := mote(at, radius, i, elapsed_ms)
		var mote_alpha := (1.0 - m.z) * alpha
		Fx.dot(canvas, Vector2(m.x, m.y), 2.2, Color("b3ffb3", mote_alpha * 0.9))
		Fx.dot(canvas, Vector2(m.x, m.y), 1.1, Color(Color.WHITE, mote_alpha * 0.7))
	if progress < 0.3:
		var flash := (0.3 - progress) / 0.3
		canvas.draw_circle(at, radius * 0.22 * (1.0 - progress), Color(Color.WHITE, flash * 0.8))
