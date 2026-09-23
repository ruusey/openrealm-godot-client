extends SceneTree

## Signs in through the real login screen, makes a character of a class and
## enters the realm on it with "Create & play".
##
## The unit suite proves what the button sends; this proves the data service
## answers with the account, that the new character is the one handed to the
## game server, and that the game server lets it in.
##
##   godot --path . --script tests/visual/live_create.gd -- \
##     <host> <data_port> <email> <password> <class_id> <out_dir> [ws]
##
## Every run adds a character to the account; the service caps a normal
## account at 15 living ones and a demo account at 1.
##
## Exit codes: 0 in the realm on the new character, 1 it never got there,
## 2 bad arguments.

const SIGN_IN_TIMEOUT := 20.0
const LOGIN_TIMEOUT := 20.0

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <class_id> <out_dir> [ws]")
		quit(2)
		return

	_drive = LiveDriver.new(self, args[5])
	var config := LiveDriver.config_from(args)
	config.character_uuid = ""
	config.autoconnect = false
	await _drive.boot(config)
	var main := _drive.main
	var login: LoginScreen = main.screens.login

	await login._on_login_pressed()
	if not login._stage.creator.visible:
		push_error("sign-in did not reach the class grid: %s" % login._status.text)
		quit(1)
		return
	var before: int = login._stage.picker.alive_count()
	var class_id := int(args[4])
	if not login._stage.creator.options.has(class_id):
		push_error("no class %d in the content; have %s" % [class_id, login._stage.creator.options.keys()])
		quit(1)
		return
	await _drive.settle(0.3)
	_drive.capture("create_grid")

	login._stage.creator.options[class_id].button_pressed = true
	await login._stage.creator._create(true)
	if login._stage.picker.alive_count() != before + 1:
		push_error("the account did not gain a character: %s" % login._status.text)
		quit(1)
		return
	var made: Dictionary = login._stage.picker.selected()
	print("created %s (%s); now %d living" % [made.get("characterUuid", ""),
		main.game_data.classes_art.display_name(class_id), login._stage.picker.alive_count()])

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game on the new character; client state = %d" % main.client.state)
		quit(1)
		return
	if main.state.local.class_id != class_id:
		push_error("in the realm as class %d, not %d" % [main.state.local.class_id, class_id])
		quit(1)
		return
	await _drive.settle(1.5)
	_drive.capture("create_in_realm")
	print("in the realm as playerId=%d class=%d" % [main.state.local.id, main.state.local.class_id])
	quit(0)
