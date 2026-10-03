class_name FxRampageAura
extends RefCounted

## RAMPAGE_AURA (41): the fury that ignites on Rage and Frenzy. A short
## burst, not a standing aura: an ignition flash and a shockwave ring throw
## out over the first 30%, then flames erupt round the body -- tongues
## leaning upward and flickering, embers climbing, over a pulsing red disc
## and a ring of fury spikes -- peaking early and burning out by the end.
## Ignores the tier colour; red and gold whatever the caster.

const FLAME := Color("ff4020")
const HOT := Color("ffd040")
const DEEP := Color("600010")
const EMBER := Color("ff8030")
const TONGUES := 10
const EMBERS := 6


## The ignition's strength, a sharp peak at 15% gone by 35%.
static func ignite(progress: float) -> float:
	if progress > 0.35:
		return 0.0
	var t := progress / 0.35
	return t / 0.4 if t <= 0.4 else maxf(0.0, 1.0 - (t - 0.4) / 0.6)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = maxf(fx["radius"], 20.0)
	var alpha := 1.0 - progress
	Fx.dot(canvas, at, radius, Color(DEEP, alpha * 0.4))
	Fx.dot(canvas, at, radius * 0.8, Color(FLAME, alpha * 0.4 * (0.8 + 0.2 * sin(elapsed_ms * 0.03))))
	var spike := ignite(progress)
	if spike > 0.0:
		Fx.ring(canvas, at, radius * (0.4 + 1.1 * progress / 0.35), 4.0, Color(HOT, spike))
		Fx.dot(canvas, at, radius * 0.5 * spike + 6.0, Color(Color.WHITE, spike))
		Fx.dot(canvas, at, radius * 0.7 * spike + 8.0, Color(HOT, spike * 0.7))
	for i in TONGUES:
		var angle := i * TAU / TONGUES + elapsed_ms * 0.004
		var flick := 0.75 + 0.35 * sin(elapsed_ms * 0.02 + i * 1.7)
		var base := Fx.polar(at, angle, radius * 0.8)
		# Lean the tongues upward so the fire reads as rising, not radial.
		var tip := Fx.polar(at, angle, radius * 1.1 * flick) - Vector2(0.0, radius * 0.4 * flick)
		var side := Vector2(-sin(angle), cos(angle)) * radius * 0.14
		Fx.polygon(canvas, [base + side, tip, base - side], Color(FLAME, alpha * 0.95))
		Fx.polygon(canvas, [base + side * 0.55, tip, base - side * 0.55], Color(HOT, alpha))
	_embers(canvas, at, radius, progress, alpha)


## Embers climbing off the body and winking out, from a fixed scatter.
static func _embers(canvas: CanvasItem, at: Vector2, radius: float, progress: float, alpha: float) -> void:
	for i in EMBERS:
		var seed := i * 0.613
		var spread := (fmod(seed * 7.0, 1.0) - 0.5) * radius * 1.4
		var rise := radius * (0.4 + 1.6 * fmod(progress + seed, 1.0))
		var pos := at + Vector2(spread, -rise)
		Fx.dot(canvas, pos, 2.2 * (1.0 - fmod(progress + seed, 1.0)), Color(EMBER, alpha * 0.85))
