class_name FxDisarmFlourish
extends RefCounted

## DISARM_FLOURISH (55): the Heavy Debuffer's ultimate. Three gold rings
## cascading outward a little apart in time, eight twinkling four-point
## gold stars circling slowly just inside the radius, and a white-and-gold
## impact burst at the centre that is gone by 40% of the way.

const GOLD := Color("ffd24c")
const DEEP := Color("804808")


## How far ring `i` has got, 0..0.85, or -1 in the gap where it is hidden.
static func ring_phase(progress: float, i: int) -> float:
	var phase := fmod(progress + i * 0.18, 1.0)
	return -1.0 if phase > 0.85 else phase


static func ring_radius(radius: float, phase: float) -> float:
	return radius * (0.2 + phase)


static func star_radius(radius: float, progress: float) -> float:
	return radius * (0.7 + 0.25 * progress)


static func impact(progress: float) -> float:
	return maxf(0.0, 1.0 - progress * 2.5)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	for i in 3:
		var phase := ring_phase(progress, i)
		if phase < 0.0:
			continue
		var ring_alpha := alpha * (1.0 - phase) * 0.9
		Fx.ring(canvas, at, ring_radius(radius, phase), 6.0, Color(DEEP, ring_alpha * 0.6))
		Fx.ring(canvas, at, ring_radius(radius, phase), 3.0, Color(GOLD, ring_alpha))
	var orbit := star_radius(radius, progress)
	var point := (5.0 + 2.0 * (0.5 + 0.5 * sin(elapsed_ms * 0.024))) * Fx.S
	for i in 8:
		var star := Fx.polar(at, i * TAU / 8.0 + elapsed_ms * 0.001, orbit)
		var corners: Array = []
		for k in 4:
			corners.append(Fx.polar(star, k * TAU / 4.0, point))
		Fx.polygon(canvas, corners, Color(GOLD, alpha))
		Fx.dot(canvas, star, 2.0, Color(Color.WHITE, alpha))
	var early := impact(progress)
	if early > 0.0:
		# The web's order: white first, the wider gold over it.
		Fx.dot(canvas, at, 10.0 + 8.0 * early, Color(Color.WHITE, alpha * early))
		Fx.dot(canvas, at, 18.0 + 10.0 * early, Color(GOLD, alpha * early * 0.85))
