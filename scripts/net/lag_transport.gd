class_name LagTransport
extends NetTransport

## A transport that holds every byte, both ways, for a configurable delay.
##
## The server on loopback answers in a millisecond, and a client tuned
## against that has never met the thing that makes movement hard: an ack
## that describes where you were an RTT ago. Wrapping the real transport
## in a delay line -- `one_way_ms` each way, so the overlay's ping reads
## that figure, plus a uniform jitter -- reproduces a distant server
## against the local one, and lets the live movement test walk at 100ms
## and fail on the numbers. Bytes never reorder: each parcel is due no
## earlier than the one before it, as a TCP stream would deliver them.

## What `/lag` in the chat steps through: 50ms at a time to 350, then back
## to none. One-way milliseconds, so the overlay's ping rises by as much.
const STEPS := [0.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0]
const STEP_JITTER_MS := 4.0

var inner: NetTransport
var one_way_ms := 0.0
var jitter_ms := 0.0
var clock: Callable = func() -> int: return Time.get_ticks_msec()
var rng := RandomNumberGenerator.new()

var _inbound: Array = []    # [due_ms, bytes], oldest first
var _outbound: Array = []
var _ready := PackedByteArray()
var _last_due := {"in": 0.0, "out": 0.0}


func _init(wrapped: NetTransport, delay_ms: float, jitter := 0.0, seed := 1) -> void:
	inner = wrapped
	one_way_ms = delay_ms
	jitter_ms = jitter
	rng.seed = seed


func connect_to_host(host: String, port: int) -> Error:
	_inbound.clear()
	_outbound.clear()
	_ready = PackedByteArray()
	return inner.connect_to_host(host, port)


## Moves what has arrived into the delay line and lets out what is due.
func poll() -> void:
	inner.poll()
	var now := float(clock.call())
	var waiting := inner.get_available_bytes()
	if waiting > 0:
		var read: Array = inner.get_data(waiting)
		if read[0] == OK and not read[1].is_empty():
			_inbound.append([_due("in", now), read[1]])
	while not _inbound.is_empty() and _inbound[0][0] <= now:
		_ready.append_array(_inbound.pop_front()[1])
	while not _outbound.is_empty() and _outbound[0][0] <= now:
		inner.put_data(_outbound.pop_front()[1])


func get_status() -> int:
	return inner.get_status()


func get_available_bytes() -> int:
	return _ready.size()


func get_data(count: int) -> Array:
	var take := mini(count, _ready.size())
	var bytes := _ready.slice(0, take)
	_ready = _ready.slice(take)
	return [OK, bytes]


func put_data(bytes: PackedByteArray) -> Error:
	# With no delay and nothing already waiting, straight through: a queued
	# write would otherwise sit until the next poll, a frame late.
	if inner.get_status() != StreamPeerTCP.STATUS_CONNECTED or (not delaying() and _outbound.is_empty()):
		return inner.put_data(bytes)
	_outbound.append([_due("out", float(clock.call())), bytes])
	return OK


func delaying() -> bool:
	return one_way_ms > 0.0 or jitter_ms > 0.0


## The next step up, wrapping round to none; from a delay the key did not
## set (a --lag of its own), the first step. Returns the new delay.
func cycle() -> float:
	var index := STEPS.find(one_way_ms)
	one_way_ms = STEPS[(index + 1) % STEPS.size()] if index >= 0 else STEPS[1]
	jitter_ms = STEP_JITTER_MS if one_way_ms > 0.0 else 0.0
	return one_way_ms


func disconnect_from_host() -> void:
	_inbound.clear()
	_outbound.clear()
	_ready = PackedByteArray()
	inner.disconnect_from_host()


func set_no_delay(enabled: bool) -> void:
	inner.set_no_delay(enabled)


func in_flight() -> int:
	return _inbound.size() + _outbound.size()


func _due(direction: String, now: float) -> float:
	var due := now + one_way_ms + rng.randf_range(-jitter_ms, jitter_ms)
	due = maxf(due, _last_due[direction])
	_last_due[direction] = due
	return due
