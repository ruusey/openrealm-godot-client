class_name FxStasisField
extends RefCounted

## STASIS_FIELD (2): a mystic area freeze. A white flash in the first 15%,
## a frosted disc under a triple-stroke ice rim, eight jagged fracture
## lines from the centre to the edge, a faint lattice of seven hexagons,
## twelve ice shards turning inside the rim, ten wisps of frozen mist
## drifting out and up, and eight twinkles breathing in the middle.

const FROST := Color("6090d0")
const LATTICE := Color("e0f0ff")
const FRACTURES := 8
const FRACTURE_SEGMENTS := 4
const WISPS := 10


## The freeze flash: full at the cast, gone by 15%.
static func flash(progress: float) -> float:
	return 1.0 - progress / 0.15 if progress < 0.15 else 0.0


## Fracture `i`: from the centre to the rim in four steps, each pushed
## sideways by up to 4% of the radius so it reads as a crack.
static func fracture(at: Vector2, radius: float, i: int, elapsed_ms: int) -> PackedVector2Array:
	var angle := float(i) / FRACTURES * TAU + elapsed_ms * 0.0008
	var points := PackedVector2Array([at])
	for s in range(1, FRACTURE_SEGMENTS + 1):
		var t := float(s) / FRACTURE_SEGMENTS
		var jag := sin(t * 6.0 + i * 1.3) * radius * 0.04
		points.append(Fx.polar(at, angle, radius * t) + Vector2(cos(angle + PI / 2.0), sin(angle + PI / 2.0)) * jag)
	return points


static func hex_radius(radius: float) -> float:
	return radius * 0.22


## The lattice: one hexagon in the middle and six round it, 1.6 of a
## hexagon's radius out, as offsets from the centre.
static func hex_centres(radius: float) -> Array:
	var centres: Array = [Vector2.ZERO]
	for k in 6:
		centres.append(Fx.polar(Vector2.ZERO, k * PI / 3.0, hex_radius(radius) * 1.6))
	return centres


## How far wisp `i` has drifted, 0..1; each starts at its own offset and
## goes round one and a half times over the effect's life.
static func wisp_phase(i: int, progress: float) -> float:
	return fposmod(progress * 1.5 + i * 0.683, 1.0)


## Where wisp `i` is: out from 30% to 85% of the radius along its own
## heading, rising 14 web px as it goes.
static func wisp(at: Vector2, radius: float, i: int, progress: float) -> Vector2:
	var phase := wisp_phase(i, progress)
	var angle := i * 0.683 * TAU
	return Fx.polar(at, angle, radius * (0.3 + 0.55 * phase)) - Vector2(0.0, phase * 14.0 * Fx.S)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	if flash(progress) > 0.0:
		canvas.draw_circle(at, radius * 1.15, Color(Color.WHITE, flash(progress) * alpha * 0.6))
	canvas.draw_circle(at, radius, Color(FROST, alpha * 0.22))
	Fx.ring(canvas, at, radius, 6.0, Color("60a0ff", alpha * 0.55))
	Fx.ring(canvas, at, radius, 4.0, Color("b0e0ff", alpha * 0.95))
	Fx.ring(canvas, at, radius * 0.92, 2.0, Color(Color.WHITE, alpha * 0.7))
	for i in FRACTURES:
		canvas.draw_polyline(fracture(at, radius, i, elapsed_ms), Color("d0eaff", alpha * 0.55), 2.0 * Fx.S)
	_lattice(canvas, at, radius, Color(LATTICE, alpha * 0.45), elapsed_ms)
	for i in 12:
		var shard := Fx.polar(at, i / 12.0 * TAU + elapsed_ms * 0.003, radius * 0.78)
		Fx.dot(canvas, shard, 7.0, Color("a0d0ff", alpha * 0.35))
		Fx.polygon(canvas, [shard + Vector2(0, -5) * Fx.S, shard + Vector2(4, 0) * Fx.S,
			shard + Vector2(0, 5) * Fx.S, shard + Vector2(-4, 0) * Fx.S], Color(LATTICE, alpha * 0.95))
	for i in WISPS:
		var phase := wisp_phase(i, progress)
		var wisp_alpha := alpha * (1.0 - phase) * 0.85
		if wisp_alpha > 0.05:
			Fx.dot(canvas, wisp(at, radius, i, progress), 2.0 + (1.0 - phase) * 1.5, Color(Color.WHITE, wisp_alpha * 0.8))
	for i in 8:
		var reach := radius * (0.25 + 0.4 * absf(sin(elapsed_ms * 0.005 + i)))
		Fx.dot(canvas, Fx.polar(at, i / 8.0 * TAU - elapsed_ms * 0.004, reach), 2.0, Color(Color.WHITE, alpha * 0.6))


static func _lattice(canvas: CanvasItem, at: Vector2, radius: float, colour: Color, elapsed_ms: int) -> void:
	var size := hex_radius(radius)
	for centre in hex_centres(radius):
		var corners := PackedVector2Array()
		for v in 7:
			corners.append(Fx.polar(at + centre, (v % 6) * PI / 3.0 + elapsed_ms * 0.0006, size))
		canvas.draw_polyline(corners, colour, 1.5 * Fx.S)
