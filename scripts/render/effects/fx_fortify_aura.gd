class_name FxFortifyAura
extends RefCounted

## FORTIFY_AURA (57): the knight's Hold Your Ground, a bulwark aura. Fourteen
## stacked discs shade it from a vital green core to a steadfast blue rim,
## three rings pulse outward turning green to blue as they travel, a blue
## boundary marks the range, and a bright green glow sits at the heart.
## No sigil, no stars.

const BANDS := 14


## Blends two 0..255 channels as the web does: rounded to a whole step.
static func _mix(from: int, to: int, f: float) -> float:
	return roundf(from * (1.0 - f) + to * f) / 255.0


## The shade of the disc `f` of the way out (1 at the rim): 22ff66 at the
## core to 2673ff at the rim.
static func band_colour(f: float) -> Color:
	return Color(_mix(0x22, 0x26, f), _mix(0xff, 0x73, f), _mix(0x66, 0xff, f))


## A pulsing ring's shade `phase` of the way out: 38ff66 to 2673ff.
static func ring_colour(phase: float) -> Color:
	return Color(_mix(0x38, 0x26, phase), _mix(0xff, 0x73, phase), _mix(0x66, 0xff, phase))


## How far ring `i` of three has got, 0..1, looping about every 1.1 s.
static func ring_phase(i: int, elapsed_ms: int) -> float:
	return fmod(elapsed_ms * 0.0009 + i / 3.0, 1.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if radius > 0.0:
		for i in range(BANDS, 0, -1):
			var f := float(i) / BANDS
			canvas.draw_circle(at, radius * f, Color(band_colour(f), alpha * 0.16))
	for i in 3:
		var phase := ring_phase(i, elapsed_ms)
		var ring_alpha := (1.0 - phase) * alpha
		if ring_alpha <= 0.02:
			continue
		Fx.ring(canvas, at, radius * (0.18 + phase * 0.85), 3.0, Color(ring_colour(phase), ring_alpha * 0.9))
	Fx.ring(canvas, at, radius, 2.0, Color("4d99ff", alpha * 0.7))
	if radius > 0.0:
		canvas.draw_circle(at, radius * 0.16, Color("59ff8c", alpha * 0.5))
		canvas.draw_circle(at, radius * 0.07, Color("d9ffe6", alpha * 0.7))
