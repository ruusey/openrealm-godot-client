class_name FxSanctuaryDome
extends RefCounted

## SANCTUARY_DOME (51): the priest's or paladin's golden dome. A faint gold
## fill with a gold rim between two pale rings, eight light pillars rising
## from just inside the rim as the ring slowly turns, a radiant cross of
## four beams over a thinner diagonal one, and a pulsing white heart.


## Pillar `i`'s height, breathing between 0.7 and 1.0 of 0.42 radius.
static func pillar_height(radius: float, i: int, elapsed_ms: int) -> float:
	return radius * 0.42 * (0.7 + 0.3 * sin(elapsed_ms * 0.005 + i))


## Where pillar `i` of eight stands: 0.92 of the radius out, turning.
static func pillar_base(at: Vector2, radius: float, i: int, elapsed_ms: int) -> Vector2:
	return Fx.polar(at, i * TAU / 8.0 + elapsed_ms * 0.0008, radius * 0.92)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var gold := Color("ffd060")
	var gold_hi := Color("fff0a0")
	if radius > 0.0:
		canvas.draw_circle(at, radius, Color(gold, alpha * 0.18))
	Fx.ring(canvas, at, radius, 4.0, Color(gold, alpha * 0.95))
	Fx.ring(canvas, at, radius * 0.97, 2.0, Color(gold_hi, alpha * 0.8))
	Fx.ring(canvas, at, radius * 1.03, 2.0, Color(gold_hi, alpha * 0.8))
	for i in 8:
		var base := pillar_base(at, radius, i, elapsed_ms)
		var height := pillar_height(radius, i, elapsed_ms)
		Fx.dot(canvas, base - Vector2(0.0, height * 0.5), 5.0, Color(gold_hi, alpha * 0.55))
		Fx.line(canvas, base, base - Vector2(0.0, height), 3.0, Color(gold, alpha * 0.75))
	var cross := radius * 0.35
	var beam := Color(gold_hi, alpha)
	Fx.line(canvas, at - Vector2(cross, 0.0), at + Vector2(cross, 0.0), 5.0, beam)
	Fx.line(canvas, at - Vector2(0.0, cross), at + Vector2(0.0, cross), 5.0, beam)
	var diagonal := cross * 0.7
	var thin := Color(gold, alpha * 0.85)
	Fx.line(canvas, at - Vector2(diagonal, diagonal), at + Vector2(diagonal, diagonal), 2.0, thin)
	Fx.line(canvas, at + Vector2(diagonal, -diagonal), at + Vector2(-diagonal, diagonal), 2.0, thin)
	Fx.dot(canvas, at, 6.0, Color(Color.WHITE, alpha * (0.55 + 0.35 * sin(elapsed_ms * 0.008))))
	Fx.dot(canvas, at, 3.0, Color(gold_hi, alpha))
