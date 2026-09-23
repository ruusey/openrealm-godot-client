class_name FxThrownArc
extends RefCounted

## The lob that POISON_SPLASH (5) and TRAP_THROW (6) draw when the server
## sends them as a throw: a line effect, radius 0, from the thrower to the
## landing point. The landing is a separate packet with a radius, so which
## form an effect takes is read off `fx`, as the web client reads it, not
## off its progress.
##
## The path is the web client's parabola: straight from end to end, lifted
## by 4h·f·(1-f) where the peak h is half the throw's length. The trail is
## twenty segments up to the head, thickening and brightening toward it.

const STEPS := 20


## A throw is a line effect: no radius, and somewhere to land.
static func is_throw(fx: Dictionary) -> bool:
	return float(fx["radius"]) == 0.0 and fx["target"] != Vector2.ZERO


static func arc_height(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to) * 0.5


## Where the thrown thing is `f` of the way along, 0..1.
static func point(from: Vector2, to: Vector2, f: float) -> Vector2:
	return from + (to - from) * f - Vector2(0.0, 4.0 * arc_height(from, to) * f * (1.0 - f))


## How far along the trail a segment ending at `f1` is, 0 at the thrower
## and 1 at the head: what its width and alpha grow with.
static func toward_head(f1: float, head: float) -> float:
	return f1 / maxf(head, 0.01)


## The trail up to `head`: each segment `width_px.x + width_px.y * t` web
## pixels wide at alpha `alphas.x + alphas.y * t`, t from toward_head.
static func trail(canvas: CanvasItem, from: Vector2, to: Vector2, head: float,
		width_px: Vector2, alphas: Vector2, colour: Color) -> void:
	for i in STEPS:
		var f0 := float(i) / STEPS
		var f1 := float(i + 1) / STEPS
		if f1 > head:
			break
		var t := toward_head(f1, head)
		Fx.line(canvas, point(from, to, f0), point(from, to, f1), width_px.x + width_px.y * t,
			Color(colour, alphas.x + alphas.y * t))
