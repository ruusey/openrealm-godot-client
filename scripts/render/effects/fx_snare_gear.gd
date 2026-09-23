class_name FxSnareGear
extends RefCounted

## SNARE_GEAR (34): an iron gear ring tightening in by 30% over its life,
## a dark rim with an iron one just inside, and twelve teeth standing out
## from it -- iron with a white core -- turning slowly.

const TEETH := 12
const IRON := Color("808890")
const DARK := Color("303840")


static func gear_radius(radius: float, progress: float) -> float:
	return radius * (1.0 - progress * 0.30)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var gear := gear_radius(fx["radius"], progress)
	Fx.ring(canvas, at, gear, 5.0, Color(DARK, alpha * 0.95))
	Fx.ring(canvas, at, gear - 3.0 * Fx.S, 3.0, Color(IRON, alpha))
	for i in TEETH:
		var angle := float(i) / TEETH * TAU + elapsed_ms * 0.001
		var root := Fx.polar(at, angle, gear)
		var end := Fx.polar(at, angle, gear + 8.0 * Fx.S)
		Fx.line(canvas, root, end, 5.0, Color(IRON, alpha))
		Fx.line(canvas, root, end, 2.0, Color(Color.WHITE, alpha))
