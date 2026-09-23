class_name LiveDriver
extends RefCounted

## Boots the real client against a live server and drives it like a player.
##
## The mechanics a live scenario needs and none of the scenario itself:
## booting the main scene, waiting on a condition with a deadline, walking
## somewhere under real prediction, and screenshotting what is on screen.

const DEADZONE_PX := 4.0
const WALK := ["move_left", "move_right", "move_up", "move_down"]
## How long a server command has to answer in the chat.
const REPLY_TIMEOUT := 8.0

var main: Node

var _tree: SceneTree
var _out: String


func _init(tree: SceneTree, out_dir: String) -> void:
	_tree = tree
	_out = out_dir


## Command-line order is the same one live_capture.gd takes.
static func config_from(args: PackedStringArray) -> ClientConfig:
	var config := ClientConfig.new()
	config.host = args[0]
	config.data_port = int(args[1])
	config.email = args[2]
	config.password = args[3]
	config.character_uuid = args[4]
	config.autoconnect = true
	# "ws" is the browser's pair of choices: its transport and its content
	# source, neither reachable on the desktop without asking.
	config.websocket = args.size() > 6 and args[6] == "ws"
	config.content_http = config.websocket
	return config


func boot(config: ClientConfig) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.config = config
	_tree.root.add_child(main)
	# At SceneTree._init the tree has not started, so main's children do not
	# exist until the next frame.
	await _tree.process_frame


func wait(seconds: float, done: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await _tree.process_frame
	return true


func settle(seconds: float) -> void:
	await wait(seconds, func() -> bool: return false)


## Walks with held movement actions, the server acking as it goes, rather
## than teleporting the player somewhere it has never been.
func walk_to(target: Vector2, arrive_px: float, timeout: float) -> bool:
	var arrived := await wait(timeout, func() -> bool:
		_steer(target)
		return distance_to(target) < arrive_px)
	halt()
	return arrived


## Steering for a caller that drives its own loop -- walk_to owns the whole
## wait, which a fight cannot give it.
func steer_to(target: Vector2) -> void:
	_steer(target)


func halt() -> void:
	for action in WALK:
		Input.action_release(action)


func distance_to(target: Vector2) -> float:
	var position: Vector2 = main.state.local.position
	return position.distance_to(target)


func capture(name: String) -> void:
	var image := _tree.root.get_texture().get_image()
	if image == null:
		push_error("capture returned null -- run windowed, not --headless")
		return
	var path := "%s/%s.png" % [_out, name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	image.save_png(path)
	print("captured %s" % path)


## A toggle the server answers "<what> ON" or "<what> OFF": sent once, and
## once more if it was on already and the first press turned it off.
func toggle_on(line: String, what: String) -> bool:
	for attempt in 2:
		var reply := await command(line, what)
		if reply == "":
			return false
		if reply.contains("%s ON" % what):
			return true
	push_error("%s never came on" % what)
	return false


## Sends a chat command and returns the SYSTEM line that answers it, or ""
## after REPLY_TIMEOUT. `expect` is the part of the line to wait for; the
## whole line is returned so a toggle can read ON or OFF off it. A server
## error lands in the chat too, as "Error: ...", and is reported as such.
func command(line: String, expect: String) -> String:
	var chat: ChatLog = main.state.chat
	var seen: int = chat.lines.size()
	if not main.chat_actions.say(line):
		push_error("could not send %s" % line)
		return ""
	var answered := await wait(REPLY_TIMEOUT, func() -> bool:
		return answer(chat, seen, expect) != "" or answer(chat, seen, "Error:") != "")
	var reply := answer(chat, seen, expect)
	if not answered or reply == "":
		var tail: Array = chat.lines.slice(seen).map(func(entry: Dictionary) -> String: return ChatLog.rendered(entry))
		push_error("no answer to %s within %.0fs; the chat said: %s" % [line, REPLY_TIMEOUT, tail])
		return ""
	print("%s -> %s" % [line, reply])
	return reply


## The first SYSTEM line since `seen` that contains `expect`, or "".
static func answer(chat: ChatLog, seen: int, expect: String) -> String:
	for entry in chat.lines.slice(seen):
		if ChatLog.is_system(entry) and String(entry["message"]).contains(expect):
			return String(entry["message"])
	return ""


func _steer(target: Vector2) -> void:
	# main is a plain Node here, so its state is untyped -- name the type or
	# the inferred locals below cannot be resolved at parse time.
	var position: Vector2 = main.state.local.position
	var delta := target - position
	_axis("move_right", "move_left", delta.x)
	_axis("move_down", "move_up", delta.y)


func _axis(positive: String, negative: String, value: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if absf(value) > DEADZONE_PX:
		Input.action_press(positive if value > 0.0 else negative)
