class_name FxMeleeSwing
extends RefCounted

## MELEE_SWING (62): a swing in front of the wielder, toward the aim. The
## tier is the weapon: 1 sword, 2 axe, 3 hammer, 10 dagger. The size comes
## from the effect's radius, never from how far the cursor is. The web
## client can play an authored sheet instead; none is shipped, so this is
## its procedural path. A sword or axe sweeps a tapered glowing arc that
## holds and fades; a hammer arcs its head in and slams with a ring and a
## star; a dagger flicks twice.

const SWORD := 1
const AXE := 2
const HAMMER := 3
const DAGGER := 10


static func swing_radius(radius: float) -> float:
	return maxf(radius * 1.7, 30.0)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var origin: Vector2 = fx["target"]
	var aim: Vector2 = fx["pos"]
	var angle := (aim - origin).angle()
	var reach := swing_radius(fx["radius"])
	var alpha := maxf(0.0, 1.0 - progress)
	match int(fx.get("tier", 0)):
		HAMMER: _hammer(canvas, origin, angle, reach, progress, alpha)
		DAGGER: _dagger(canvas, origin, angle, reach, progress, alpha)
		_: _blade(canvas, origin, angle, reach, progress, int(fx.get("tier", 0)) == AXE)


## A curved blade silhouette: the outer edge on the arc, the inner edge
## tapering from nothing at the tail to `width` at the blade.
static func slash(canvas: CanvasItem, origin: Vector2, from: float, to: float, radius: float,
		width: float, colour: Color) -> void:
	var points: Array = []
	for i in 19:
		points.append(Fx.polar(origin, from + (to - from) * i / 18.0, radius))
	for i in range(18, -1, -1):
		var u := i / 18.0
		points.append(Fx.polar(origin, from + (to - from) * u, radius - width * pow(u, 0.55)))
	Fx.polygon(canvas, points, colour)


## The bright edge, segmented so it ramps up toward the leading end.
static func edge(canvas: CanvasItem, origin: Vector2, from: float, to: float, radius: float,
		colour: Color, width_px: float) -> void:
	for i in 18:
		var a0 := from + (to - from) * i / 18.0
		var a1 := from + (to - from) * (i + 1) / 18.0
		Fx.line(canvas, Fx.polar(origin, a0, radius), Fx.polar(origin, a1, radius), width_px,
			Color(colour, colour.a * (0.1 + 0.9 * (i + 1) / 18.0)))


static func _blade(canvas: CanvasItem, origin: Vector2, angle: float, reach: float, progress: float, axe: bool) -> void:
	var sweep := 2.0 if axe else 2.45
	var from := angle - sweep * 0.5
	var to := from + maxf(0.06, progress * sweep)
	var radius := reach * (1.0 if axe else 1.05)
	var width := radius * (0.42 if axe else 0.3)
	var hold := 1.0 if progress < 0.6 else maxf(0.0, (1.0 - progress) / 0.4)
	slash(canvas, origin, from, to, radius * 1.06, width * 1.4, Color("ff7a2a" if axe else "7fd0ff", 0.13 * hold))
	slash(canvas, origin, from, to, radius, width, Color("e8641e" if axe else "bfe8ff", 0.42 * hold))
	slash(canvas, origin, from, to, radius, width * 0.45, Color("ffd9a0" if axe else "ffffff", 0.6 * hold))
	edge(canvas, origin, from, to, radius, Color("ffe6b0" if axe else "ffffff", 0.95 * hold), 3.0 if axe else 2.2)
	var tip := Fx.polar(origin, to, radius)
	Fx.dot(canvas, tip, 3.5 if axe else 2.8, Color(Color.WHITE, hold))
	if axe and progress > 0.72:
		for k in 3:
			Fx.line(canvas, tip, Fx.polar(tip, to + (k - 1) * 0.3, reach * 0.22), 2.0, Color("ffc080", hold))


static func _hammer(canvas: CanvasItem, origin: Vector2, angle: float, reach: float, progress: float, alpha: float) -> void:
	var strike := Fx.polar(origin, angle, reach * 0.8)
	if progress < 0.45:
		var p := progress / 0.45
		var head := Fx.polar(origin, angle - 1.9 * (1.0 - p), reach * 0.8)
		Fx.line(canvas, origin, head, 5.0, Color("caa878", alpha))
		canvas.draw_circle(head, reach * 0.28, Color("9a6a38", alpha))
		canvas.draw_circle(head, reach * 0.18, Color("5a3a1e", alpha))
		canvas.draw_circle(head - Vector2(cos(angle), sin(angle)) * reach * 0.08, reach * 0.06, Color(Color.WHITE, alpha * 0.5))
		return
	var p := (progress - 0.45) / 0.55
	var ring := reach * 0.15 + p * reach * 0.9
	Fx.ring(canvas, strike, ring, 5.0 - 4.0 * p, Color("ffe0a0", alpha))
	canvas.draw_circle(strike, ring * 0.5, Color("fff6d0", alpha * (1.0 - p) * 0.4))
	for k in 6:
		var a := angle + k * PI / 3.0 + p * 0.3
		Fx.polygon(canvas, [Fx.polar(strike, a, reach * (0.5 + p * 0.5)), Fx.polar(strike, a + 0.22, reach * 0.13),
			Fx.polar(strike, a - 0.22, reach * 0.13)], Color("fff2c0", alpha * (1.0 - p)))


static func _dagger(canvas: CanvasItem, origin: Vector2, angle: float, reach: float, progress: float, alpha: float) -> void:
	var radius := reach * 0.62
	var first := progress / 0.55
	var second := (progress - 0.3) / 0.55
	if first > 0.0 and first < 1.0:
		var from := angle - 0.55
		var to := from + minf(1.0, first) * 1.05
		slash(canvas, origin, from, to, radius, radius * 0.16, Color("cdeeff", 0.5 * alpha))
		edge(canvas, origin, from, to, radius, Color(Color.WHITE, 0.95 * alpha), 2.0)
	if second > 0.0 and second < 1.0:
		var from := angle + 0.55
		var to := from - minf(1.0, second) * 1.05
		slash(canvas, origin, minf(from, to), maxf(from, to), radius * 0.94, radius * 0.15, Color("d4f2ff", 0.5 * alpha))
		edge(canvas, origin, minf(from, to), maxf(from, to), radius * 0.94, Color(Color.WHITE, 0.9 * alpha), 2.0)
