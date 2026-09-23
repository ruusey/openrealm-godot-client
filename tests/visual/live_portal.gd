extends SceneTree

## Drives a real session through a realm transition and screenshots both sides.
##
## The unit suite proves what the client sends; this proves the server agrees.
## It walks to a portal under real prediction, uses it, waits for the realm to
## change underneath, then takes the way out that has no portal in it.
##
##   godot --path . --script tests/visual/live_portal.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws]
##
## Exit codes: 0 transited, 1 never got there, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const WALK_TIMEOUT := 45.0
const LOAD_TIMEOUT := 20.0
## Stop short of the client's own reach, so arrival is unambiguous.
const ARRIVE_PX := PortalInput.REACH_PX - 16.0

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws]")
		quit(2)
		return

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main := _drive.main

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	print("logged in as playerId=%d" % main.state.local.id)

	if not await _drive.wait(LOAD_TIMEOUT,
			func() -> bool: return not main.state.entities.portals.is_empty()):
		push_error("no portals ever arrived in realm %d" % main.state.tiles.realm_id)
		quit(1)
		return
	await _drive.settle(1.0)

	quit(0 if await _walk_there() and await _use_it() and await _go_back() else 1)


func _walk_there() -> bool:
	var target := _closest_portal()
	print("walking from %s to a portal at %s" % [_drive.main.state.local.position, target])
	if not await _drive.walk_to(target, ARRIVE_PX, WALK_TIMEOUT):
		push_error("never reached the portal; stopped %.0f px away"
			% _drive.distance_to(target))
		return false
	await _drive.settle(0.5)
	_drive.capture("portal_before")
	return true


func _use_it() -> bool:
	var tiles: TileMapState = _drive.main.state.tiles
	var realm := tiles.realm_id
	var map := tiles.map_id
	_drive.main.portals.use_nearest()
	if not _drive.main.state.transition_pending:
		push_error("nothing was in reach after all")
		return false
	if not await _arrived_somewhere_else(realm):
		push_error("the server never sent another realm (still realm %d)" % realm)
		return false
	print("realm %d map %d -> realm %d map %d" % [realm, map, tiles.realm_id, tiles.map_id])
	_drive.capture("portal_after")
	return true


## And back out, which is the path with no portal in it.
func _go_back() -> bool:
	var state: RealmState = _drive.main.state
	var realm: int = state.tiles.realm_id
	_drive.main.portals.to_nexus()
	if not await _arrived_somewhere_else(realm):
		push_error("never got back to the nexus from realm %d" % realm)
		return false
	print("back in realm %d map %d, %d portals, corrections %d" % [
		state.tiles.realm_id, state.tiles.map_id, state.entities.portals.size(),
		state.movement.corrections])
	_drive.capture("portal_nexus")
	return true


func _arrived_somewhere_else(realm: int) -> bool:
	var state: RealmState = _drive.main.state
	var moved := await _drive.wait(LOAD_TIMEOUT, func() -> bool:
		return state.tiles.realm_id != realm and state.tiles.tile_count() > 0)
	await _drive.settle(2.0)
	return moved


func _closest_portal() -> Vector2:
	var state: RealmState = _drive.main.state
	var found := Vector2.ZERO
	var closest := INF
	for id in state.entities.portals:
		var at: Vector2 = state.entities.render_position(state.entities.portals[id])
		var distance := state.local.position.distance_to(at)
		if distance < closest:
			closest = distance
			found = at
	return found
