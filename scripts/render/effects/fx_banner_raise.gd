class_name FxBannerRaise
extends RefCounted

## BANNER_RAISE (40): a red war banner raised over the caster. A gold pole
## one and a half radii tall, a dark-edged red cloth unfurling down it to
## 1.6 radii by 62.5% in, a white saltire on the cloth, and a red stomp
## ring spreading from the feet. It ignores the tier colour.

const RED := Color("c01030")


## How far the cloth has unfurled, in world units.
static func cloth_height(radius: float, progress: float) -> float:
	return radius * 1.6 * minf(progress * 1.6, 1.0)


static func stomp_radius(radius: float, progress: float) -> float:
	return radius * (0.3 + progress * 0.8)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var cloth := cloth_height(radius, progress)
	var s := Fx.S
	canvas.draw_rect(Rect2(at.x - 2.0 * s, at.y - radius * 1.5, 4.0 * s, radius * 1.5), Color("ffd060", alpha))
	if cloth > 0.0:
		canvas.draw_rect(Rect2(at.x + 2.0 * s, at.y - radius * 1.4, 30.0 * s, cloth), Color("500010", alpha * 0.95))
	if cloth > 4.0 * s:
		canvas.draw_rect(Rect2(at.x + 4.0 * s, at.y - radius * 1.38, 26.0 * s, cloth - 4.0 * s), Color(RED, alpha))
	var top := at.y - radius * 1.3
	var emblem := Color(Color.WHITE, alpha)
	Fx.line(canvas, Vector2(at.x + 8.0 * s, top), Vector2(at.x + 26.0 * s, top + 14.0 * s), 2.0, emblem)
	Fx.line(canvas, Vector2(at.x + 26.0 * s, top), Vector2(at.x + 8.0 * s, top + 14.0 * s), 2.0, emblem)
	Fx.ring(canvas, at + Vector2(0.0, 8.0 * s), stomp_radius(radius, progress), 3.0, Color(RED, alpha * alpha))
