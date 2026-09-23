class_name FxHasteWind
extends RefCounted

## HASTE_WIND (39): five cyan wind streamers at the caster's feet, each a
## short cyan dash with a white core rising from under the feet through
## the radius and fading as it climbs, staggered so they are never all at
## the same height, and wrapping round to start again.

const STREAMERS := 5
const CYAN := Color("40dfff")
## A streamer's length, 18 web px.
const LENGTH := 18.0 * Fx.S


## How far up streamer `i` has climbed, 0..1, wrapping.
static func phase(i: int, progress: float) -> float:
	return fmod(progress + i * 0.523, 1.0)


## Where streamer `i`'s upper end is from the caster: across by up to 60%
## of the radius either side, and from 40% of it below the feet to 80%
## above them as its phase runs.
static func streamer_top(radius: float, i: int, progress: float) -> Vector2:
	var seed := i * 0.523
	return Vector2((seed * 2.0 - 1.0) * radius * 0.6, radius * 0.4 - phase(i, progress) * radius * 1.2)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	for i in STREAMERS:
		var top := at + streamer_top(fx["radius"], i, progress)
		var bottom := top + Vector2(0.0, LENGTH)
		var fading := (1.0 - phase(i, progress)) * alpha
		Fx.line(canvas, top, bottom, 4.0, Color(CYAN, fading))
		Fx.line(canvas, top, bottom, 2.0, Color(Color.WHITE, fading))
