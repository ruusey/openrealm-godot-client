class_name FxGroundPound
extends RefCounted

## GROUND_POUND (58): the Heavy DPS slam. A dust ring bursting out to the
## radius over the first 40% in three strokes (dark, dust, light), six
## zig-zag ground cracks fanning from the centre, eight dust puffs that
## drift up and swell as they fade, and a white impact flash that is gone
## by a quarter of the way.

const DUST := Color("b89060")
const DARK := Color("402810")
const LIGHT_DUST := Color("e0c890")
const PUFFS := 8


static func ring_radius(radius: float, progress: float) -> float:
	return radius * (0.2 + 0.8 * minf(1.0, progress / 0.4))


static func crack_reach(radius: float, progress: float) -> float:
	return radius * (0.5 + 0.55 * progress)


static func flash(progress: float) -> float:
	return maxf(0.0, 1.0 - progress * 4.0)


## Where puff `i` sits before it drifts: a fixed scatter, the same every
## frame, as the web's seeded one is.
static func puff_offset(radius: float, i: int) -> Vector2:
	var seed := i * 0.617
	var angle := i * TAU / PUFFS + seed * 0.4
	return Vector2(cos(angle), sin(angle)) * radius * (0.3 + 0.5 * fmod(seed * 13.0, 1.0))


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var ring := ring_radius(radius, progress)
	var ring_alpha := alpha * (1.0 - minf(1.0, progress / 0.4) * 0.5)
	Fx.ring(canvas, at, ring, 8.0, Color(DARK, ring_alpha * 0.85))
	Fx.ring(canvas, at, ring, 5.0, Color(DUST, ring_alpha))
	Fx.ring(canvas, at, ring, 2.0, Color(LIGHT_DUST, ring_alpha * 0.9))
	var reach := crack_reach(radius, progress)
	var crack := Color(DARK, alpha * (1.0 - progress * 0.4))
	for i in 6:
		var angle := i * TAU / 6.0 + 0.3
		var bend := angle + (0.15 if i % 2 == 0 else -0.15)
		if crack.a > 0.001:
			canvas.draw_polyline(PackedVector2Array([at, Fx.polar(at, angle, reach * 0.55), Fx.polar(at, bend, reach)]),
				crack, 4.0 * Fx.S)
	var puff_px := 4.0 + 4.0 * progress
	for i in PUFFS:
		var puff := at + puff_offset(radius, i) - Vector2(0.0, progress * 8.0 * Fx.S)
		Fx.dot(canvas, puff, puff_px, Color(DUST, alpha * (1.0 - progress) * 0.75))
		Fx.dot(canvas, puff, puff_px * 0.5, Color(LIGHT_DUST, alpha * (1.0 - progress) * 0.55))
	var early := flash(progress)
	if early > 0.0:
		Fx.dot(canvas, at, 12.0 * early + 6.0, Color(Color.WHITE, alpha * early))
		Fx.dot(canvas, at, 18.0 * early + 8.0, Color(LIGHT_DUST, alpha * early * 0.8))
