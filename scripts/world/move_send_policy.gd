class_name MoveSendPolicy
extends RefCounted

## Decides which predicted ticks are worth putting on the wire.
##
## Every tick is predicted, but transmitting 64Hz of zero vectors while
## standing still is ~12 kbit/s of pure noise -- the web client calls it out as
## such -- so idle input collapses to a keepalive. The skipped packets are all
## (0,0), which move nothing, so the server's view and the replay history
## still agree.
##
## Separate from MovementPredictor because this is a bandwidth decision, not a
## physics one: nothing here may change where the player ends up.

## While idle, still anchor the server's reconciliation at ~4Hz.
const IDLE_KEEPALIVE_TICKS := 16

var _last_sent_input := Vector2.ZERO
var _idle_ticks := 0


func should_send(input: Vector2) -> bool:
	var moving := input.length_squared() > 0.0
	var was_moving := _last_sent_input.length_squared() > 0.0
	var send := false

	if moving or was_moving:
		# The stop edge must always go out, or the server keeps walking us.
		send = true
	else:
		_idle_ticks += 1
		send = _idle_ticks >= IDLE_KEEPALIVE_TICKS

	if send:
		_idle_ticks = 0
		_last_sent_input = input
	return send
