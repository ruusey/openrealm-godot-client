class_name FxRecklessSlash
extends RefCounted

## RECKLESS_SLASH (32): the berserker's wide red sweep, an arc of 1.4
## radians just beyond the radius -- a dark trace, the red blade, a white
## highlight. Both references centre it on +X ("sweeps right") whatever
## the aim, and so does this.

const SWEEP := 1.4
const SEGMENTS := 14
## The sweep's centre: straight right, as both references draw it.
const FACING := 0.0


static func reach(radius: float) -> float:
	return radius * 1.05


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var alpha := 1.0 - progress
	var r := reach(fx["radius"])
	FxBladeShapes.arc(canvas, at, FACING, SWEEP, r, SEGMENTS, 10.0, Color("600010", alpha * 0.85))
	FxBladeShapes.arc(canvas, at, FACING, SWEEP, r, SEGMENTS, 6.0, Color("ff2030", alpha))
	FxBladeShapes.arc(canvas, at, FACING, SWEEP, r, SEGMENTS, 3.0, Color(Color.WHITE, alpha * 0.9))
