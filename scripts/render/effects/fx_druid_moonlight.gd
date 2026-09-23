class_name FxDruidMoonlight
extends RefCounted

## DRUID_MOONLIGHT (60): a night aura. A deep blue floor, a silver ring
## opening out to the radius, six soft moonbeams slanting down into the
## centre as they slowly turn, fourteen healing motes rising and fading,
## and a crescent moon over the caster, cut from a disc by a night-blue
## one offset up and right.

const NIGHT := Color("1a1f4d")
const SILVER := Color("d8e4ff")
const SOFT := Color("b3c6ff")
const MOTES := 14


static func ring_radius(radius: float, progress: float) -> float:
	return radius * (0.35 + 0.65 * minf(1.0, progress * 1.8))


## The moon's radius in web pixels, breathing by two.
static func moon_px(elapsed_ms: int) -> float:
	return 14.0 + 2.0 * sin(elapsed_ms * 0.002)


## Mote `i`: where it is and how bright, or alpha 0 while it is between
## risings. The web's `(seed * 13) % 1` scatters them over the floor.
static func mote(at: Vector2, radius: float, i: int, progress: float, elapsed_ms: int) -> Array:
	var seed := i * 0.453
	var phase := fmod(progress * 1.1 + seed, 1.0)
	var angle := seed * TAU + elapsed_ms * 0.0006
	var dist := radius * (0.2 + 0.7 * fmod(seed * 13.0, 1.0))
	return [at + Vector2(cos(angle) * dist, sin(angle) * dist * 0.5 - phase * radius * 0.5), sin(phase * PI)]


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var ring := ring_radius(radius, progress)
	canvas.draw_circle(at, radius, Color(NIGHT, alpha * 0.30))
	canvas.draw_circle(at, ring * 0.9, Color("2e3a73", alpha * 0.18))
	Fx.ring(canvas, at, ring, 5.0, Color(SILVER, alpha * 0.9))
	Fx.ring(canvas, at, ring * 0.9, 2.0, Color(SOFT, alpha * 0.7))
	for i in 6:
		var angle := i * TAU / 6.0 + elapsed_ms * 0.0003
		var beam_alpha := alpha * (0.25 + 0.35 * (0.5 + 0.5 * sin(elapsed_ms * 0.002 + i)))
		var offset := Vector2(cos(angle), -sin(angle)) * radius * 0.9
		Fx.line(canvas, at + offset - Vector2(0.0, radius * 0.5), at + offset * 0.4, 3.0, Color(SOFT, beam_alpha))
	for i in MOTES:
		var m := mote(at, radius, i, progress, elapsed_ms)
		var mote_alpha: float = m[1] * alpha
		if mote_alpha <= 0.05:
			continue
		Fx.dot(canvas, m[0], 4.0, Color(SOFT, mote_alpha * 0.8))
		Fx.dot(canvas, m[0], 1.8, Color(Color.WHITE, mote_alpha))
	var moon := moon_px(elapsed_ms)
	Fx.dot(canvas, at, moon, Color("eaf1ff", alpha * 0.95))
	Fx.dot(canvas, at + Vector2(moon * 0.5, -moon * 0.18) * Fx.S, moon * 0.92, Color(NIGHT, alpha))
