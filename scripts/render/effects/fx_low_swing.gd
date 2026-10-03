class_name FxLowSwing
extends RefCounted

## LOW_SWING (54): the Duelist's Ankle Strike, a quick low cut that travels.
## A steel blade sweeps across the front along the caster-to-strike axis
## over the first 55%, cutting a widening smear behind its bright leading
## edge; then an icy wake lingers and a few frost motes drip low, for the
## SLOWED it leaves. Aimed by Fx.facing.

const SWEEP := 1.7
const SHADOW := Color("30363f")
const STEEL := Color("9aa6b4")
const FROST := Color("8fdcff")


## How far the sweep has travelled, 0..1, snapping across the first 55%.
static func sweep_t(progress: float) -> float:
	return minf(1.0, progress / 0.55)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var dir := Fx.facing(fx)
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var reach: float = maxf(fx["radius"], 24.0) * 1.05
	var t := sweep_t(progress)
	var base := dir.angle()
	var start_a := base - SWEEP * 0.5
	var lead_a := start_a + SWEEP * t
	var segments := maxi(2, int(12 * t))
	canvas.draw_arc(at, reach, start_a, lead_a, segments + 1, Color(SHADOW, alpha * 0.75), 8.0 * Fx.S)
	canvas.draw_arc(at, reach, start_a, lead_a, segments + 1, Color(STEEL, alpha * 0.85), 5.0 * Fx.S)
	canvas.draw_arc(at, reach, start_a, lead_a, segments + 1, Color(Color.WHITE, alpha * 0.9), 2.0 * Fx.S)
	if t < 1.0:
		# The leading edge: a bright blade standing across the arc.
		var lead := Fx.polar(at, lead_a, reach)
		var tangent := Vector2(-sin(lead_a), cos(lead_a))
		Fx.line(canvas, lead - tangent * 7.0 * Fx.S, lead + tangent * 7.0 * Fx.S, 3.0, Color(Color.WHITE, alpha))
		Fx.dot(canvas, lead, 3.0, Color(Color.WHITE, alpha))
	else:
		# The cut has passed: an icy wake and motes dripping low (SLOWED).
		canvas.draw_arc(at, reach, start_a, start_a + SWEEP, segments + 1, Color(FROST, alpha * 0.5), 4.0 * Fx.S)
		for i in 4:
			var mote_a := start_a + SWEEP * (0.2 + 0.2 * i)
			var mote := Fx.polar(at, mote_a, reach * 0.9) + Vector2(0.0, progress * reach * 0.4)
			Fx.dot(canvas, mote, 2.2 * (1.0 - progress), Color(FROST, alpha * 0.8))
