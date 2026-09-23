class_name NetStats
extends RefCounted

## Traffic counters and the latency estimate behind them.
##
## For a client whose whole job is to agree with a server you cannot see, the
## numbers worth surfacing are the ones that expose disagreement: how much is
## flowing, what kind, and how long the round trip takes.

## Weight of each new RTT sample, so the displayed figure is readable rather
## than jittery.
const RTT_SMOOTHING := 0.2
## Cap on outstanding un-acked inputs tracked for RTT.
const MAX_PENDING := 256
## Ping as both references report it: the mean of the last ten heartbeat
## round trips, halved to one way; jitter is the standard deviation of those
## one-way samples. A trip that took no time or over five seconds is clock
## skew, not a measurement, and is dropped (the web client's bounds).
const PING_SAMPLES := 10
const MAX_PLAUSIBLE_RTT_MS := 5000

var bytes_in := 0
var bytes_out := 0
var packets_in := 0
var packets_out := 0
var unknown_packets := 0
var rtt_ms := 0.0
var ping_ms := 0
var jitter_ms := 0
var packet_counts := {}

var _pending := {}   # input seq -> send time (msec)
var _trips: Array[float] = []   # the last few heartbeat round trips


func record_sent(frame_size: int) -> void:
	bytes_out += frame_size
	packets_out += 1


func record_received(name: String, chunk_size := 0) -> void:
	bytes_in += chunk_size
	if name == "":
		unknown_packets += 1
		return
	packets_in += 1
	packet_counts[name] = packet_counts.get(name, 0) + 1


func expect_ack(seq: int, now_ms: int) -> void:
	_pending[seq] = now_ms
	if _pending.size() > MAX_PENDING:
		_pending.erase(_pending.keys()[0])


func record_ack(seq: int, now_ms: int) -> void:
	if not _pending.has(seq):
		return
	var sample := float(now_ms - _pending[seq])
	_pending.erase(seq)
	rtt_ms = sample if rtt_ms == 0.0 else lerpf(rtt_ms, sample, RTT_SMOOTHING)


## The server echoes a heartbeat with the timestamp we sent, so the gap is
## a round trip that does not depend on the player moving.
func record_heartbeat_echo(sent_ms: int, now_ms: int) -> void:
	var trip := now_ms - sent_ms
	if trip <= 0 or trip >= MAX_PLAUSIBLE_RTT_MS:
		return
	_trips.append(float(trip))
	if _trips.size() > PING_SAMPLES:
		_trips.pop_front()
	var mean := heartbeat_rtt_ms()
	ping_ms = roundi(mean / 2.0)
	var variance := 0.0
	for sample in _trips:
		variance += pow(sample / 2.0 - mean / 2.0, 2.0)
	jitter_ms = roundi(sqrt(variance / _trips.size()))


func heartbeat_rtt_ms() -> float:
	var total := 0.0
	for sample in _trips:
		total += sample
	return total / _trips.size() if not _trips.is_empty() else 0.0


## The round trip to plan around -- what the web client feeds its bullet
## fast-forward: the heartbeat's, which keeps measuring while the player
## stands still, or the movement acks' until the first echo lands.
func round_trip_ms() -> float:
	return heartbeat_rtt_ms() if not _trips.is_empty() else rtt_ms


func pending_count() -> int:
	return _pending.size()


func reset() -> void:
	_pending.clear()
	_trips.clear()
	ping_ms = 0
	jitter_ms = 0


## Packet mix, busiest first -- what the client is actually spending its
## bandwidth on.
func mix() -> String:
	var names := packet_counts.keys()
	names.sort_custom(func(a, b): return packet_counts[a] > packet_counts[b])
	var lines := PackedStringArray()
	for name in names:
		lines.append("  %-28s %d" % [name, packet_counts[name]])
	return "\n".join(lines)
