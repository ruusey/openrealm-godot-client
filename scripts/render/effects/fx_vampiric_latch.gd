class_name FxVampiricLatch
extends RefCounted

## VAMPIRIC_LATCH (52): the necromancer's drain tendrils. A dark halo
## inside a blood rim, eight crimson tendrils snaking out from the centre
## to bite at the rim with a fleshy mouth, and a pulsing heart at the
## middle.

const BLOOD := Color("c02040")
const FLESHY := Color("ff80a0")
const SEGMENTS := 6


## A tendril's sideways sway `along` of the way out, in world units: a
## sine of three half-waves, up to 6 web px at the rim.
static func sway(phase: float, along: float) -> float:
	return sin(phase + along * PI * 3.0) * 6.0 * Fx.S * along


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var alpha := 1.0 - progress
	canvas.draw_circle(at, radius, Color("300810", alpha * 0.5))
	Fx.ring(canvas, at, radius, 2.0, Color(BLOOD, alpha * 0.9))
	for i in 8:
		var angle := i * TAU / 8.0
		var out := Vector2(cos(angle), sin(angle))
		var side := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
		var phase := elapsed_ms * 0.004 + i
		var previous := at
		for s in range(1, SEGMENTS + 1):
			var along := float(s) / SEGMENTS
			var point := at + out * radius * along + side * sway(phase, along)
			Fx.line(canvas, previous, point, 3.0, Color(BLOOD, alpha * 0.95))
			previous = point
		Fx.dot(canvas, previous, 3.5, Color(FLESHY, alpha))
	var pulse := 0.7 + 0.3 * sin(elapsed_ms * 0.009)
	Fx.dot(canvas, at, 8.0, Color(BLOOD, alpha * pulse))
	Fx.dot(canvas, at, 4.0, Color(FLESHY, alpha))
