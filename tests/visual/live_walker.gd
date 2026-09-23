extends SceneTree

## A second player for the live remote-motion test to watch: signs in as a
## guest of its own -- the same account cannot be in the realm twice, the
## server closes the first session -- and paces left and right at the
## spawn until its time is up. Runs headless: it draws nothing, it only
## has to move.
##
##   godot --headless --path . --script tests/visual/live_walker.gd -- \
##     <host> <data_port> [seconds] [leg_seconds]
##
## The guest is registered through the data service on the first run and
## kept in user://walker_guest.cfg, with its one living character (a demo
## account is allowed one), so every run after is the same walker.
##
## Exit: 0 walked for its time, 1 could not sign in or never reached the
## realm, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const GUEST_PATH := "user://walker_guest.cfg"

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: <host> <data_port> [seconds] [leg_seconds]")
		quit(2)
		return
	var seconds := float(args[2]) if args.size() > 2 else 60.0
	var leg := float(args[3]) if args.size() > 3 else 1.5

	var service := DataService.new()
	service.base_url = "http://%s:%s" % [args[0], args[1]]
	root.add_child(service)
	# At SceneTree._init the tree has not started: the service's HTTP node
	# is not in it until the next frame.
	await process_frame
	var config := await _sign_in(service, args)
	if config == null:
		quit(1)
		return

	_drive = LiveDriver.new(self, "")
	await _drive.boot(config)
	var main := _drive.main
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("walker never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	await _drive.settle(1.0)
	print("[walker] in game as %s, pacing %.1fs legs for %.0fs" % [main.state.local.name, leg, seconds])

	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var right := true
	while Time.get_ticks_msec() < until:
		Input.action_press("move_right" if right else "move_left")
		await _drive.settle(leg)
		_drive.halt()
		right = not right
	print("[walker] done")
	quit(0)


## The guest's credentials and a living character of its own, made on the
## first run. Null, with the reason pushed, when the service refuses.
func _sign_in(service: DataService, args: PackedStringArray) -> ClientConfig:
	var guest := GuestAccount.new()
	guest.path = GUEST_PATH
	var got: Dictionary = await guest.obtain(service)
	if not got["success"]:
		push_error("walker could not obtain a guest: %s" % got["result"])
		return null
	if got["created"]:
		var login: Dictionary = await service.login(got["email"], got["password"])
		if not login["success"]:
			push_error("walker's new guest could not sign in: %s" % login["result"])
			return null
	var fetched: Dictionary = await service.fetch_characters()
	var living: Array = fetched["characters"].filter(func(c: Dictionary) -> bool: return c.get("deleted") == null)
	if living.is_empty():
		var made: Dictionary = await service.create_character(0)
		if not made["success"]:
			push_error("walker could not make a character: %s" % made["result"])
			return null
		living = (made["result"] as Array).filter(func(c: Dictionary) -> bool: return c.get("deleted") == null)
	if living.is_empty():
		push_error("walker has no living character")
		return null
	print("[walker] guest %s, character %s" % [got["email"], living[0]["characterUuid"]])

	var config := ClientConfig.new()
	config.host = args[0]
	config.data_port = int(args[1])
	config.email = got["email"]
	config.password = got["password"]
	config.character_uuid = str(living[0]["characterUuid"])
	config.autoconnect = true
	return config
