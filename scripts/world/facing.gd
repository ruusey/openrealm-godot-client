class_name Facing
extends RefCounted

## Which clip an entity is drawn with, from the direction it is moving.
##
## One rule for every player, local or remote: both reference clients derive
## it from velocity rather than tracking it per entity kind. The sheet has no
## left-facing clip, so leftward movement is the side clip mirrored.
##
## A standing entity keeps whatever it last faced, so a stopped character
## settles rather than snapping back to front.
##
## The native client adds hysteresis before switching axis, which stops the
## clip flickering when |dx| and |dy| are close; the web client uses this
## plain comparison, and so do we.

const MOVING_EPSILON := 0.000001


static func of(direction: Vector2, previous := "front") -> String:
	if direction.length_squared() <= MOVING_EPSILON:
		return previous
	if absf(direction.x) > absf(direction.y):
		return "side"
	return "front" if direction.y > 0.0 else "back"


## Whether a side-facing clip is mirrored. Only horizontal movement changes
## it, so walking up after walking left stays mirrored.
static func mirrored(direction: Vector2, previous := false) -> bool:
	if absf(direction.x) <= absf(direction.y):
		return previous
	return direction.x < 0.0
