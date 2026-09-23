class_name FxKnightShockwave
extends RefCounted

## KNIGHT_SHOCKWAVE (11): the knight's forward shield bash, aimed from the
## cast at `target`. A wind-up (a dust burst behind the feet, six chevrons
## gathering behind), a thrust (the chevrons sweep forward past the slam
## point along a dark ground streak), then the slam `reach` ahead: a
## burst with spokes and forward cracks, a flash peaking at the thrust's
## end, two chasing shock rings, debris and ground fissures -- those are
## FxKnightShockwaveImpact and FxKnightShockwaveAftermath. This file owns
## the axis and the timeline; the tier colour runs through all of it.

const WINDUP_END := 0.12
const THRUST_END := 0.50
const SLAM_END := 0.70
const CHEVRONS := 6


## How far ahead the slam lands: the distance to the aim, held between
## the web's 60 and 280 screen px (30 and 140 world).
static func reach(from: Vector2, to: Vector2) -> float:
	return clampf(from.distance_to(to), 60.0 * Fx.S, 280.0 * Fx.S)


## The thrust's heading; east when the aim is on the knight.
static func heading(from: Vector2, to: Vector2) -> Vector2:
	return (to - from).normalized() if from.distance_to(to) > 0.5 * Fx.S else Vector2.RIGHT


## Where chevron `i` sits along the axis, in reaches: gathered behind the
## knight in the wind-up, eased forward through the thrust, held in front.
static func chevron_at(progress: float, i: int) -> float:
	var behind := -0.55 - 0.10 - i * 0.08
	var front := 1.20 - i * 0.05
	if progress < WINDUP_END:
		return -0.55 - 0.10 * progress / WINDUP_END - i * 0.08
	if progress >= THRUST_END:
		return front
	var offset := i * 0.045
	var t := clampf((progress - WINDUP_END - offset) / (THRUST_END - WINDUP_END - offset), 0.0, 1.0)
	return behind + (front - behind) * t * t * (3.0 - 2.0 * t)


## The slam's strength before the fade: rising from the end of the wind-up
## to a peak at the thrust's end, gone by SLAM_END.
static func slam_strength(progress: float) -> float:
	if progress < WINDUP_END:
		return 0.0
	var t := clampf((progress - WINDUP_END) / (SLAM_END - WINDUP_END), 0.0, 1.0)
	var peak := (THRUST_END - WINDUP_END) / (SLAM_END - WINDUP_END)
	return t / peak if t <= peak else maxf(0.0, 1.0 - (t - peak) / (1.0 - peak))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var aim: Vector2 = fx["target"]
	var dir := heading(at, aim)
	var far := reach(at, aim)
	var alpha := 1.0 - progress
	_streak(canvas, at, dir, far, progress, alpha, colour)
	_chevrons(canvas, at, dir, far, progress, alpha, colour)
	if progress < WINDUP_END:
		var wt := progress / WINDUP_END
		var brace := at - dir * 18.0 * Fx.S
		Fx.dot(canvas, brace, 14.0 + wt * 8.0, Color("553322", alpha * (1.0 - wt) * 0.7 * 0.5))
		Fx.dot(canvas, brace, 10.0 + wt * 6.0, Color(colour, alpha * (1.0 - wt) * 0.7 * 0.4))
	var slam := at + dir * far
	FxKnightShockwaveImpact.draw(canvas, slam, dir, progress, alpha, colour)
	FxKnightShockwaveAftermath.draw(canvas, slam, dir, progress, alpha, colour)


## A dark band on the ground from behind the knight out along the thrust.
static func _streak(canvas: CanvasItem, at: Vector2, dir: Vector2, far: float, progress: float,
		alpha: float, colour: Color) -> void:
	var from := at - dir * 40.0 * Fx.S
	var to := at + dir * far * minf(1.2, progress * 1.4)
	Fx.line(canvas, from, to, 28.0, Color(colour, alpha * 0.10))
	Fx.line(canvas, from, to, 16.0, Color(colour, alpha * 0.22))
	Fx.line(canvas, from, to, 6.0, Color(Color.BLACK, alpha * 0.45))


## Six forward-pointing Vs along the axis, the trailing ones larger, each
## a tier stroke over a black underlay under a white core.
static func _chevrons(canvas: CanvasItem, at: Vector2, dir: Vector2, far: float, progress: float,
		alpha: float, colour: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	for i in CHEVRONS:
		var along := chevron_at(progress, i)
		var centre := at + dir * far * along
		var ahead := maxf(0.0, clampf(along, -0.7, 1.3) - 1.0)
		var fade := alpha * maxf(0.2, 1.0 - ahead * 1.8) * (1.0 - i * 0.06)
		var arm := (22.0 - i * 2.2) * Fx.S
		var tip := centre + dir * arm * 0.55
		var back_a := centre + side * arm - dir * arm * 0.4
		var back_b := centre - side * arm - dir * arm * 0.4
		for stroke in [[7.0, Color(colour, fade * 0.85)], [3.0, Color(Color.BLACK, fade * 0.6)],
				[2.0, Color(Color.WHITE, fade * 0.95)]]:
			Fx.line(canvas, back_a, tip, stroke[0], stroke[1])
			Fx.line(canvas, tip, back_b, stroke[0], stroke[1])
