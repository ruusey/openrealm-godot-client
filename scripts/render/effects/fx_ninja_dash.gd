class_name FxNinjaDash
extends RefCounted

## NINJA_DASH (13): a dash from `pos` to `target` cut through with blades.
## A slim spine along the path in a soft tier-coloured aura; a vortex of
## spinning blades orbiting across it (FxNinjaVortex); katanas swinging
## crescent cuts at stations along it (FxNinjaKatana); a grey vanish puff
## where the dash began and a flash with sparks where it lands. The number
## of blades and cuts grows with the dash's length, so a short dash and a
## long one are equally dense.


## How many blades orbit the path: the web's one per 14 screen pixels (7
## world), never fewer than fourteen.
static func blade_count(distance: float) -> int:
	return maxi(14, floori(distance / (14.0 * Fx.S)))


## How many katana cuts: one per 40 screen pixels (20 world), at least three.
static func slash_count(distance: float) -> int:
	return maxi(3, floori(distance / (40.0 * Fx.S)))


## The vanish puff at the start, gone by 62.5% of the way.
static func start_puff(progress: float) -> float:
	return maxf(0.0, 1.0 - progress * 1.6)


## The arrival flash, gone halfway through.
static func arrival(progress: float) -> float:
	return 1.0 - progress / 0.5 if progress < 0.5 else 0.0


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var from: Vector2 = fx["pos"]
	var to: Vector2 = fx["target"]
	var alpha := 1.0 - progress
	_spine(canvas, from, to, colour, alpha)
	var distance := from.distance_to(to)
	FxNinjaVortex.draw(canvas, from, to, blade_count(distance), progress, colour, elapsed_ms)
	FxNinjaKatana.draw(canvas, from, to, slash_count(distance), progress, colour)
	var puff := start_puff(progress)
	if puff > 0.0:
		Fx.dot(canvas, from, 16.0, Color("808080", puff * 0.6))
		Fx.dot(canvas, from, 26.0, Color(colour, puff * 0.4))
	_arrive(canvas, to, arrival(progress), colour, elapsed_ms)


## Toned down so the blades are what reads: an aura, a black outline for
## contrast on bright ground, a white core.
static func _spine(canvas: CanvasItem, from: Vector2, to: Vector2, colour: Color, alpha: float) -> void:
	Fx.line(canvas, from, to, 20.0, Color(colour, alpha * 0.10))
	Fx.line(canvas, from, to, 10.0, Color(colour, alpha * 0.25))
	Fx.line(canvas, from, to, 5.0, Color(Color.BLACK, alpha * 0.55))
	Fx.line(canvas, from, to, 3.0, Color(Color.WHITE, alpha * 0.75))


static func _arrive(canvas: CanvasItem, at: Vector2, flash: float, colour: Color, elapsed_ms: int) -> void:
	if flash <= 0.0:
		return
	Fx.dot(canvas, at, 12.0 + flash * 10.0, Color(Color.WHITE, flash * 0.9))
	Fx.dot(canvas, at, 26.0 + flash * 14.0, Color(colour, flash * 0.6))
	for i in 10:
		var angle := i * TAU / 10.0 + elapsed_ms * 0.005
		Fx.line(canvas, Fx.polar(at, angle, 8.0 * Fx.S), Fx.polar(at, angle, (22.0 + flash * 18.0) * Fx.S),
			2.0, Color(Color.WHITE, flash * 0.9))
