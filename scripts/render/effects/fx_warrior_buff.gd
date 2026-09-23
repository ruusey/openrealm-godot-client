class_name FxWarriorBuff
extends RefCounted

## WARRIOR_BUFF (12): a gritty battle rally. A warm dust haze, a jagged
## shockwave ring in the tier colour whose sixteen segments wobble, two
## crossed blades raised at the centre and swaying apart, eight chevrons
## circling and pointing outward, eighteen square embers riding the front,
## an angry flash at the cast, and a throbbing tier-tinted core that fades
## from 35% on.

const JAGS := 16
const CHEVRONS := 8
const EMBERS := 18


static func buff_radius(radius: float, progress: float) -> float:
	return radius * (0.5 + progress * 0.55)


## The core's alpha: full to 35%, then down to nothing at the end.
static func early_alpha(progress: float) -> float:
	var alpha := 1.0 - progress
	return alpha if progress < 0.35 else alpha * (1.0 - (progress - 0.35) / 0.65)


## The shock ring's radius at segment boundary `i`, wobbling with age.
static func jag_radius(buff: float, i: int, elapsed_ms: int) -> float:
	return buff * (0.92 + 0.08 * sin(i * 5.7 + elapsed_ms * 0.005))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var buff := buff_radius(fx["radius"], progress)
	canvas.draw_circle(at, buff * 1.1, Color("553322", alpha * 0.22))
	for i in JAGS:
		Fx.line(canvas, Fx.polar(at, i * TAU / JAGS, jag_radius(buff, i, elapsed_ms)),
			Fx.polar(at, (i + 1) * TAU / JAGS, jag_radius(buff, i + 1, elapsed_ms)), 5.0, Color(colour, alpha * 0.85))
	var sway := sin(elapsed_ms * 0.004) * 0.06
	_blade(canvas, at, -PI / 4.0 + sway, buff * 0.55, alpha)
	_blade(canvas, at, -PI * 3.0 / 4.0 - sway, buff * 0.55, alpha)
	for i in CHEVRONS:
		var angle := i * TAU / CHEVRONS + elapsed_ms * 0.005
		var centre := Fx.polar(at, angle, buff * 0.78)
		var out := Vector2(cos(angle), sin(angle)) * Fx.S
		var along := Vector2(-out.y, out.x)
		var wing_a := centre - along * 8.0 - out * 4.0
		var tip := centre + out * 9.0
		var wing_b := centre + along * 8.0 - out * 4.0
		for stroke in [[4.0, Color(colour, alpha * 0.85)], [2.0, Color("ffe0c0", alpha * 0.95)]]:
			Fx.line(canvas, wing_a, tip, stroke[0], stroke[1])
			Fx.line(canvas, tip, wing_b, stroke[0], stroke[1])
	for i in EMBERS:
		var seed := i * 0.91
		var ember := Fx.polar(at, seed * 6.28 + elapsed_ms * 0.004,
			buff * (0.85 + 0.20 * sin(elapsed_ms * 0.008 + seed)))
		var size := (3.0 if i % 2 == 1 else 2.0) * Fx.S
		canvas.draw_rect(Rect2(ember - Vector2.ONE * size, Vector2.ONE * size * 2.0), Color("ff6020", alpha * 0.85))
		var cool := size + Fx.S
		canvas.draw_rect(Rect2(ember - Vector2.ONE * cool, Vector2.ONE * cool * 2.0), Color("884400", alpha * 0.55))
	if progress < 0.18:
		var flash := 1.0 - progress / 0.18
		canvas.draw_circle(at, buff * 0.28, Color("ffe0c0", flash * 0.95))
		canvas.draw_circle(at, buff * 0.5, Color("ff8030", flash * 0.7))
	var pulse := 0.6 + 0.4 * sin(elapsed_ms * 0.022)
	canvas.draw_circle(at, buff * 0.22, Color(colour, early_alpha(progress) * 0.65 * pulse))


## A stretched diamond pointing along `angle`: a warm glow round a white
## steel core.
static func _blade(canvas: CanvasItem, at: Vector2, angle: float, length: float, alpha: float) -> void:
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	var glow := (6.0 + 3.0) * Fx.S
	Fx.polygon(canvas, [at + along * length * 1.1, at + across * glow, at - along * length * 0.55,
		at - across * glow], Color("ff8030", alpha * 0.55))
	var width := 6.0 * Fx.S
	Fx.polygon(canvas, [at + along * length, at + across * width, at - along * length * 0.5,
		at - across * width], Color(Color.WHITE, alpha * 0.95))
