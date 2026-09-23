class_name FxLightningStrike
extends RefCounted

## LIGHTNING_STRIKE (25): a bolt crashing down onto the target from above.
## A six-step zigzag from 2.2 radii overhead, dark under a yellow core,
## swaying at the top and wobbling less the nearer it gets to the ground;
## a straight white hairline down its middle; an impact ring widening out;
## and a yellow and white burst where it lands.

const ELEC := Color("fff060")
const DARK := Color("806010")
const SEGMENTS := 6


## How far above the target the bolt starts.
static func height(radius: float) -> float:
	return radius * 2.2


## The zigzag: the top sways by up to 8 web px on a slow sine, each joint
## below it wobbles by up to 14, less the lower it is, and the last lands
## dead on the target.
static func bolt(at: Vector2, radius: float, elapsed_ms: int) -> PackedVector2Array:
	var top := height(radius)
	var points := PackedVector2Array([at + Vector2(sin(elapsed_ms * 0.05) * 8.0 * Fx.S, -top)])
	for s in range(1, SEGMENTS + 1):
		var t := float(s) / SEGMENTS
		var wobble := sin(elapsed_ms * 0.04 + s * 1.7) * 14.0 * Fx.S * (1.0 - t)
		points.append(at + Vector2(wobble, -top * (1.0 - t)))
	return points


static func impact_radius(radius: float, progress: float) -> float:
	return radius * (0.4 + progress * 0.8)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var path := bolt(at, radius, elapsed_ms)
	canvas.draw_polyline(path, Color(DARK, alpha * 0.7), 6.0 * Fx.S)
	canvas.draw_polyline(path, Color(ELEC, alpha), 3.0 * Fx.S)
	Fx.line(canvas, at - Vector2(0.0, height(radius)), at, 1.0, Color(Color.WHITE, alpha))
	Fx.ring(canvas, at, impact_radius(radius, progress), 3.0, Color(ELEC, (1.0 - progress) * alpha))
	Fx.dot(canvas, at, 14.0, Color(ELEC, alpha * 0.6))
	Fx.dot(canvas, at, 6.0, Color(Color.WHITE, alpha))
