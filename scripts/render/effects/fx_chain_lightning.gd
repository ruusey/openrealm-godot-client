class_name FxChainLightning
extends RefCounted

## CHAIN_LIGHTNING (3): a forked bolt from the effect's origin to its
## target. A jagged spine drawn four times, haze to white core; five short
## forks off it; a burst at the target; a flickering glow at the origin.
## The web client re-rolls the jitter every frame so the bolt shivers; the
## RNG here is seeded from the effect's age at 25 ticks a second, so it
## shivers the same way and a scripted render is repeatable.


## How hard the bolt hits at `progress`: full for the first 18%, then fading.
static func strike(progress: float) -> float:
	return 1.0 if progress < 0.18 else maxf(0.0, 1.0 - (progress - 0.18) / 0.82)


## The spine: `segments` steps from `from` to `to`, jittered across the
## line most in the middle and not at all at either end, so it connects.
static func spine(from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var delta := to - from
	var distance := maxf(delta.length(), 1.0)
	var segments := maxi(8, int(distance / (7.0 * Fx.S)))
	var across := Vector2(-delta.y, delta.x) / distance
	var points := PackedVector2Array([from])
	for i in range(1, segments):
		var t := float(i) / segments
		points.append(from + delta * t + across * (rng.randf() - 0.5) * 28.0 * Fx.S * sin(t * PI))
	points.append(to)
	return points


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var from: Vector2 = fx["pos"]
	var to: Vector2 = fx["target"]
	var alpha := 1.0 - progress
	var hit := strike(progress)
	var flicker := 0.7 + 0.3 * sin(elapsed_ms * 0.08 + from.x * 0.13)
	var rng := Fx.rng_for(fx, elapsed_ms)
	var path := spine(from, to, rng)
	for layer in [[14.0, colour, alpha * 0.32 * hit], [9.0, Color("2060ff"), alpha * 0.45 * hit * flicker],
			[5.0, Color("80c0ff"), alpha * 0.85 * hit], [2.0, Color.WHITE, minf(1.0, alpha * 1.2) * hit]]:
		if layer[2] > 0.001:
			canvas.draw_polyline(path, Color(layer[1], layer[2]), layer[0] * Fx.S)
	var delta := to - from
	var distance := maxf(delta.length(), 1.0)
	var across := Vector2(-delta.y, delta.x) / distance
	for f in 5:
		var root: Vector2 = path[1 + rng.randi_range(0, path.size() - 3)]
		var sign := -1.0 if rng.randf() < 0.5 else 1.0
		var tilt := (rng.randf() - 0.5) * 0.6
		var reach := (12.0 + rng.randf() * 26.0) * Fx.S
		var fork_end := root + (across * sign + delta / distance * tilt) * reach
		var middle := root + (fork_end - root) * 0.5 + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 6.0 * Fx.S
		var fork := PackedVector2Array([root, middle, fork_end])
		for layer in [[4.0, Color("2060ff"), alpha * 0.4 * hit * flicker], [2.0, Color("a0d0ff"), alpha * 0.7 * hit],
				[1.0, Color.WHITE, alpha * 0.9 * hit]]:
			if layer[2] > 0.001:
				canvas.draw_polyline(fork, Color(layer[1], layer[2]), layer[0] * Fx.S)
	if progress < 0.55:
		var burst := 1.0 - progress / 0.55
		Fx.dot(canvas, to, 28.0 * burst + 12.0, Color("80c0ff", alpha * 0.35 * burst))
		Fx.dot(canvas, to, 12.0 * burst + 6.0, Color("e0f0ff", alpha * 0.7 * burst))
		Fx.dot(canvas, to, 5.0 * burst + 2.0, Color(Color.WHITE, minf(1.0, alpha * burst * 1.2)))
		for i in 10:
			var angle := i * TAU / 10.0 + elapsed_ms * 0.02
			Fx.line(canvas, to, Fx.polar(to, angle, (14.0 + 18.0 * burst + rng.randf() * 8.0) * Fx.S), 2.0,
				Color(Color.WHITE, alpha * 0.85 * burst))
	Fx.dot(canvas, from, 6.0 + 2.0 * sin(elapsed_ms * 0.05), Color("80c0ff", alpha * 0.45 * hit * flicker))
	Fx.dot(canvas, from, 3.0, Color(Color.WHITE, alpha * 0.7 * hit))
