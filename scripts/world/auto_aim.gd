class_name AutoAim
extends RefCounted

## Which enemy the phone's Attack locks on to: the nearest in range by the
## distance between centres, skipping anything BLIND has hidden, since a
## target the player cannot see is not one to find. It feeds the lock-on
## ring (EntityRegistry.lock_on) and is where the phone's shots and casts
## go. Nothing here reaches the wire.

const RANGE_PX := 10.0 * GameConstants.TILE_SIZE


## The id of the nearest enemy within `range_px` of `from`, or -1.
static func nearest(state: RealmState, from: Vector2, range_px := RANGE_PX) -> int:
	var found := -1
	var closest := range_px
	for id in state.entities.enemies:
		var body := _body(state, state.entities.enemies[id])
		if body.size == Vector2.ZERO:
			continue
		var distance := body.get_center().distance_to(from)
		if distance <= closest:
			closest = distance
			found = id
	return found


## The centre of the nearest enemy within `range_px` of `from`, or INF.
static func target(state: RealmState, from: Vector2, range_px := RANGE_PX) -> Vector2:
	var id := nearest(state, from, range_px)
	return Vector2.INF if id == -1 else _body(state, state.entities.enemies[id]).get_center()


## Where the enemy is drawn, or an empty rect when BLIND hides it.
static func _body(state: RealmState, enemy: Dictionary) -> Rect2:
	var top_left := state.entities.render_position(enemy)
	var size := float(enemy.get("size", 16))
	if Blind.hides(state, top_left, size):
		return Rect2()
	return Rect2(top_left, Vector2.ONE * size)
