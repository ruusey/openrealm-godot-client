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


## Where mote `i` of `count` is (x, y) and how far its rise has got (z,
## 0..1, looping about every 1.1 s): on its own spoke, at a distance fixed
## by its seed, lifted by up to half the radius.
static func mote(at: Vector2, radius: float, i: int, elapsed_ms: int, count := 12) -> Vector3:
	var seed := i * 0.53
	var phase := fmod(elapsed_ms * 0.0009 + seed, 1.0)
	var distance := radius * (0.2 + 0.6 * fmod(seed * 17.0, 1.0))
	var point := Fx.polar(at, i * TAU / float(count), distance) - Vector2(0.0, phase * radius * 0.5)
	return Vector3(point.x, point.y, phase)


# This effect stacks ~4 deep per healer (server re-emits every 400ms, 1500ms life)
# and redraws every frame, so its primitive count is a hot path -- especially on
# the GL-compat web renderer, which can't batch immediate-mode 2D draws. The beams
# go out as one draw_multiline, motes are a single dot each, and web halves the
# mote/beam counts and ring segments on top.
static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var web := OS.has_feature("web")
	var alpha := 1.0 - progress
	var burst := burst_radius(radius, progress)
	if burst > 0.0:
		canvas.draw_circle(at, burst, Color("d8ffb0", alpha * 0.16))
		canvas.draw_circle(at, burst * 0.6, Color("80ff80", alpha * 0.12))
	var pulse := 0.8 + 0.2 * sin(elapsed_ms * 0.006)
	var segments := 24 if web else 40
	Fx.ring(canvas, at, radius, 5.0, Color("ffe64d", alpha * 0.9 * pulse), segments)
	Fx.ring(canvas, at, radius * 0.97, 2.0, Color("bfffbf", alpha * 0.8), segments)
	var beam := Color("ffffcc", alpha * 0.6)
	var beams := 6 if web else 8
	if beam.a > 0.001:
		var spokes := PackedVector2Array()
		for i in beams:
			var angle := i * TAU / float(beams) + elapsed_ms * 0.0012
			spokes.append(Fx.polar(at, angle, burst * 0.2))
			spokes.append(Fx.polar(at, angle, burst * 0.95))
		canvas.draw_multiline(spokes, beam, 2.0 * Fx.S)
	var motes := 6 if web else 12
	for i in motes:
		var m := mote(at, radius, i, elapsed_ms, motes)
		var mote_alpha := (1.0 - m.z) * alpha
		Fx.dot(canvas, Vector2(m.x, m.y), 2.4, Color("ccffcc", mote_alpha * 0.9))
	if progress < 0.3:
		var flash := (0.3 - progress) / 0.3
		canvas.draw_circle(at, radius * 0.22 * (1.0 - progress), Color(Color.WHITE, flash * 0.8))
