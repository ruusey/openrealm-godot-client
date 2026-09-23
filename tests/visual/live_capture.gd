extends SceneTree

## Boots the real client against a live server and screenshots the session.
##
## This runs the actual main scene, so it exercises the whole stack --
## handshake, world stream, prediction, rendering -- rather than a synthetic
## scenario. Must run windowed; the headless driver cannot produce pixels.
##
##   godot --path . --script tests/visual/live_capture.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out.png> \
##     [seconds] [ws]
##
## A trailing "ws" runs it the way a web export has to: the server's WebSocket
## listener instead of its TCP one, and content fetched from the data service
## instead of read off disk. Neither is otherwise reachable without a browser.

const LOGIN_TIMEOUT := 20.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out.png> [seconds]")
		quit(2)
		return

	var config := ClientConfig.new()
	config.host = args[0]
	config.data_port = int(args[1])
	config.email = args[2]
	config.password = args[3]
	config.character_uuid = args[4]
	config.autoconnect = true
	var output: String = args[5]
	var observe: float = float(args[6]) if args.size() > 6 else 3.0
	# "ws" is the browser's pair of choices: its transport and its content
	# source. Neither is reachable on the desktop without asking.
	config.websocket = args.size() > 7 and args[7] == "ws"
	config.content_http = config.websocket

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.config = config
	root.add_child(main)
	# At SceneTree._init the tree has not started, so _ready has not run yet
	# and main's children do not exist until the next frame.
	await process_frame

	var deadline := Time.get_ticks_msec() + int(LOGIN_TIMEOUT * 1000.0)
	while not main.client.is_in_game():
		if Time.get_ticks_msec() > deadline:
			push_error("never reached in-game; client state = %d" % main.client.state)
			quit(1)
			return
		await process_frame

	print("logged in as playerId=%d" % main.state.local.id)

	# Let the first-world burst land and a few frames render.
	var until := Time.get_ticks_msec() + int(observe * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture returned null -- run windowed, not --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	image.save_png(output)

	var counts: Dictionary = main._world.draw_stats
	print("captured %s | tiles=%d players=%d enemies=%d bullets=%d | rtt=%.0fms in=%dB/%dpkt" % [
		output, counts["tiles"], counts["players"], counts["enemies"], counts["bullets"],
		main.client.stats.rtt_ms, main.client.stats.bytes_in, main.client.stats.packets_in])
	quit(0)
