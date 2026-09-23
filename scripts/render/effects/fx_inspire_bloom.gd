class_name FxInspireBloom
extends RefCounted

## INSPIRE_BLOOM (31): a golden flower opening. Six petals -- each a deep
## amber disc, a gold one and a white heart -- spreading and turning an
## eighth of a turn as the bloom grows, around a white-and-gold centre.


## How far the flower reaches: from 0.55 of the radius to 1.1.
static func reach(radius: float, progress: float) -> float:
	return radius * (0.55 + 0.55 * progress)


## Petal `i` of six: half the reach out, the ring turning PI/4 over the life.
static func petal(at: Vector2, extent: float, i: int, progress: float) -> Vector2:
	return Fx.polar(at, i * TAU / 6.0 + progress * PI * 0.25, extent * 0.5)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var extent := reach(fx["radius"], progress)
	if extent > 0.0:
		for i in 6:
			var centre := petal(at, extent, i, progress)
			canvas.draw_circle(centre, extent * 0.32, Color("a07020", alpha * 0.75))
			canvas.draw_circle(centre, extent * 0.26, Color("ffd060", alpha * 0.95))
			canvas.draw_circle(centre, extent * 0.12, Color(Color.WHITE, alpha * 0.6))
	# The web paints the white centre first and the larger gold disc over
	# it, so the white only shows through the gold; the order is kept.
	Fx.dot(canvas, at, 6.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, at, 11.0, Color("ffd060", alpha))
