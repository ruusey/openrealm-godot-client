class_name FxPoisonSplash
extends RefCounted

## POISON_SPLASH (5): a thrown vial, then where it bursts -- two packets,
## told apart by FxThrownArc.is_throw. In flight, a chunky parabolic trail,
## five drips falling off it and a fat glowing blob at the head, green for
## the assassin's vial; a boss grenade (tier 10 red, 12 blue, 11 green like
## the vial) recolours it. The splash is a toxic cloud expanding from 40%
## to full: a tier-coloured halo, a green body with a thick tier rim,
## fourteen bubbles drifting round it and a pulsing fume at the centre.

const GREEN := 0
const RED := 1
const BLUE := 2
## [trail, drip, glow, body, core] per palette, from the web's throw.
const THROW_COLOURS := [
	[Color("339920"), Color("2a8818"), Color("30771a"), Color("40cc30"), Color("90ff70")],
	[Color("e6280f"), Color("c01505"), Color("ff3315"), Color("ff4d0d"), Color("ffd955")],
	[Color("1e6fe6"), Color("1550c0"), Color("33a0ff"), Color("2d7dff"), Color("90d0ff")],
]
const BUBBLES := 14


## Which throw palette a tier gets: only the 10 and 12 sentinels differ.
static func palette(tier: int) -> int:
	return RED if tier == 10 else BLUE if tier == 12 else GREEN


static func cloud_radius(radius: float, progress: float) -> float:
	return radius * (0.4 + progress * 0.6)


## How far drip `i` has fallen below the trail, in web px.
static func drip_fall_px(i: int, progress: float) -> float:
	return progress * 20.0 * (i + 1) / 5.0


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	if FxThrownArc.is_throw(fx):
		_throw(canvas, fx["pos"], fx["target"], minf(progress, 1.0), THROW_COLOURS[palette(int(fx.get("tier", 0)))])
	else:
		_splash(canvas, fx["pos"], cloud_radius(fx["radius"], progress), 1.0 - progress, colour, elapsed_ms)


static func _throw(canvas: CanvasItem, from: Vector2, to: Vector2, head: float, colours: Array) -> void:
	FxThrownArc.trail(canvas, from, to, head, Vector2(2.0, 6.0), Vector2(0.15, 0.4), colours[0])
	var drip_alpha := maxf(0.0, 0.5 - head * 0.6)
	if drip_alpha > 0.0:
		for i in 5:
			var p := FxThrownArc.point(from, to, head * (0.3 + 0.7 * i / 5.0))
			var top := p + Vector2(-2.0, drip_fall_px(i, head)) * Fx.S
			canvas.draw_rect(Rect2(top, Vector2(4.0, 3.0 + i) * Fx.S), Color(colours[1], drip_alpha))
	if head < 1.0:
		var vial := FxThrownArc.point(from, to, head)
		Fx.dot(canvas, vial, 10.0, Color(colours[2], 0.4))
		Fx.dot(canvas, vial, 7.0, Color(colours[3], 0.9))
		Fx.dot(canvas, vial - Vector2(2.0, 2.0) * Fx.S, 3.0, Color(colours[4], 0.7))


static func _splash(canvas: CanvasItem, at: Vector2, cloud: float, alpha: float, colour: Color, elapsed_ms: int) -> void:
	canvas.draw_circle(at, cloud * 1.1, Color(colour, alpha * 0.25))
	canvas.draw_circle(at, cloud, Color("4cc530", alpha * 0.4))
	Fx.ring(canvas, at, cloud, 4.0, Color(colour, alpha * 0.9))
	Fx.ring(canvas, at, cloud * 0.85, 2.0, Color("a0ff70", alpha * 0.7))
	for i in BUBBLES:
		var angle := float(i) / BUBBLES * TAU + elapsed_ms * 0.003
		var wobble := sin(elapsed_ms * 0.005 + i) * 0.15
		var bubble := Fx.polar(at, angle, cloud * (0.45 + wobble))
		Fx.dot(canvas, bubble, 7.0, Color("80e060", alpha * 0.4))
		Fx.dot(canvas, bubble, 4.0, Color("c0ff80", alpha * 0.85))
	var fume := 0.5 + 0.5 * sin(elapsed_ms * 0.012)
	canvas.draw_circle(at, cloud * 0.25, Color("60ff40", alpha * 0.7 * fume))
