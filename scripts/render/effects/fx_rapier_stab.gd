class_name FxRapierStab
extends RefCounted

## RAPIER_STAB (53): the Heavy Debuffer's sidearm, a quick silver thrust.
## Short-lived: four steel-and-white dashes flick out along the axes, a
## white sparkle at each tip, and a white-and-silver core flash that
## shrinks away. The web centres it on the effect's position; it has no
## direction, so neither does this.

const SILVER := Color("e0e6ee")
const STEEL := Color("8a98a8")


static func arm_reach(radius: float, progress: float) -> float:
	return radius * (0.4 + 0.7 * progress)


## The core's two discs in web pixels: (white, silver).
static func core_px(progress: float) -> Vector2:
	var pulse := 1.0 - progress
	return Vector2(6.0 + 3.0 * pulse, 10.0 + 4.0 * pulse)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var reach := arm_reach(fx["radius"], progress)
	for stroke in [[4.0, Color(STEEL, alpha * 0.85)], [2.0, Color(Color.WHITE, alpha)]]:
		for i in 4:
			var angle := i * TAU / 4.0
			Fx.line(canvas, Fx.polar(at, angle, reach * 0.35), Fx.polar(at, angle, reach), stroke[0], stroke[1])
	for i in 4:
		Fx.dot(canvas, Fx.polar(at, i * TAU / 4.0, reach), 3.0 + 2.0 * (1.0 - progress),
			Color(Color.WHITE, alpha * (1.0 - progress * 0.6)))
	# The web's order: the white core first, the wider silver over it.
	var core := core_px(progress)
	var pulse := 1.0 - progress
	Fx.dot(canvas, at, core.x, Color(Color.WHITE, alpha * pulse))
	Fx.dot(canvas, at, core.y, Color(SILVER, alpha * pulse * 0.7))
