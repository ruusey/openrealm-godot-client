class_name FxDisarmFlourish
extends RefCounted

## DISARM_FLOURISH (55): the Duelist's ultimate, a dazzling disarm. Three
## gold blades slash across the strike in quick succession (0-35%), then a
## heavy gold-and-white impact with a snapping ring and radial spokes
## (30-55%); from there the enemy's weapon is knocked spinning away on a
## ballistic arc while three stun-stars circle the hit and fade (STUNNED).
## Aimed along the caster-to-strike axis Fx.facing gives it.

const GOLD := Color("ffd24c")
const DEEP := Color("804808")
const STEEL := Color("c8d0dc")
const SLASHES := 3


## A slash's own progress, 0..1, or -1 before it starts or once it is gone;
## the three are staggered a tenth of the life apart.
static func slash_t(progress: float, i: int) -> float:
	var t := (progress - i * 0.1) / 0.25
	return t if t >= 0.0 and t <= 1.0 else -1.0


## The impact's strength: rising from 30%, peaking near 45%, gone by 55%.
static func impact(progress: float) -> float:
	if progress < 0.3 or progress > 0.55:
		return 0.0
	var t := (progress - 0.3) / 0.25
	return t / 0.6 if t <= 0.6 else maxf(0.0, 1.0 - (t - 0.6) / 0.4)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var dir := Fx.facing(fx)
	var alpha := 1.0 - progress
	var reach: float = maxf(fx["radius"], 28.0)
	var base := dir.angle()
	for i in SLASHES:
		var t := slash_t(progress, i)
		if t < 0.0:
			continue
		var centre := base + (0.4 if i % 2 == 0 else -0.4)
		var fade := (1.0 - t)
		FxBladeShapes.arc(canvas, at, centre, 1.3, reach * (0.8 + 0.3 * t), 12, 7.0, Color(DEEP, fade * 0.7))
		FxBladeShapes.arc(canvas, at, centre, 1.3, reach * (0.8 + 0.3 * t), 12, 4.0, Color(GOLD, fade))
		FxBladeShapes.arc(canvas, at, centre, 1.3, reach * (0.8 + 0.3 * t), 12, 2.0, Color(Color.WHITE, fade * 0.9))
	var hit := impact(progress)
	if hit > 0.0:
		Fx.dot(canvas, at, 8.0 + 14.0 * hit, Color(Color.WHITE, hit))
		Fx.ring(canvas, at, reach * (0.3 + 0.8 * (1.0 - hit)), 5.0, Color(GOLD, hit))
		for i in 8:
			var spoke := i * TAU / 8.0
			Fx.line(canvas, Fx.polar(at, spoke, reach * 0.2), Fx.polar(at, spoke, reach * (0.5 + 0.4 * hit)),
				2.0, Color(GOLD, hit * 0.85))
	_disarm(canvas, at, dir, reach, progress, elapsed_ms)


## The disarm's aftermath: the weapon flung spinning along a forward arc,
## and three stun-stars circling the hit. Both over the back 55%.
static func _disarm(canvas: CanvasItem, at: Vector2, dir: Vector2, reach: float, progress: float,
		elapsed_ms: int) -> void:
	if progress < 0.45:
		return
	var dt := (progress - 0.45) / 0.55
	var fade := 1.0 - dt
	var side := Vector2(-dir.y, dir.x)
	var flung := at + dir * reach * 1.6 * dt + side * reach * 0.4 * dt
	flung.y -= sin(dt * PI) * reach * 0.9
	var spin := elapsed_ms * 0.02
	var blade := FxBladeShapes.lens(flung, spin, 9.0 * Fx.S, 2.5 * Fx.S)
	Fx.polygon(canvas, blade, Color(STEEL, fade))
	FxBladeShapes.outline(canvas, blade, 1.5, Color(Color.WHITE, fade * 0.8))
	Fx.line(canvas, flung, flung + Vector2(cos(spin), sin(spin)) * 5.0 * Fx.S, 2.0, Color("6a4a20", fade))
	for i in 3:
		var orbit := i * TAU / 3.0 + elapsed_ms * 0.004
		var star_at := Fx.polar(at, orbit, reach * 0.45) - Vector2(0.0, reach * 0.25 + 3.0 * sin(elapsed_ms * 0.006 + i))
		Fx.polygon(canvas, FxBladeShapes.star(star_at, elapsed_ms * 0.003, 7.0 * Fx.S), Color(GOLD, fade * 0.9))
