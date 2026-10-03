class_name FxStarShuriken
extends RefCounted

## STAR_SHURIKEN (33): a throwing star snapping to speed over the caster --
## a steel diamond through four points that grows from 0.6 of the radius to
## all of it and spins hard, a motion-blur ghost chasing its turn, white
## glints on the points, speed arcs trailing the spin and a couple of blood
## flecks spun off (the Ninja's Shuriken, which bleeds).

const STEEL := Color("c0c8d0")
const DARK := Color("404850")
const BLOOD := Color("c01828")


static func arm_radius(radius: float, progress: float) -> float:
	return radius * (0.6 + 0.4 * progress)


## The star's turn: 18 radians a second.
static func spin(elapsed_ms: int) -> float:
	return elapsed_ms * 0.018


static func points_at(at: Vector2, radius: float, turn: float) -> Array:
	var out: Array = []
	for i in 4:
		out.append(Fx.polar(at, turn + i * TAU / 4.0, radius))
	return out


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var arm := arm_radius(fx["radius"], progress)
	var turn := spin(elapsed_ms)
	# A ghost a little behind the turn blurs the spin so it reads as fast.
	Fx.polygon(canvas, points_at(at, arm, turn - 0.3), Color(STEEL, alpha * 0.25))
	var corners := points_at(at, arm, turn)
	Fx.polygon(canvas, corners, Color(STEEL, alpha * 0.85))
	FxBladeShapes.outline(canvas, corners, 4.0, Color(DARK, alpha))
	Fx.line(canvas, corners[0], corners[2], 3.0, Color(Color.WHITE, alpha))
	Fx.line(canvas, corners[1], corners[3], 3.0, Color(Color.WHITE, alpha))
	for p in corners:
		Fx.dot(canvas, p, 2.0, Color(Color.WHITE, alpha * 0.9))
	for k in 3:
		var a0 := turn - 0.5 - k * 0.25
		canvas.draw_arc(at, arm * 1.1, a0, a0 + 0.4, 4, Color(STEEL, alpha * 0.4), 1.5 * Fx.S)
	for k in 2:
		var fleck := Fx.polar(at, turn * 0.5 + k * PI, arm * (1.0 + 0.6 * progress))
		Fx.dot(canvas, fleck, 2.0 * (1.0 - progress), Color(BLOOD, alpha * 0.8))
	Fx.dot(canvas, at, 5.0, Color(DARK, alpha))
