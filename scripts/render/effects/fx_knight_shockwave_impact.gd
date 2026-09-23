class_name FxKnightShockwaveImpact
extends RefCounted

## KNIGHT_SHOCKWAVE's moment of contact, at the slam point: the burst that
## swells to the thrust's end and fades by the slam's (a tier halo, a
## white-hot core, a punch dot, twelve spokes and three cracks thrown
## forward), and the brief white flash centred on the thrust's end.

## The flash spans this much of the effect either side of THRUST_END.
const FLASH_WINDOW := 0.20


## How bright the flash is, 0..1 before the fade: a tent peaking at the
## thrust's end.
static func flash(progress: float) -> float:
	var off := absf(progress - FxKnightShockwave.THRUST_END)
	return 1.0 - off / FLASH_WINDOW if off < FLASH_WINDOW else 0.0


static func draw(canvas: CanvasItem, slam: Vector2, dir: Vector2, progress: float, alpha: float,
		colour: Color) -> void:
	var strength := FxKnightShockwave.slam_strength(progress) * alpha
	if strength > 0.02:
		_burst(canvas, slam, dir, strength, colour)
	var bright := flash(progress)
	if bright > 0.0:
		var flash_alpha := bright * alpha * 0.75
		Fx.dot(canvas, slam, 56.0 + bright * 24.0, Color(Color.WHITE, flash_alpha))
		Fx.dot(canvas, slam, 92.0, Color(colour, flash_alpha * 0.55))


static func _burst(canvas: CanvasItem, slam: Vector2, dir: Vector2, strength: float, colour: Color) -> void:
	Fx.dot(canvas, slam, 38.0 + strength * 18.0, Color(colour, strength * 0.55))
	Fx.dot(canvas, slam, 18.0 + strength * 10.0, Color(Color.WHITE, strength * 0.95))
	Fx.dot(canvas, slam, 8.0, Color(colour, strength))
	var spoke := Color(Color.WHITE, strength * 0.9)
	for i in 12:
		var angle := i * TAU / 12.0
		Fx.line(canvas, Fx.polar(slam, angle, 12.0 * Fx.S),
			Fx.polar(slam, angle, (28.0 + strength * 22.0) * Fx.S), 3.0, spoke)
	var crack := Color(colour, strength * 0.85)
	for i in [-1, 0, 1]:
		Fx.line(canvas, slam, slam + dir.rotated(i * 0.45) * (40.0 + strength * 30.0) * Fx.S, 4.0, crack)
