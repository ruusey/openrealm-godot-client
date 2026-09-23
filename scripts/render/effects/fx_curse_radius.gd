class_name FxCurseRadius
extends RefCounted

## CURSE_RADIUS (4): two effects under one id. A curse cast is a swirling
## dark-magic vortex -- a translucent void, a shockwave pushing out over
## the first third, two counter-rotating dashed rune rings, eighteen motes
## spiralling in, and a pulsing black core. A tier of ten or more is the
## server's boss grenade marking where it lands: a solid danger disc at
## full radius from the start, a throbbing edge and a second pair of rings,
## red at 10, green at 11, blue at 12 -- FxGeneric's boss palette, which is
## the same three colours per tier as the web client's.

const VOID := Color("2a0a3a")
const MOTES := 18
const DASHES := 12


## The shockwave, 0..1: out over the first third, then held.
static func wave(progress: float) -> float:
	return minf(1.0, progress * 3.0)


static func shock_radius(radius: float, progress: float) -> float:
	return radius * (0.55 + 0.5 * wave(progress))


## How far in mote `i` has spiralled, 0 at the rim to 1 at the centre;
## each wraps back out, staggered around the ring.
static func inward(i: int, progress: float) -> float:
	return fmod(float(i) / MOTES + progress * 1.3, 1.0)


## [fill, edge, second edge] for a boss tier.
static func boss_colours(tier: int) -> Array:
	return FxGeneric.BOSS.get(tier, FxGeneric.BOSS_RED)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if int(fx.get("tier", 0)) >= FxGeneric.BOSS_TIER:
		_danger_zone(canvas, at, radius, alpha, elapsed_ms, boss_colours(int(fx["tier"])))
		return
	var t := elapsed_ms * 0.001
	canvas.draw_circle(at, radius, Color(VOID, alpha * 0.28))
	Fx.ring(canvas, at, shock_radius(radius, progress), 3.0, Color("9b30ff", alpha * 0.5 * (1.0 - wave(progress) * 0.5)))
	for ring in 2:
		var reach := radius * (0.78 if ring == 0 else 0.52)
		var turn := (1.0 if ring == 0 else -1.0) * t * 1.6
		var dash := Color("8040c0" if ring == 0 else "c060ff", alpha * 0.8)
		for i in DASHES:
			var a0 := float(i) / DASHES * TAU + turn
			Fx.line(canvas, Fx.polar(at, a0, reach), Fx.polar(at, a0 + PI / DASHES, reach), 2.0, dash)
	for i in MOTES:
		var spin := float(i) / MOTES * TAU - t * 2.2
		var closing := 1.0 - inward(i, progress)
		Fx.dot(canvas, Fx.polar(at, spin, radius * closing * 0.95), 1.0 + 2.5 * closing,
			Color("b060ff", alpha * (0.25 + 0.5 * closing)))
	var pulse := 0.6 + 0.4 * sin(t * 6.0)
	var core := radius * 0.1 + radius * 0.08 * pulse
	canvas.draw_circle(at, core, Color("10001a", alpha * 0.6))
	Fx.ring(canvas, at, core, 2.0, Color("d080ff", alpha * 0.9 * pulse))


## The web's boss path, drawn as it draws it: alpha is the plain fade and
## the edge throbs on the clock, where FxGeneric's form holds to 70%.
static func _danger_zone(canvas: CanvasItem, at: Vector2, radius: float, alpha: float,
		elapsed_ms: int, colours: Array) -> void:
	canvas.draw_circle(at, radius, Color(colours[0], alpha * 0.95))
	var urgency := 0.85 + 0.15 * sin(elapsed_ms * 0.025)
	for scale in [1.0, 0.97, 1.03]:
		Fx.ring(canvas, at, radius * scale, 8.0, Color(colours[1], alpha * urgency))
	for scale in [0.9, 1.1]:
		Fx.ring(canvas, at, radius * scale, 6.0, Color(colours[2], alpha * 0.85))
