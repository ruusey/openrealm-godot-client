class_name FxPaladinSeal
extends RefCounted

## PALADIN_SEAL (14): consecration. A gold cast ring snapping out to the
## range, a pillar of light rising from the caster, a slowly turning halo
## with sun-rays, a radiant cross in three layers with flares at its four
## tips, motes ascending the pillar, and a flash at the cast.


static func base_radius(radius: float, progress: float) -> float:
	return radius * (0.70 + 0.30 * minf(1.0, progress * 3.0))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var base := base_radius(radius, progress)
	Fx.ring(canvas, at, radius * sqrt(minf(1.0, progress * 4.0)), 4.0, Color("ffe673", alpha * 0.85 * (1.0 - progress)))
	Fx.ring(canvas, at, radius, 2.0, Color(Color.WHITE, alpha * 0.55))
	var pillar_h := base * 2.4
	var pillar_w := base * 0.55
	canvas.draw_rect(Rect2(at.x - pillar_w, at.y - pillar_h, pillar_w * 2.0, pillar_h), Color(colour, alpha * 0.18))
	canvas.draw_rect(Rect2(at.x - pillar_w * 0.55, at.y - pillar_h * 0.95, pillar_w * 1.1, pillar_h * 0.95), Color("fff0a0", alpha * 0.30))
	canvas.draw_rect(Rect2(at.x - pillar_w * 0.20, at.y - pillar_h * 0.92, pillar_w * 0.4, pillar_h * 0.92), Color(Color.WHITE, alpha * 0.45))
	var halo := base * 0.78
	var centre := at - Vector2(0.0, base * 0.15)
	canvas.draw_circle(centre, halo, Color(colour, alpha * 0.22))
	Fx.ring(canvas, centre, halo, 3.0, Color("ffe070", alpha * 0.85))
	Fx.ring(canvas, centre, halo * 0.92, 2.0, Color(Color.WHITE, alpha * 0.6))
	var pulse := 0.8 + 0.2 * sin(elapsed_ms * 0.012)
	for i in 12:
		var angle := i * TAU / 12.0 + elapsed_ms * 0.0015
		Fx.line(canvas, Fx.polar(centre, angle, halo * 0.95),
			Fx.polar(centre, angle, halo * (1.15 + 0.08 * sin(elapsed_ms * 0.008 + i))), 2.0,
			Color("fff0a0", alpha * 0.7 * pulse))
	# The cross: a vertical arm and a horizontal one sitting a little above
	# its middle, each in glow, gold and white.
	var arm_h := halo * 1.55
	var arm_w := halo * 0.18
	var bar_h := halo * 0.18
	var bar_w := halo * 1.05
	var bar_y := centre.y - arm_h * 0.12
	for layer in [[1.5, 0.55, 1.1, 1.0, Color(colour, alpha * 0.55)], [1.0, 0.5, 1.0, 0.95, Color("ffe070", alpha * 0.85)],
			[0.45, 0.5, 1.0, 0.92, Color(Color.WHITE, minf(1.0, alpha))]]:
		var wide: float = layer[0]
		canvas.draw_rect(Rect2(centre.x - arm_w * wide, centre.y - arm_h * layer[1], arm_w * wide * 2.0, arm_h * layer[2]), layer[4])
		canvas.draw_rect(Rect2(centre.x - bar_w * layer[3], bar_y - bar_h * wide, bar_w * layer[3] * 2.0, bar_h * wide * 2.0), layer[4])
	var flare := 4.0 + 2.0 * pulse
	for tip in [centre - Vector2(0, arm_h * 0.5), centre + Vector2(0, arm_h * 0.5),
			Vector2(centre.x - bar_w * 0.95, bar_y), Vector2(centre.x + bar_w * 0.95, bar_y)]:
		Fx.dot(canvas, tip, flare * 1.8, Color(colour, alpha * 0.5))
		Fx.dot(canvas, tip, flare, Color(Color.WHITE, alpha * 0.9))
	for i in 14:
		var seed := i * 0.61
		var phase := fmod(progress + seed, 1.0)
		var mote_alpha := sin(phase * PI) * alpha
		if mote_alpha <= 0.05:
			continue
		var mote := Vector2(at.x + sin(seed * 7.0 + elapsed_ms * 0.001) * base * 0.5, at.y + base * 0.6 - phase * pillar_h * 1.05)
		Fx.dot(canvas, mote, 5.0, Color("ffe070", mote_alpha * 0.5))
		Fx.dot(canvas, mote, 2.5, Color(Color.WHITE, minf(1.0, mote_alpha)))
	if progress < 0.18:
		var flash := 1.0 - progress / 0.18
		canvas.draw_circle(at, base * 0.55, Color(Color.WHITE, flash * 0.95))
		canvas.draw_circle(at, base * 0.85, Color("ffe070", flash * 0.7))
