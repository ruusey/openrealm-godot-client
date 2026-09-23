class_name FxTrapTrigger
extends RefCounted

## TRAP_TRIGGER (8): a snare snapping shut. A white-and-orange flash over
## the first quarter, a tier-coloured ring and an amber one closing to
## nothing, eight steel teeth riding in on the ring with a bright edge,
## eight amber pellets just outside it, and from the quarter mark eight
## flecks of blood flying out and falling. The rings hold full for the
## first 30% and fade after.

const TEETH := 8
const FLECKS := 8


static func close_radius(radius: float, progress: float) -> float:
	return radius * (1.0 - progress)


static func flash_alpha(progress: float) -> float:
	return 1.0 if progress < 0.3 else maxf(0.0, 1.0 - (progress - 0.3) / 0.7)


## How far through its flight the blood is, 0..1, or -1 before the bite.
static func spray(progress: float) -> float:
	return (progress - 0.25) / 0.75 if progress >= 0.25 else -1.0


## Where fleck `i` is from the snap point at spray `t`: each out along its
## own angle, 40 to 62 web px by the end, and falling.
static func fleck_offset(i: int, t: float) -> Vector2:
	var seed := i * 0.737
	var angle := fmod(seed * TAU, TAU)
	var out := Vector2(cos(angle), sin(angle)) * t * (40.0 + seed * 22.0)
	return (out + Vector2(0.0, t * t * 12.0)) * Fx.S


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	var closing := close_radius(radius, progress)
	var held := flash_alpha(progress)
	if progress < 0.25:
		var snap := 1.0 - progress / 0.25
		canvas.draw_circle(at, radius * 0.5, Color(Color.WHITE, snap * 0.85))
		canvas.draw_circle(at, radius * 0.85, Color("ffaa00", snap * 0.7))
	Fx.ring(canvas, at, closing, 4.0, Color(colour, held * 0.95))
	Fx.ring(canvas, at, closing * 0.7, 2.0, Color("ffcc44", held * 0.6))
	for i in TEETH:
		var angle := float(i) / TEETH * TAU + elapsed_ms * 0.001
		var tip := Fx.polar(at, angle, closing + 4.0 * Fx.S)
		var base := Fx.polar(at, angle, closing + 18.0 * Fx.S)
		var side := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)) * 5.0 * Fx.S
		Fx.polygon(canvas, [tip, base + side, base - side], Color("a0a0b0", held * 0.92))
		Fx.polygon(canvas, [tip, (tip + base + side) * 0.5, (tip + base - side) * 0.5], Color(Color.WHITE, held * 0.75))
	var t := spray(progress)
	if t >= 0.0:
		for i in FLECKS:
			var fleck_alpha := alpha * (1.0 - t) * 0.85
			if fleck_alpha <= 0.04:
				continue
			var fleck := at + fleck_offset(i, t)
			Fx.dot(canvas, fleck, 2.5, Color("8c1010", fleck_alpha))
			Fx.dot(canvas, fleck, 1.5, Color("c8302a", fleck_alpha * 0.7))
	for i in 8:
		Fx.dot(canvas, Fx.polar(at, i * TAU / 8.0, closing + 8.0 * Fx.S), 2.0, Color("ffcc44", held * 0.7))
