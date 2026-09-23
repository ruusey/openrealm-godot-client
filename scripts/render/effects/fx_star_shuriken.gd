class_name FxStarShuriken
extends RefCounted

## STAR_SHURIKEN (33): a big spinning throwing star over the caster -- a
## steel diamond through four points on a circle that grows from 0.6 of
## the radius to all of it, a dark rim, a white cross through the points
## and a dark hub.


static func arm_radius(radius: float, progress: float) -> float:
	return radius * (0.6 + 0.4 * progress)


## The star's turn: 18 radians a second.
static func spin(elapsed_ms: int) -> float:
	return elapsed_ms * 0.018


static func points(at: Vector2, radius: float, progress: float, elapsed_ms: int) -> Array:
	var arm := arm_radius(radius, progress)
	var out: Array = []
	for i in 4:
		out.append(Fx.polar(at, spin(elapsed_ms) + i * TAU / 4.0, arm))
	return out


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var corners := points(at, fx["radius"], progress, elapsed_ms)
	Fx.polygon(canvas, corners, Color("c0c8d0", alpha * 0.85))
	FxBladeShapes.outline(canvas, corners, 4.0, Color("404850", alpha))
	Fx.line(canvas, corners[0], corners[2], 3.0, Color(Color.WHITE, alpha))
	Fx.line(canvas, corners[1], corners[3], 3.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 5.0, Color("404850", alpha))
