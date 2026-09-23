class_name FxTrapThrow
extends RefCounted

## TRAP_THROW (6): the trapper's trap in flight, then armed where it
## lands -- two packets, told apart by FxThrownArc.is_throw. In flight, a
## thin amber trail thickening toward a spinning brass trap with four teeth
## glinting round it; on the ground, the armed snare of FxSnareRing.

const TEETH := 4


## Where glint `i` sits around the trap's centre, spinning with its age.
static func glint_angle(i: int, elapsed_ms: int) -> float:
	return float(i) / TEETH * TAU + elapsed_ms * 0.01


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	if not FxThrownArc.is_throw(fx):
		FxSnareRing.paint(canvas, fx["pos"], fx["radius"], progress, colour, elapsed_ms)
		return
	var from: Vector2 = fx["pos"]
	var to: Vector2 = fx["target"]
	var head := minf(progress, 1.0)
	FxThrownArc.trail(canvas, from, to, head, Vector2(1.0, 3.0), Vector2(0.1, 0.3), Color("996622"))
	if head >= 1.0:
		return
	var trap := FxThrownArc.point(from, to, head)
	Fx.dot(canvas, trap, 9.0, Color("664411", 0.5))
	Fx.dot(canvas, trap, 6.0, Color("cc8833", 0.9))
	for i in TEETH:
		var glint := Fx.polar(trap, glint_angle(i, elapsed_ms), 4.0 * Fx.S)
		canvas.draw_rect(Rect2(glint - Vector2.ONE * Fx.S, Vector2(2.0, 2.0) * Fx.S), Color("ffcc44", 0.8))
