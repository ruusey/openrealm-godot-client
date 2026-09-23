extends SceneTree

## Moves a real item against a live server, and puts it back.
##
## The unit suite proves what the client sends; this proves the server takes
## it. It waits for the first UpdatePacket, unequips whatever is in the weapon
## slot into the first free backpack slot, waits for the UpdatePacket that
## answers, then moves it back -- so the character is left as it was found.
##
##   godot --path . --script tests/visual/live_inventory.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws]
##
## Exit codes: 0 moved out and back, 1 the server never agreed, 2 bad
## arguments, 3 nothing equipped to move.

const LOGIN_TIMEOUT := 20.0
const UPDATE_TIMEOUT := 10.0

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
	var bag: Inventory = main.state.local.inventory

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	if not await _drive.wait(UPDATE_TIMEOUT, func() -> bool: return bag.version > 1):
		push_error("no UpdatePacket ever arrived")
		quit(1)
		return
	await _drive.settle(1.0)

	var weapon := bag.item_at(0)
	if not Inventory.holds(weapon):
		push_error("nothing in the weapon slot to move")
		quit(3)
		return
	var free := bag.first_empty_backpack()
	print("moving %s from slot 0 to slot %d" % [weapon.get("name", "?"), free])
	_drive.capture("inventory_before")

	quit(0 if await _move(0, free) and await _move(free, 0) else 1)


## One move, and the UpdatePacket that confirms it landed where asked.
func _move(from: int, to: int) -> bool:
	var bag: Inventory = _drive.main.state.local.inventory
	var item_id := int(bag.item_at(from).get("itemId", -1))
	if not _drive.main.inventory_actions.move(from, to):
		push_error("the client refused to move %d -> %d" % [from, to])
		return false
	var landed := await _drive.wait(UPDATE_TIMEOUT, func() -> bool:
		return int(bag.item_at(to).get("itemId", -1)) == item_id and bag.item_at(from).is_empty())
	if not landed:
		push_error("the server never moved item %d from %d to %d" % [item_id, from, to])
		return false
	await _drive.settle(0.5)
	print("item %d now in slot %d" % [item_id, to])
	_drive.capture("inventory_slot_%d" % to)
	return true
