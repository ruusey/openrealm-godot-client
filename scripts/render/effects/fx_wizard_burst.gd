class_name FxWizardBurst
extends RefCounted

## WIZARD_BURST (10): the arcane release at a wizard's cast. A magic-circle
## floor, two rune-ring waves sweeping out, a rotating hexagram, six runes
## orbiting the ring, fading spokes, motes gathering inward at the start,
## a flash, and a pulsing core -- in the tier's colour.


static func burst_radius(radius: float, progress: float) -> float:
	return radius * (0.5 + progress * 0.6)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var radius := burst_radius(fx["radius"], progress)
	canvas.draw_circle(at, radius, Color(colour, alpha * 0.18))
	for w in 2:
		var t := Fx.wave(progress, w * 0.20)
		if t < 0.0:
			continue
		var wave_alpha := alpha * (1.0 - t) * 0.75
		Fx.ring(canvas, at, radius * (1.0 + t * 0.9), 2.5, Color(colour, wave_alpha))
		Fx.ring(canvas, at, radius * (1.0 + t * 0.9) * 0.97, 1.5, Color(Color.WHITE, wave_alpha * 0.6))
	Fx.ring(canvas, at, radius, 3.0, Color(colour, alpha * 0.85))
	Fx.ring(canvas, at, radius * 0.78, 2.0, Color(Color.WHITE, alpha * 0.85))
	# The hexagram: two triangles inscribed in the inner ring, turning.
	var glyph := radius * 0.55
	var rot := elapsed_ms * 0.003
	var glyph_colour := Color(colour, alpha * 0.75)
	for start in [-PI * 0.5, PI * 0.5]:
		var corners: Array = []
		for k in 3:
			corners.append(Fx.polar(at, rot + start + k * TAU / 3.0, glyph))
		for k in 3:
			Fx.line(canvas, corners[k], corners[(k + 1) % 3], 2.0, glyph_colour)
	for i in 6:
		var rune := Fx.polar(at, i * TAU / 6.0 + elapsed_ms * 0.006, radius)
		Fx.dot(canvas, rune, 8.0, Color(colour, alpha * 0.55))
		Fx.polygon(canvas, [rune + Vector2(0, -5) * Fx.S, rune + Vector2(4, 0) * Fx.S,
			rune + Vector2(0, 5) * Fx.S, rune + Vector2(-4, 0) * Fx.S], Color(Color.WHITE, alpha * 0.95))
	var spoke := Color(Color.WHITE, alpha * (1.0 - progress * 0.7))
	for i in 8:
		var angle := i * TAU / 8.0
		Fx.line(canvas, Fx.polar(at, angle, radius * 0.2), Fx.polar(at, angle, radius * 0.95), 2.0, spoke)
	if progress < 0.30:
		var eased := 1.0 - pow(1.0 - progress / 0.30, 2.0)
		for i in 8:
			var mote := Fx.polar(at, i * TAU / 8.0, radius * 1.4 * (1.0 - eased))
			Fx.dot(canvas, mote, 2.0 + (1.0 - eased) * 2.0, Color(Color.WHITE, alpha * 0.9))
			Fx.dot(canvas, mote, 5.0 + (1.0 - eased) * 3.0, Color(colour, alpha * 0.55))
	if progress < 0.25:
		var flash := 1.0 - progress / 0.25
		canvas.draw_circle(at, radius * 0.5, Color(Color.WHITE, flash * 0.85))
		canvas.draw_circle(at, radius * 0.75, Color(colour, flash * 0.65))
	canvas.draw_circle(at, radius * 0.18, Color(colour, alpha * 0.75))
