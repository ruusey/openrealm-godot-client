class_name FxCompanionSummon
extends RefCounted

## COMPANION_SUMMON (66): the conjuring burst where your one companion is called
## to the field, centred on you (ownerId). A white-hot core flash, two arcane
## rings sweeping outward, a slowly-rotating six-point glyph star that flares then
## fades, and motes drawn inward to the centre as the companion is summoned. Pure
## function of progress/elapsed so a scripted render draws the same frame twice.

const ARCANE := Color("7b6cff")
const ARCANE_BRIGHT := Color("b9b0ff")
const WHITE_HOT := Color("f2f0ff")
const MOTES := 16
const GLYPH_POINTS := 6


static func noise(i: int, salt: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var fade := 1.0 - progress
	# Opening white-hot core flash.
	if progress < 0.22:
		var k := progress / 0.22
		Fx.dot(canvas, at, radius * 0.5 * (1.0 - k * 0.4), Color(WHITE_HOT, 0.6 * (1.0 - k)))
	# Two arcane rings sweeping outward, staggered.
	for w in 2:
		var t := Fx.wave(progress, w * 0.18)
		if t >= 0.0:
			Fx.ring(canvas, at, radius * (0.3 + t), 5.0 - 2.0 * t, Color(ARCANE_BRIGHT, 0.9 * (1.0 - t)))
	# Ground glyph: a six-point star, flaring up then dimming, slowly rotating.
	var spin := progress * 1.2
	var glyph_r := radius * (0.55 + 0.1 * sin(progress * PI))
	var glyph_a := sin(progress * PI)
	for i in GLYPH_POINTS:
		var a0 := spin + i * TAU / GLYPH_POINTS
		var a1 := spin + (i + 2) * TAU / GLYPH_POINTS
		Fx.line(canvas, Fx.polar(at, a0, glyph_r), Fx.polar(at, a1, glyph_r), 2.5, Color(ARCANE, 0.85 * glyph_a))
	Fx.ring(canvas, at, glyph_r, 2.0, Color(ARCANE, 0.5 * glyph_a))
	# Motes spiralling inward to the centre as the companion is conjured.
	for i in MOTES:
		var ang := noise(i, 1) * TAU + progress * 2.0
		var dist := radius * 1.1 * (1.0 - progress) * (0.6 + noise(i, 2) * 0.6)
		Fx.dot(canvas, Fx.polar(at, ang, dist), 2.6 * fade, Color(ARCANE_BRIGHT, 0.9 * fade))
