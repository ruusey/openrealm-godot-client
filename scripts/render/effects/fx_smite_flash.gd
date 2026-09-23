class_name FxSmiteFlash
extends RefCounted

## SMITE_FLASH (29): a small holy strike. A gold cross of light with a
## white core -- the upright longer than the bar, which sits just above
## centre -- a white-and-gold burst at its heart, and four dark cracks
## running out across the ground on the diagonals. It only fades.


## The cross from its centre: x the half-bar, y the half-upright, z how
## far above centre the bar sits.
static func arms(radius: float) -> Vector3:
	return Vector3(radius * 0.45, radius * 0.6, radius * 0.1)


## Crack `i` of four, on the diagonals, from 0.6 to 1.1 of the radius.
static func crack(at: Vector2, radius: float, i: int) -> PackedVector2Array:
	var angle := i * TAU / 4.0 + PI / 4.0
	return PackedVector2Array([Fx.polar(at, angle, radius * 0.6), Fx.polar(at, angle, radius * 1.1)])


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var gold := Color("ffd060")
	var span := arms(radius)
	for layer in [[8.0, Color(gold, alpha)], [3.0, Color(Color.WHITE, alpha)]]:
		Fx.line(canvas, at - Vector2(0.0, span.y), at + Vector2(0.0, span.y), layer[0], layer[1])
		Fx.line(canvas, at + Vector2(-span.x, -span.z), at + Vector2(span.x, -span.z), layer[0], layer[1])
	if radius > 0.0:
		canvas.draw_circle(at, radius * 0.35, Color(Color.WHITE, alpha * 0.75))
		canvas.draw_circle(at, radius * 0.55, Color(gold, alpha * 0.55))
	for i in 4:
		var ends := crack(at, radius, i)
		Fx.line(canvas, ends[0], ends[1], 3.0, Color("806020", alpha * 0.85))
