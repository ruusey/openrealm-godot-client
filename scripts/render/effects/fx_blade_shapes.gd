class_name FxBladeShapes
extends RefCounted

## The shapes the rogue's effects share: a slash drawn as a stroked arc
## (beast claws, death blossom, reckless slash), a lens-shaped blade that
## spins about its middle (the ninja dash's vortex), and a four-point
## throwing star (blade orbit, blade blender). The web client draws the
## last from the tier's shuriken sprite; a drawer has no sprites, so it is
## a vector star here in the tier's colour.


## An arc of `sweep` radians centred on `centre`, stroked as the web client
## strokes it: `segments` straight pieces, not a smooth curve.
static func arc(canvas: CanvasItem, at: Vector2, centre: float, sweep: float, radius: float,
		segments: int, width_px: float, colour: Color) -> void:
	if colour.a > 0.001 and radius > 0.0:
		canvas.draw_arc(at, radius, centre - sweep * 0.5, centre + sweep * 0.5, segments + 1,
			colour, width_px * Fx.S)


## A diamond `length` from the middle to each point along `angle` and
## `width` across it: tip, side, tail, side.
static func lens(at: Vector2, angle: float, length: float, width: float) -> Array:
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	return [at + along * length, at + across * width, at - along * length, at - across * width]


## A closed outline through `points`.
static func outline(canvas: CanvasItem, points: Array, width_px: float, colour: Color) -> void:
	if colour.a > 0.001 and points.size() >= 2:
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		canvas.draw_polyline(closed, colour, width_px * Fx.S)


## A four-point star `size` across, turned by `angle`: the points at half
## the size, the waist between them at a fifth of it.
static func star(at: Vector2, angle: float, size: float) -> Array:
	var points: Array = []
	for k in 8:
		var reach := size * (0.5 if k % 2 == 0 else 0.2)
		points.append(Fx.polar(at, angle + k * PI / 4.0, reach))
	return points


## A shuriken standing in for the tier's sprite: a dark rim, a body in the
## tier's colour, a bright edge down each blade and a hole in the hub.
static func shuriken(canvas: CanvasItem, at: Vector2, angle: float, size: float, colour: Color,
		alpha: float) -> void:
	var points := star(at, angle, size)
	Fx.polygon(canvas, star(at, angle, size * 1.18), Color("202028", alpha * 0.85))
	Fx.polygon(canvas, points, Color(colour, alpha))
	for k in 4:
		Fx.line(canvas, at, points[k * 2], 1.5, Color(Color.WHITE, alpha * 0.8))
	canvas.draw_circle(at, size * 0.09, Color("202028", alpha))
