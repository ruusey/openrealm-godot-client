class_name StickDirection
extends RefCounted

## Movement input as the keys give it: one of eight directions at full
## speed, never a partial push.
##
## The phone's stick reports how far it is pushed, and both the predictor
## and the server scale the step by that length -- the server only clamps
## it at one -- so half a push walked at half speed and a wobbling thumb
## walked at a wobbling speed. The web client's stick (touch.js) is digital
## for the same reason, and this is its rule: under DEADZONE of a push is
## no movement; an axis turns on past ENTER and off only under LEAVE, the
## gap keeping a thumb held near the line from flickering between a
## straight and a diagonal. Keys press their axes fully, so they come out
## of it exactly as they went in.

const DEADZONE := 0.25
const ENTER := 0.45
const LEAVE := 0.3

var _x := 0
var _y := 0


## The raw vector in, a unit vector along one of eight directions, or zero, out.
func filter(raw: Vector2) -> Vector2:
	if raw.length() < DEADZONE:
		_x = 0
		_y = 0
		return Vector2.ZERO
	_x = _axis(_x, raw.x)
	_y = _axis(_y, raw.y)
	return Vector2(_x, _y).normalized()


static func _axis(held: int, value: float) -> int:
	if held == 0:
		return 1 if value > ENTER else (-1 if value < -ENTER else 0)
	if held * value < LEAVE:
		return int(signf(value)) if absf(value) > ENTER else 0
	return held
