class_name CooldownSweep
extends Control

## The cooldown over a round touch button: a dark wedge that sweeps away
## clockwise from twelve o'clock as the ability cools, the clock wipe phone
## games use, where the hotbar's square cell drains from the bottom
## (AbilityCell). It fills its parent and takes no touches.

const SHADE := Color(0.0, 0.0, 0.0, 0.6)
const STEPS := 48

## What is left of the cooldown: 1 just cast, 0 ready.
var fraction := 0.0:
	set(value):
		if not is_equal_approx(value, fraction):
			fraction = value
			queue_redraw()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var points := wedge(size * 0.5, minf(size.x, size.y) * 0.5, fraction)
	if points.size() >= 3:
		draw_colored_polygon(points, SHADE)


## The wedge from twelve o'clock, clockwise over `left` of the circle: the
## centre, then the rim. Empty when nothing is left.
static func wedge(centre: Vector2, radius: float, left: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if left <= 0.0:
		return points
	points.append(centre)
	var steps := maxi(2, ceili(STEPS * left))
	for step in steps + 1:
		var angle := -PI * 0.5 + TAU * left * float(step) / float(steps)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points
