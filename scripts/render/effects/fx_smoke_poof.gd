class_name FxSmokePoof
extends RefCounted

## SMOKE_POOF (9): a rogue's cloak vanishing. Twelve billowing puffs
## turning slowly, four dagger slivers fanning out at the start, a
## three-layer pop, ember flecks drifting up, and grey wisps rising.


static func puff_radius(radius: float, progress: float) -> float:
	return radius * (0.6 + progress * 1.4)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var puff := puff_radius(fx["radius"], progress)
	for i in 12:
		var centre := Fx.polar(at, i * TAU / 12.0 + elapsed_ms * 0.002, puff * (0.30 + 0.20 * (i % 2)))
		var size := puff * (0.55 + 0.12 * sin(elapsed_ms * 0.01 + i))
		canvas.draw_circle(centre, size, Color(colour, alpha * 0.18))
		canvas.draw_circle(centre, size * 0.78, Color("808080", alpha * 0.32))
		canvas.draw_circle(centre, size * 0.45, Color("404040", alpha * 0.4))
	if progress < 0.35:
		var dagger_alpha := (1.0 - progress / 0.35) * alpha
		for i in 4:
			var angle := i * TAU / 4.0 + PI / 4.0
			var tip := Fx.polar(at, angle, puff * (0.55 + progress * 0.6))
			var along := Vector2(cos(angle), sin(angle))
			var across := Vector2(sin(angle), -cos(angle))
			Fx.polygon(canvas, [tip + along * 8.0 * Fx.S, tip + across * 2.5 * Fx.S, tip - along * 4.0 * Fx.S,
				tip - across * 2.5 * Fx.S], Color("b0b0c0", dagger_alpha * 0.85))
			Fx.polygon(canvas, [tip + along * 7.0 * Fx.S, tip + across * 1.0 * Fx.S, tip - along * 2.0 * Fx.S,
				tip - across * 1.0 * Fx.S], Color(Color.WHITE, dagger_alpha * 0.9))
	if progress < 0.30:
		var flash := 1.0 - progress / 0.30
		Fx.ring(canvas, at, puff * 0.7 * (1.0 + progress * 1.2), 4.0, Color(colour, flash * 0.75))
		canvas.draw_circle(at, puff * 0.55 * (1.0 + progress), Color(colour, flash * 0.55))
		canvas.draw_circle(at, puff * 0.35 * (1.0 + progress), Color(Color.WHITE, flash * 0.85))
	for i in 10:
		var seed := i * 0.439
		var phase := fmod(progress * 1.6 + seed, 1.0)
		var angle := fmod(seed * TAU + elapsed_ms * 0.001, TAU)
		var ember := Fx.polar(at, angle, puff * 0.4 + phase * puff * 0.7) - Vector2(0.0, phase * 28.0 * Fx.S)
		var ember_alpha := alpha * (1.0 - phase) * 0.95
		if ember_alpha <= 0.05:
			continue
		Fx.dot(canvas, ember, 3.0, Color("ff8030", ember_alpha * 0.6))
		Fx.dot(canvas, ember, 1.5, Color("ffff80", ember_alpha * 0.95))
	for i in 12:
		var seed := i * 0.83
		var drift := fmod(seed * 1.7, TAU)
		var lift := 18.0 * progress * (1 + (i & 1)) * Fx.S
		var wisp := at + Vector2(cos(drift) * puff * 0.4 + (i - 6) * 3.0 * Fx.S, sin(drift) * puff * 0.2 - lift)
		Fx.dot(canvas, wisp, 4.0 - progress * 2.0, Color("a0a0a0", alpha * 0.55))
