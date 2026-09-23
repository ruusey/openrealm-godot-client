class_name WalkCycle
extends RefCounted

## Walk animation cadence, advanced by distance travelled rather than by the
## wall clock.
##
## A frame swaps every PX_PER_FRAME pixels of actual movement, so the gait
## scales with speed: brisk at a sprint, proportionally slower when a slow
## tile cuts the step. A fixed-interval timer instead gives a high-SPD class
## the same footfalls as a slow one, which reads as skating.
##
## PX_PER_FRAME must match the web client's WALK_PX_PER_FRAME (and, per its
## comment, the native client's Entity.WALK_PX_PER_FRAME) or the same
## character walks to a different rhythm in each client.

const PX_PER_FRAME := 28.0
## Below this (px/tick) the entity counts as standing still, matching the
## `pace > 0.1f` test in both reference clients.
const MOVING_EPSILON := 0.1

var frame := 0
var distance := 0.0


## `pace` is the applied pixels-per-tick -- after the slow-tile divisor, so a
## slow tile stretches the gait automatically. Both reference clients
## accumulate `pace * 64 * dt` and treat anything at or under MOVING_EPSILON
## as standing still; matching that literally is the point, since the walk
## rhythm is meant to look identical in all three.
##
## Note this is velocity, not distance actually covered: walking into a wall
## keeps the legs cycling, which is what the other clients do.
func advance(pace: float, delta: float) -> void:
	if pace <= MOVING_EPSILON:
		reset()
		return
	distance += pace * GameConstants.TICK_RATE * delta
	while distance >= PX_PER_FRAME:
		distance -= PX_PER_FRAME
		frame += 1


## Standing still returns to the first frame, so a stopped character settles
## into its idle pose rather than freezing mid-stride.
func reset() -> void:
	frame = 0
	distance = 0.0
