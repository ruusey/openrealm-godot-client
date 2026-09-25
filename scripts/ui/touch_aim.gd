class_name TouchAim
extends RefCounted

## Where the phone's shots and casts go: the enemy AutoAim finds, or with
## none in range a point REACH_PX the way the player last walked. Each call
## also sets the lock-on ring on that enemy, so the ring is always where
## the next shot will land.

const REACH_PX := 5.0 * GameConstants.TILE_SIZE

var _last_move := Vector2.DOWN


func target(state: RealmState) -> Vector2:
	var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if moving != Vector2.ZERO:
		_last_move = moving.normalized()
	var centre := state.local.render_centre()
	lock(state)
	var enemy := AutoAim.target(state, centre)
	return enemy if enemy != Vector2.INF else centre + _last_move * REACH_PX


## The ring on the nearest enemy, every frame whether or not anything fires.
static func lock(state: RealmState) -> void:
	state.entities.lock_on = AutoAim.nearest(state, state.local.render_centre())
