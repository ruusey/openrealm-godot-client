class_name FxBeamWarning
extends RefCounted

## BEAM_WARNING (64): a boss's beam telegraph. A solid red band from the
## boss (`pos`) to the beam's end (`target`), as wide as twice the radius
## (the server sends the half-width there), flashing between 55% and full
## opacity. It does not fade with progress: it is a warning, and it holds
## until the effect expires.

const RED := Color("ff1010")


## The half-width in world units: the radius, but never under the web's
## 2 screen pixels.
static func half_width(radius: float) -> float:
	return maxf(2.0 * Fx.S, radius)


static func pulse(elapsed_ms: int) -> float:
	return 0.55 + 0.45 * absf(sin(elapsed_ms * 0.012))


## The band's four corners, or none when the beam has no length.
static func corners(from: Vector2, to: Vector2, half: float) -> Array:
	var along := to - from
	if along.length() < 0.001:
		return []
	var side := Vector2(-along.y, along.x).normalized() * half
	return [from + side, to + side, to - side, from - side]


static func draw(canvas: CanvasItem, fx: Dictionary, _progress: float, _colour: Color, elapsed_ms: int) -> void:
	var band := corners(fx["pos"], fx["target"], half_width(fx["radius"]))
	Fx.polygon(canvas, band, Color(RED, pulse(elapsed_ms)))
