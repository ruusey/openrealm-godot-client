class_name FxGroundPound
extends RefCounted

## GROUND_POUND (58): the Barbarian's slam. A short wind-up (a darkening
## shadow and a ring sucking inward, 0-15%), then the slam proper: a white
## flash, a double shock ring snapping out, jagged cracks punched through
## the ground and a ring of rock chunks launched on ballistic arcs (15-32%).
## From there the dust settles -- the ring slows, chunks fall, puffs rise,
## an icy haze marking the SLOWED it leaves. Radial, centred on the strike.

const DUST := Color("b89060")
const DARK := Color("402810")
const LIGHT_DUST := Color("e0c890")
const ROCK := Color("6b5540")
const FROST := Color("8fdcff")
const CHUNKS := 8
const CRACKS := 7
const ANTICIPATE_END := 0.15
const SLAM_END := 0.32


## The shock ring's radius, snapping out from the slam with a sqrt ease and
## holding just past the radius.
static func shock_radius(radius: float, progress: float) -> float:
	var t := clampf((progress - ANTICIPATE_END) / (1.0 - ANTICIPATE_END), 0.0, 1.0)
	return radius * minf(1.15, sqrt(t) * 1.25)


## The slam flash, only in the first beats after impact.
static func flash(progress: float) -> float:
	if progress < ANTICIPATE_END or progress > SLAM_END + 0.1:
		return 0.0
	return 1.0 - (progress - ANTICIPATE_END) / (SLAM_END + 0.1 - ANTICIPATE_END)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = maxf(fx["radius"], 24.0)
	var alpha := 1.0 - progress
	if progress < ANTICIPATE_END:
		var wt := progress / ANTICIPATE_END
		Fx.dot(canvas, at, radius * 0.4 * wt, Color(DARK, 0.5 * wt))
		Fx.ring(canvas, at, radius * (1.3 - 0.3 * wt), 3.0, Color(DUST, 0.4 * wt))
		return
	var ring := shock_radius(radius, progress)
	var ring_alpha := alpha * (1.0 - clampf((progress - SLAM_END) / 0.4, 0.0, 0.4))
	Fx.ring(canvas, at, ring, 9.0, Color(DARK, ring_alpha * 0.85))
	Fx.ring(canvas, at, ring, 5.0, Color(DUST, ring_alpha))
	Fx.ring(canvas, at, ring * 0.82, 3.0, Color(LIGHT_DUST, ring_alpha * 0.8))
	Fx.ring(canvas, at, ring * 1.02, 1.5, Color(FROST, ring_alpha * 0.45))
	_cracks(canvas, at, radius, progress, alpha)
	_chunks(canvas, at, radius, progress, alpha)
	_dust(canvas, at, radius, progress, alpha)
	var burst := flash(progress)
	if burst > 0.0:
		Fx.dot(canvas, at, 10.0 + 20.0 * burst, Color(Color.WHITE, burst))
		Fx.dot(canvas, at, 18.0 + 12.0 * burst, Color(LIGHT_DUST, burst * 0.8))


## Jagged fissures punched out from the centre, reaching further as it runs.
static func _cracks(canvas: CanvasItem, at: Vector2, radius: float, progress: float, alpha: float) -> void:
	var reach := radius * (0.55 + 0.6 * minf(1.0, (progress - ANTICIPATE_END) / 0.3))
	var colour := Color(DARK, alpha * (1.0 - progress * 0.3))
	if colour.a <= 0.001:
		return
	for i in CRACKS:
		var angle := i * TAU / CRACKS + 0.2
		var bend := angle + (0.18 if i % 2 == 0 else -0.18)
		canvas.draw_polyline(PackedVector2Array([at, Fx.polar(at, angle, reach * 0.5),
			Fx.polar(at, bend, reach * 0.78), Fx.polar(at, angle, reach)]), colour, 5.0 * Fx.S)


## A ring of rock chunks thrown out and up on a shared ballistic arc, each
## tumbling and shrinking as it falls back.
static func _chunks(canvas: CanvasItem, at: Vector2, radius: float, progress: float, alpha: float) -> void:
	var t := clampf((progress - ANTICIPATE_END) / (1.0 - ANTICIPATE_END), 0.0, 1.0)
	if t <= 0.0:
		return
	var out := radius * (0.3 + 1.0 * t)
	var lift := sin(t * PI) * radius * 0.7
	var size := (5.0 - 3.0 * t) * Fx.S
	for i in CHUNKS:
		var angle := i * TAU / CHUNKS + 0.4
		var pos := Fx.polar(at, angle, out) - Vector2(0.0, lift)
		var spin := angle + t * 6.0
		var tri := [pos + Vector2(cos(spin), sin(spin)) * size,
			pos + Vector2(cos(spin + 2.2), sin(spin + 2.2)) * size,
			pos + Vector2(cos(spin + 4.2), sin(spin + 4.2)) * size]
		Fx.polygon(canvas, tri, Color(ROCK, alpha))
		Fx.dot(canvas, tri[0], 1.0, Color(LIGHT_DUST, alpha * 0.7))


## Eight puffs drifting up and swelling as they thin out.
static func _dust(canvas: CanvasItem, at: Vector2, radius: float, progress: float, alpha: float) -> void:
	var puff_px := 4.0 + 5.0 * progress
	for i in 8:
		var angle := i * TAU / 8.0 + 0.3
		var spread := radius * (0.3 + 0.4 * fmod(i * 0.37, 1.0))
		var puff := Fx.polar(at, angle, spread) - Vector2(0.0, progress * 10.0 * Fx.S)
		Fx.dot(canvas, puff, puff_px, Color(DUST, alpha * (1.0 - progress) * 0.7))
		Fx.dot(canvas, puff, puff_px * 0.5, Color(LIGHT_DUST, alpha * (1.0 - progress) * 0.5))
