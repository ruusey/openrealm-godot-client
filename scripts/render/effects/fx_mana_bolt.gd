class_name FxManaBolt
extends RefCounted

## MANA_BOLT (26): an arcane starburst. A faint violet disc the size of the
## radius, six turning arms out to its edge -- pale violet under a white
## core a little shorter -- and a hot centre.

const ARC := Color("9040ff")
const HOT := Color("c080ff")
const ARMS := 6


static func arm_angle(i: int, elapsed_ms: int) -> float:
	return float(i) / ARMS * TAU + elapsed_ms * 0.003


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	canvas.draw_circle(at, radius, Color(ARC, alpha * 0.25))
	for i in ARMS:
		Fx.line(canvas, at, Fx.polar(at, arm_angle(i, elapsed_ms), radius), 4.0, Color(HOT, alpha))
	for i in ARMS:
		Fx.line(canvas, at, Fx.polar(at, arm_angle(i, elapsed_ms), radius * 0.95), 2.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 8.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 14.0, Color(HOT, alpha * 0.7))
