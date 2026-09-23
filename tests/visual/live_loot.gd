extends SceneTree

## The loot bag preview against a live server: a real bag, its grid, from
## underfoot and from across the floor, and the switch that hides it.
##
## Turns admin on, drops seven of an item with the server's own `/item`
## (a bag lands within a tile and a half of the player), waits for the bag
## and its grid, then walks three tiles off -- out of pickup reach, where
## the bag panel has nothing -- and checks the grid is still there, as the
## web client's is. Last it turns the switch off and back on. A screenshot
## at each step.
##
##   godot --path . --script tests/visual/live_loot.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws]
##
## Exit codes: 0 all seen, 1 something was not, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const DROP_TIMEOUT := 8.0
const ITEM := 49   # Goblin Sword: not stackable, so seven are seven cells
const COUNT := 7
const AWAY_PX := 96.0

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws]")
		quit(2)
		return
	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	quit(0 if await _run() else 1)


func _run() -> bool:
	var main := _drive.main
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		return false
	await _drive.settle(1.5)
	if not await _drive.toggle_on("/admin", "Admin mode"):
		return false
	var before: Array = main.state.entities.containers.keys()
	main.chat_actions.say("/item %d %d" % [ITEM, COUNT])
	var bag_id := [-1]
	if not await _drive.wait(DROP_TIMEOUT, func() -> bool:
		bag_id[0] = _new_bag(main.state.entities, before)
		return bag_id[0] != -1):
		push_error("no bag of %d appeared" % COUNT)
		return false
	var overlay: EntityOverlay = main.screens.overlay
	await _drive.settle(0.5)
	if not _check(overlay, bag_id[0], "near"):
		return false
	_drive.capture("loot_near")

	var start: Vector2 = main.state.local.position
	if not await _drive.walk_to(start + Vector2(AWAY_PX, 0.0), 6.0, 8.0):
		push_error("could not walk away from the bag")
		return false
	await _drive.settle(0.5)
	if not main.inventory_actions.loot_items().is_empty():
		push_error("still within pickup reach -- not the case under test")
		return false
	if not _check(overlay, bag_id[0], "away"):
		return false
	_drive.capture("loot_away")

	var settings: GameSettings = main.state.settings
	settings.set_on("loot_preview", false)
	await _drive.settle(0.3)
	var hidden := overlay.previews == 0
	_drive.capture("loot_off")
	settings.set_on("loot_preview", true)
	print("switch off: %d grids" % overlay.previews)
	return hidden


func _new_bag(entities: EntityRegistry, before: Array) -> int:
	for id in entities.containers:
		if id not in before and LootPreview.shown_items(entities.containers[id].get("items", [])).size() == COUNT:
			return id
	return -1


func _check(overlay: EntityOverlay, id: int, where: String) -> bool:
	var grid := overlay._loot.preview(id)
	if grid == null or grid.icon_count() != COUNT:
		push_error("%s: no grid of %d under bag %d (%s)" % [where, COUNT, id,
			"none" if grid == null else str(grid.icon_count())])
		return false
	print("%s: bag %d shows %d icons at %s" % [where, id, grid.icon_count(), grid.position])
	return true
