extends SceneTree

## Enters an assembled dungeon against a live server, and comes back out.
##
## The vault and the nexus are maps; a dungeon is generated on the server
## from `dungeon-graph.json` the moment a portal to one is used, and the
## realm it becomes has no map id -- LoadMapPacket carries -1 there and the
## dungeon's own id in `dungeonId`. Nothing in the nexus leads to one, so the
## portal is spawned at our feet with the server's own /portal, which is
## admin-only; god mode keeps us alive among what spawns around the entrance.
##
##   godot --path . --resolution 1280x960 --script tests/visual/live_dungeon.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws] [portal]
##
## Exit codes: 0 in and out, 1 never got there, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
## Generation is CPU-heavy and runs on a worker; give a 200x200 dungeon time.
const GENERATE_TIMEOUT := 40.0
## Portal 5: the Inferno Cavern, dungeon 1, 200x200.
const PORTAL := 5

var _drive: LiveDriver
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws] [portal]")
		quit(2)
		return
	var portal := int(args[7]) if args.size() > 7 else PORTAL

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	_main = _drive.main
	var state: RealmState = _main.state
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return _main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % _main.client.state)
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return state.tiles.tile_count() > 300):
		push_error("the map never streamed in")
		quit(1)
		return
	await _drive.settle(1.0)

	if not await _drive.toggle_on("/admin", "Admin mode") or not await _drive.toggle_on("/godmode", "God mode"):
		quit(1)
		return
	quit(0 if await _spawn_portal(portal) and await _enter() and await _leave() else 1)


## The server puts the portal exactly where we stand, so it is in reach
## the moment it lands.
func _spawn_portal(portal: int) -> bool:
	var state: RealmState = _main.state
	var before: int = state.entities.portals.size()
	if await _drive.command("/portal %d" % portal, "spawned") == "":
		return false
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return state.entities.portals.size() > before):
		push_error("the server said it spawned a portal and none arrived")
		return false
	await _drive.settle(0.5)
	_drive.capture("dungeon_portal")
	return true


func _enter() -> bool:
	var state: RealmState = _main.state
	var realm: int = state.tiles.realm_id
	_main.portals.use_nearest()
	if not state.transition_pending:
		push_error("the spawned portal was not in reach")
		return false
	var arrived := await _drive.wait(GENERATE_TIMEOUT, func() -> bool:
		return state.tiles.realm_id != realm and state.tiles.tile_count() > 0)
	if not arrived:
		push_error("the server never sent the dungeon (still realm %d)" % realm)
		return false
	await _drive.settle(3.0)
	print("realm %d -> realm %d: map %d dungeon %d, %dx%d, %d tiles, zone '%s', %d enemies, corrections %d" % [
		realm, state.tiles.realm_id, state.tiles.map_id, state.tiles.dungeon_id,
		state.tiles.width, state.tiles.height, state.tiles.tile_count(), state.transition.zone,
		state.entities.enemies.size(), state.movement.corrections])
	_drive.capture("dungeon_inside")
	if state.tiles.dungeon_id < 0:
		push_error("arrived somewhere, but not in a dungeon: map %d" % state.tiles.map_id)
		return false
	return true


## The way out that needs no exit portal: the nexus key.
func _leave() -> bool:
	var state: RealmState = _main.state
	var realm: int = state.tiles.realm_id
	_main.portals.to_nexus()
	var back := await _drive.wait(LOAD_TIMEOUT, func() -> bool:
		return state.tiles.realm_id != realm and state.tiles.tile_count() > 0)
	if not back:
		push_error("never got back to the nexus from dungeon realm %d" % realm)
		return false
	await _drive.settle(2.0)
	print("back in realm %d map %d dungeon %d, corrections %d" % [
		state.tiles.realm_id, state.tiles.map_id, state.tiles.dungeon_id, state.movement.corrections])
	_drive.capture("dungeon_nexus")
	return state.tiles.dungeon_id < 0
