class_name FxRapierStab
extends RefCounted

## RAPIER_STAB (53): the Duelist's Sidearm, a fast forward lunge read as a
## thrust. A thin steel blade drives from the caster out through the strike
## point across the first 40%, then withdraws as a silver pierce bursts
## where it landed: a white core, a forward fan of sparks, a thin puncture
## ring and a couple of armour shards knocked loose (ARMOR_BROKEN). Aimed
## along the caster-to-strike axis Fx.facing gives it.

const SILVER := Color("e6ecf4")
const STEEL := Color("7f8ea0")
const SHARD := Color("aab4c2")


## The blade's tail and tip offsets along the axis: it drives out through
## the first 40%, then the tip eases back toward the caster.
static func blade_span(reach: float, progress: float) -> Vector2:
	var drive := minf(1.0, progress / 0.4)
	var withdraw := maxf(0.0, (progress - 0.4) / 0.6)
	var tip := reach * (0.35 + 0.95 * drive) - reach * 0.75 * withdraw
	var tail := tip - reach * (0.8 - 0.35 * withdraw)
	return Vector2(tail, tip)


## The pierce's strength: nothing until the blade arrives, a peak at 40%,
## gone by the end.
static func pierce(progress: float) -> float:
	if progress < 0.3:
		return 0.0
	return maxf(0.0, 1.0 - (progress - 0.3) / 0.7)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var dir := Fx.facing(fx)
	var alpha := 1.0 - progress
	var reach: float = maxf(fx["radius"], 24.0)
	var span := blade_span(reach, progress)
	var tail := at + dir * span.x
	var tip := at + dir * span.y
	Fx.line(canvas, tail, tip, 5.0, Color(STEEL, alpha * 0.9))
	Fx.line(canvas, tail, tip, 2.0, Color(Color.WHITE, alpha))
	Fx.dot(canvas, tip, 2.5, Color(Color.WHITE, alpha))
	var hit := pierce(progress)
	if hit > 0.0:
		Fx.dot(canvas, at, 5.0 + 9.0 * hit, Color(Color.WHITE, hit))
		Fx.dot(canvas, at, 10.0 + 6.0 * hit, Color(SILVER, hit * 0.6))
		Fx.ring(canvas, at, reach * (0.25 + 0.85 * (1.0 - hit)), 2.0, Color(SILVER, hit * 0.7))
		for i in 5:
			var spark := dir.rotated((i - 2) * 0.3)
			var length := reach * (0.45 + 0.55 * (1.0 - hit))
			Fx.line(canvas, at + spark * reach * 0.1, at + spark * length, 1.5, Color(Color.WHITE, hit * 0.9))
	_shards(canvas, at, dir, reach, progress, alpha)


## Three armour chips knocked off the strike and thrown forward, swelling
## apart and settling as it fades. A fixed scatter, the same every frame.
static func _shards(canvas: CanvasItem, at: Vector2, dir: Vector2, reach: float, progress: float,
		alpha: float) -> void:
	var fall := progress * reach * 0.6
	for i in 3:
		var spread := (i - 1) * 0.5
		var pos := at + dir.rotated(spread) * (reach * 0.2 + fall) + Vector2(0.0, fall * 0.4)
		Fx.dot(canvas, pos, 2.2, Color(SHARD, alpha * 0.8))
