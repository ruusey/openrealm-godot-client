class_name FxNinjaKatana
extends RefCounted

## The ninja dash's katana cuts: at stations along the path a sword swings
## through ~170 degrees across it, eased so it is fast through the middle
## where the cut lands, leaving a crescent that brightens and thickens
## toward the blade. Neighbours swing opposite ways, a flurry rather than a
## metronome. The sword shows only while it swings; the crescent lingers
## 40% of a swing longer and fades.

## Each swing lasts half the effect.
const SWING := 0.50
const SPAN := PI * 0.95
const SEGMENTS := 14
## The web's pixel sizes, halved into world units.
const REACH := 56.0 * Fx.S
const HILT := 4.0 * Fx.S
const BLADE_WIDTH := 5.0 * Fx.S
const GLOW_EXTRA := 2.0 * Fx.S


## Ease in and out: slow at the ends of the swing, fast through the cut.
static func ease_swing(life: float) -> float:
	var s := minf(1.0, life)
	return 2.0 * s * s if s < 0.5 else 1.0 - pow(-2.0 * s + 2.0, 2.0) / 2.0


## Full strength through the swing, then fading over the afterglow.
static func fade(raw_life: float, alpha: float) -> float:
	return alpha if raw_life <= 1.0 else alpha * maxf(0.0, 1.0 - (raw_life - 1.0) / 0.4)


static func draw(canvas: CanvasItem, from: Vector2, to: Vector2, count: int, progress: float,
		colour: Color) -> void:
	var alpha := 1.0 - progress
	var along := (to - from).normalized()
	var across := Vector2(-along.y, along.x).angle()
	for i in count:
		var t := (i + 0.5) / count
		var begins := t * 0.55
		if progress < begins:
			continue
		var raw := (progress - begins) / SWING
		if raw > 1.4:
			continue
		var centre := from + (to - from) * t
		var side := 1.0 if i & 1 else -1.0
		var start := across - side * SPAN * 0.5
		var now := start + side * SPAN * ease_swing(raw)
		var strength := fade(raw, alpha)
		_crescent(canvas, centre, start, now, colour, strength)
		if raw <= 1.0:
			_sword(canvas, centre, now, colour, strength)


static func _crescent(canvas: CanvasItem, centre: Vector2, start: float, now: float, colour: Color,
		strength: float) -> void:
	for s in SEGMENTS:
		var lead := (s + 1.0) / SEGMENTS
		var a0 := Fx.polar(centre, start + (now - start) * s / SEGMENTS, REACH)
		var a1 := Fx.polar(centre, start + (now - start) * lead, REACH)
		var seg := strength * pow(lead, 1.4)
		Fx.line(canvas, a0, a1, 2.0 + 5.0 * lead, Color(colour, seg * 0.40))
		Fx.line(canvas, a0, a1, 1.0 + 3.0 * lead, Color(Color.WHITE, seg * 0.75))


static func _sword(canvas: CanvasItem, centre: Vector2, angle: float, colour: Color, strength: float) -> void:
	var tip := Fx.polar(centre, angle, REACH)
	var hilt := Fx.polar(centre, angle, HILT)
	var mid := (tip + hilt) * 0.5
	var normal := Vector2(-sin(angle), cos(angle))
	var glow := BLADE_WIDTH + GLOW_EXTRA
	Fx.polygon(canvas, [tip, mid + normal * glow, hilt, mid - normal * glow], Color(colour, strength * 0.40))
	var blade := [tip, mid + normal * BLADE_WIDTH, hilt, mid - normal * BLADE_WIDTH]
	FxBladeShapes.outline(canvas, blade, 1.0, Color(Color.BLACK, strength * 0.85))
	Fx.polygon(canvas, blade, Color("e8e8f0", strength * 0.92))
	Fx.dot(canvas, tip, 3.0, Color(Color.WHITE, strength))
	Fx.dot(canvas, hilt, 2.5, Color("2a1810", strength * 0.9))
