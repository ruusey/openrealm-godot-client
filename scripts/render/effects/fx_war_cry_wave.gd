class_name FxWarCryWave
extends RefCounted

## WAR_CRY_WAVE (36): the impact of the knight's shield bash, a steel and
## gold concussion. A settling dust disc, a gold shock ring over a pale
## steel one, eight radial cracks, a white slam flash in the first 30%,
## and a small gold core. It holds full strength to 65%, then fades; it
## ignores the tier colour.

const CRACKS := 8


## The ring's radius: a square-root snap out, stopping at 1.12 of the
## effect's radius.
static func ring_radius(radius: float, progress: float) -> float:
	return radius * minf(1.12, sqrt(progress) * 1.15)


## Full to 65%, then a linear fade to nothing.
static func strength(progress: float) -> float:
	return 1.0 if progress < 0.65 else maxf(0.0, 1.0 - (progress - 0.65) / 0.35)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var a := strength(progress)
	var ring := ring_radius(radius, progress)
	if ring > 0.0:
		canvas.draw_circle(at, ring * 0.92, Color("9a948a", a * 0.18))
	Fx.ring(canvas, at, ring, 6.0, Color("dbca7a", a))
	Fx.ring(canvas, at, ring * 0.85, 3.0, Color("e6eeff", a * 0.9))
	for i in CRACKS:
		var angle := i * TAU / CRACKS
		Fx.line(canvas, Fx.polar(at, angle, ring * 0.14), Fx.polar(at, angle, ring * 0.95), 3.0,
			Color("ccd2e6", a * 0.8))
	if progress < 0.3:
		canvas.draw_circle(at, radius * 0.30 * (1.0 - progress), Color(Color.WHITE, (0.3 - progress) / 0.3 * 0.85))
	canvas.draw_circle(at, radius * 0.12, Color("f2d973", a * 0.5))
