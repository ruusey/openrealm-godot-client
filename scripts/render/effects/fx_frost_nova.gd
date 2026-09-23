class_name FxFrostNova
extends RefCounted

## FROST_NOVA (19): crystalline white-blue spikes radiating outward. A cold
## floor halo and rim at the radius, twelve diamond ice shards whose reach
## grows from just over half the radius to past it, each outlined in deep
## blue with a white core line, and a small white burst at the centre.

const SPIKES := 12
const ICE_BLUE := Color("80d0ff")
const ICE_DEEP := Color("3070d0")


static func spike_reach(radius: float, progress: float) -> float:
	return radius * (0.55 + 0.55 * progress)


## One shard pointing along `angle`: the tip, a shoulder a third of the way
## out, the point just off the centre, and the other shoulder.
static func shard(at: Vector2, angle: float, reach: float) -> Array:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x) * 9.0 * Fx.S
	var inner := at + dir * reach * 0.35
	return [at + dir * reach, inner + perp, at + dir * reach * 0.05, inner - perp]


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001 or radius <= 0.0:
		return
	canvas.draw_circle(at, radius, Color(ICE_BLUE, alpha * 0.18))
	Fx.ring(canvas, at, radius, 2.0, Color(ICE_BLUE, alpha * 0.85))
	var reach := spike_reach(radius, progress)
	for i in SPIKES:
		var angle := i * TAU / SPIKES
		var points := shard(at, angle, reach)
		Fx.polygon(canvas, points, Color(ICE_BLUE, alpha * 0.6))
		canvas.draw_polyline(PackedVector2Array(points + [points[0]]), Color(ICE_DEEP, alpha * 0.95), 2.0 * Fx.S)
		Fx.line(canvas, Fx.polar(at, angle, reach * 0.08), points[0], 2.0, Color(Color.WHITE, alpha))
	canvas.draw_circle(at, radius * 0.12, Color(Color.WHITE, alpha * 0.55))
