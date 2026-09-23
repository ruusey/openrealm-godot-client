class_name FxBoneSpikes
extends RefCounted

## BONE_SPIKES (24): jagged white shards erupt from the ground. A faint
## shadow disc, and nine bone spikes scattered inside it, each a dark
## triangle with a bone face over it, shooting up to full height in the
## first 45% and holding while the whole fades.

const SPIKES := 9


## How far up the spikes have grown, 0..1: full by 1/2.2 of the way in.
static func grow(progress: float) -> float:
	return minf(progress * 2.2, 1.0)


## Where spike `i` stands, as an offset from the centre.
static func spike_offset(radius: float, i: int) -> Vector2:
	var seed := i * 0.683
	var distance := radius * (0.20 + 0.7 * fposmod(seed * 13.0, 1.0))
	return Fx.polar(Vector2.ZERO, i * TAU / SPIKES + seed, distance)


## Spike `i`'s height in world units when fully grown: 14 to 24 web px.
static func spike_height(i: int) -> float:
	return (14.0 + 10.0 * fposmod(i * 0.683 * 7.0, 1.0)) * Fx.S


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color(Color.BLACK, alpha * 0.15))
	var width := 6.0 * Fx.S
	var up := grow(progress)
	for i in SPIKES:
		var base := at + spike_offset(radius, i)
		var height := spike_height(i) * up
		Fx.polygon(canvas, [base + Vector2(-width, 0.0), base + Vector2(width, 0.0), base + Vector2(0.0, -height)],
			Color("504830", alpha * 0.7))
		var face := base - Vector2(0.0, 1.0 * Fx.S)
		Fx.polygon(canvas, [face + Vector2(-width * 0.7, 0.0), face + Vector2(width * 0.7, 0.0),
			base + Vector2(0.0, -height * 0.92)], Color("eae0c0", alpha))
