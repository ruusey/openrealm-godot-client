class_name FxRampageAura
extends RefCounted

## RAMPAGE_AURA (41): a flaming red aura round the player. A dark red disc,
## a flame-red one inside it, and ten flame tongues round the rim turning
## slowly and flickering in length, each a hot yellow core in a red
## tongue. It ignores the tier colour.

const TONGUES := 10
const FLAME := Color("ff4020")


## How far tongue `i`'s tip reaches from the centre.
static func tip_reach(radius: float, i: int, elapsed_ms: int) -> float:
	return radius * 1.15 * (0.85 + 0.15 * sin(elapsed_ms * 0.015 + i))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("600010", alpha * 0.35))
	canvas.draw_circle(at, radius * 0.85, Color(FLAME, alpha * 0.45))
	for i in TONGUES:
		var angle := i * TAU / TONGUES + elapsed_ms * 0.0035
		var base := Fx.polar(at, angle, radius * 0.85)
		var tip := Fx.polar(at, angle, tip_reach(radius, i, elapsed_ms))
		var side := Vector2(-sin(angle), cos(angle)) * 6.0 * Fx.S
		Fx.polygon(canvas, [base + side, tip, base - side], Color(FLAME, alpha * 0.95))
		Fx.polygon(canvas, [base + side * 0.6, tip, base - side * 0.6], Color("ffd040", alpha))
