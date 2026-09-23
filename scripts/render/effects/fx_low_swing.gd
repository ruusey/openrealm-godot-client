class_name FxLowSwing
extends RefCounted

## LOW_SWING (54): the Heavy Debuffer's Ankle Strike. A half-sweep arc
## across the lower part of the radius, from lower right round to lower
## left, in three strokes -- a dark red shadow, the red blade and a white
## edge -- with a small steel glint at ankle height under the centre. Like
## the web, it is centred on the effect's position and has no direction.

const FROM := PI * 0.15
const TO := PI * 0.85
const SEGMENTS := 10
const RED := Color("c02830")
const SHADOW := Color("400810")
const STEEL := Color("a0a8b0")


static func reach(radius: float) -> float:
	return radius * 1.05


static func arc(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in SEGMENTS + 1:
		points.append(Fx.polar(at, FROM + (TO - FROM) * s / SEGMENTS, radius))
	return points


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var points := arc(at, reach(fx["radius"]))
	canvas.draw_polyline(points, Color(SHADOW, alpha * 0.8), 8.0 * Fx.S)
	canvas.draw_polyline(points, Color(RED, alpha), 5.0 * Fx.S)
	canvas.draw_polyline(points, Color(Color.WHITE, alpha * 0.9), 2.0 * Fx.S)
	Fx.dot(canvas, at + Vector2(0.0, 4.0 * Fx.S), 4.0, Color(STEEL, alpha * (1.0 - progress)))
