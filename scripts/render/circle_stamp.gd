class_name CircleStamp
extends RefCounted

## Filled circles and full rings without draw_circle/draw_arc.
##
## On the GL compatibility renderer every draw_circle, draw_arc and polygon
## builds a vertex buffer of its own -- 20-30us a call, a hundred times a
## texture rect -- and the effects, shadows and minimap make dozens a frame.
## A disc is instead one tinted quad of a shared disc texture, and a ring one
## draw_multiline of a unit circle scaled to size, which draws as plain rects.

const DISC_SIZE := 128
## Fraction of the radius over which the disc's edge fades, so it reads as a
## clean circle at any scale instead of a stepped one.
const DISC_EDGE := 0.04
const RING_SEGMENTS := 48

static var _disc: CanvasTexture
static var _rings := {}   # segments -> PackedVector2Array of unit-circle segment pairs


static func disc(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	if radius <= 0.0:
		return
	canvas.draw_texture_rect(disc_texture(), Rect2(centre.x - radius, centre.y - radius,
		radius * 2.0, radius * 2.0), false, colour)


## A full ring `width` wide centred on `radius`, as draw_arc strokes it. Leaves
## the canvas transform at identity.
static func ring(canvas: CanvasItem, centre: Vector2, radius: float, width: float, colour: Color,
		segments := RING_SEGMENTS) -> void:
	if radius <= 0.0 or width <= 0.0:
		return
	canvas.draw_set_transform(centre, 0.0, Vector2(radius, radius))
	canvas.draw_multiline(unit_ring(segments), colour, width / radius)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func disc_texture() -> CanvasTexture:
	if _disc != null:
		return _disc
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0 - DISC_EDGE, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill = GradientTexture2D.FILL_RADIAL
	fill.fill_from = Vector2(0.5, 0.5)
	fill.fill_to = Vector2(1.0, 0.5)
	fill.width = DISC_SIZE
	fill.height = DISC_SIZE
	_disc = CanvasTexture.new()
	_disc.diffuse_texture = fill
	# Smooth however the layer it lands on samples its own sprites.
	_disc.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return _disc


static func unit_ring(segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = _rings.get(segments, PackedVector2Array())
	if not points.is_empty():
		return points
	for k in segments:
		points.append(Vector2.from_angle(TAU * k / segments))
		points.append(Vector2.from_angle(TAU * (k + 1) / segments))
	_rings[segments] = points
	return points
