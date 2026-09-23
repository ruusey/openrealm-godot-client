class_name Heartbeat
extends RefCounted

## Fixed-interval keepalive timer.
##
## The server reaps idle pre-login sockets, and any inbound packet refreshes a
## session's activity timestamp, so a periodic heartbeat is what keeps a quiet
## connection alive.

var interval: float


func _init(seconds := 2.0) -> void:
	interval = seconds

var _accumulator := 0.0


## Advances the timer, returning true on the frames a heartbeat is due.
func tick(delta: float) -> bool:
	_accumulator += delta
	if _accumulator < interval:
		return false
	_accumulator = 0.0
	return true


func reset() -> void:
	_accumulator = 0.0
