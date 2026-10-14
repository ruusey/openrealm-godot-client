class_name PacketClock
extends RefCounted

## When a movement packet was sent, recovered from when we happened to read it.
##
## Remote entities are interpolated between snapshots stamped with their arrival
## time, but a packet is only read at the start of a frame: at 60fps an arrival
## is late by anything up to 16ms, on top of network jitter, so snapshots the
## server sent 31.25ms apart land 20 or 45ms apart and the interpolated walk
## speeds up and slows down every packet. The server only sends on its 64Hz tick
## grid (movement on every second tick), so each arrival is snapped to the grid
## point nearest the expected arrival, and the grid's phase follows the mean
## delay. Packets read in the same frame share a stamp, as they did before.

const GRID_MS := 1000.0 / 32.0
## How fast the phase follows the measured delay, per packet.
const FOLLOW := 0.08
## A gap this long (a stall, a hidden tab, a realm change) restarts the estimate.
const RESET_MS := 1000.0

var _phase := 0.0
var _last_arrival := -INF


## The send-grid time for a packet read at `arrival_ms`, never ahead of the read
## by more than half a grid step.
func stamp(arrival_ms: float) -> float:
	if arrival_ms - _last_arrival > RESET_MS:
		_phase = arrival_ms
	_last_arrival = arrival_ms
	var steps := roundf((arrival_ms - _phase) / GRID_MS)
	var on_grid := _phase + steps * GRID_MS
	var residual := arrival_ms - on_grid
	_phase += residual * FOLLOW
	return on_grid
