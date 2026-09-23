class_name FxBlinkGlyph
extends RefCounted

## BLINK_GLYPH (20): a violet rune ring where a blink leaves or lands. It
## opens over the first half of its life, a dark portal inside a bright
## violet rim with a darker one just within, six runes turning round the
## rim, and a vertical rift of light through the middle.

const VIOLET := Color("9040ff")
const BRIGHT := Color("c880ff")
const VOID := Color("1a0a30")
const RUNES := 6


## The ring opens from 40% to 110% of the radius by halfway, then holds.
static func ring_radius(radius: float, progress: float) -> float:
	return radius * (0.4 + minf(progress * 2.0, 1.0) * 0.7)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var ring := ring_radius(fx["radius"], progress)
	canvas.draw_circle(at, ring, Color(VOID, alpha * 0.55))
	Fx.ring(canvas, at, ring, 4.0, Color(BRIGHT, alpha))
	Fx.ring(canvas, at, ring - 4.0 * Fx.S, 2.0, Color(VIOLET, alpha * 0.85))
	for i in RUNES:
		var rune := Fx.polar(at, float(i) / RUNES * TAU + elapsed_ms * 0.004, ring)
		Fx.dot(canvas, rune, 4.0, Color(BRIGHT, alpha))
		Fx.dot(canvas, rune, 1.6, Color(Color.WHITE, alpha * 0.8))
	var rift := Vector2(0.0, ring)
	Fx.line(canvas, at - rift * 0.9, at + rift * 0.9, 3.0, Color(BRIGHT, alpha * 0.95))
	Fx.line(canvas, at - rift * 0.85, at + rift * 0.85, 2.0, Color(Color.WHITE, alpha * 0.8))
