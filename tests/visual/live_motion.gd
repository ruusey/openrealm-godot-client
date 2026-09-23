extends SceneTree

## Walks under a chosen latency and judges the motion by the numbers.
##
##   godot --path . --script tests/visual/live_motion.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> [lag_ms] [jitter_ms]
##
## `lag_ms` is the one-way delay LagTransport adds to every byte, so the
## overlay's ping reads that figure; 0 is the real socket. Three legs -- a
## straight walk, a diagonal one, and a stop -- each traced by MotionTrace.
## The walking legs fail when the drawn motion is uneven: more than one
## frame in twenty that barely moved, a spread over half the mean, a jump
## past four means, or the sprite drawn off the camera's centre -- the
## frame's parts not agreeing. The baseline at 0, 50, 100 and 200ms is a spread
## of a tenth to a third of the mean, a largest frame of about twice it and
## a stall or two (the frame a one-step correction lands on); the bugs this
## exists to catch read as min 0.00 and max 15 -- what the history wipe and
## the wrong slow-tile sample looked like on a real connection.
##
## Exit: 0 even, 1 uneven or never in game, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LEG_FRAMES := 120
## Bounds on a walking leg, as multiples of the mean displacement.
const MAX_SPREAD := 0.5
const MAX_JUMP := 5.0
const MAX_STALLS := LEG_FRAMES / 20
## The local sprite is the camera's centre; half a pixel is the rounding.
const MAX_OFF_CENTRE := 0.51


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("usage: <host> <data_port> <email> <password> <character> [lag_ms] [jitter_ms]")
		quit(2)
		return
	var config := ClientConfig.new()
	config.host = args[0]
	config.data_port = int(args[1])
	config.email = args[2]
	config.password = args[3]
	config.character_uuid = args[4]
	config.lag_ms = float(args[5]) if args.size() > 5 else 0.0
	config.lag_jitter_ms = float(args[6]) if args.size() > 6 else 0.0
	config.autoconnect = true

	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.config = config
	root.add_child(main)
	await process_frame

	var deadline := Time.get_ticks_msec() + int(LOGIN_TIMEOUT * 1000.0)
	while not main.client.is_in_game():
		if Time.get_ticks_msec() > deadline:
			push_error("never reached in-game; client state = %d" % main.client.state)
			quit(1)
			return
		await process_frame
	await _settle(1.0)
	print("in game at lag %.0f ms (jitter %.0f), ping reads %d ms" % [config.lag_ms, config.lag_jitter_ms, main.client.stats.ping_ms])

	var uneven := 0
	for leg in [["straight", ["move_right"]], ["diagonal", ["move_right", "move_down"]]]:
		for action in leg[1]:
			Input.action_press(action)
		await _settle(0.3)
		var measured := await _trace(main)
		for action in leg[1]:
			Input.action_release(action)
		print("%-9s %s" % [leg[0], MotionTrace.summary(measured)])
		uneven += _judge(leg[0], measured)
		await _settle(0.6)
	# The stop, traced from the moment the key goes up: the server keeps
	# walking us until the stop packet lands, then the ack pulls us to where
	# it got to -- a jump that grows with the ping.
	Input.action_press("move_right")
	await _settle(0.5)
	main.trace.start(main.state.movement.corrections, LEG_FRAMES)
	Input.action_release("move_right")
	while main.trace.active():
		await process_frame
	var stopped: Dictionary = main.trace.last
	print("%-9s %s" % ["stopped", MotionTrace.summary(stopped)])

	print("ping %d ms   jitter %d ms   corrections in all %d" % [
		main.client.stats.ping_ms, main.client.stats.jitter_ms, main.state.movement.corrections])
	quit(1 if uneven > 0 else 0)


func _trace(main: Node) -> Dictionary:
	main.trace.start(main.state.movement.corrections, LEG_FRAMES)
	while main.trace.active():
		await process_frame
	return main.trace.last


func _judge(leg: String, m: Dictionary) -> int:
	var faults := PackedStringArray()
	if m.is_empty():
		faults.append("no frames")
	else:
		if m["stalls"] > MAX_STALLS:
			faults.append("%d frames that barely moved" % m["stalls"])
		if m["sd"] > MAX_SPREAD * m["mean"]:
			faults.append("spread %.2f over half the mean %.2f" % [m["sd"], m["mean"]])
		if m["max"] > MAX_JUMP * m["mean"]:
			faults.append("a jump of %.2f past five means" % m["max"])
		if m.get("off_centre", 0.0) > MAX_OFF_CENTRE:
			faults.append("the sprite drawn %.2f px off the camera" % m["off_centre"])
	if faults.is_empty():
		return 0
	push_error("%s leg is uneven: %s" % [leg, "; ".join(faults)])
	return 1


func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
