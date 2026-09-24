extends SceneTree

## Walks in the nexus, stops, and watches the blue flame against the ground.
##
##   godot --path . --resolution 1280x720 --script tests/visual/live_stop_jump.gd -- \
##     <host> <data_port> <email> <password> <character_uuid>
##
## After a stop the camera creeps on for half a second while the last
## correction's offset unwinds. Bodies are snapped to whole screen pixels
## and the ground is drawn where the canvas puts it, so a camera off the
## pixel grid slid the ground a fraction a frame under the Healer (enemy 67,
## the flame at the nexus centre) until it jumped a whole pixel -- 5 to 15
## times in six stops. This walks six ways, stops, and for each frame after
## compares where the flame is drawn with where the world's origin is: the
## two must keep their distance. The pixel-grid camera (PixelSnap.camera)
## is what holds it.
##
## Windowed only. Exit 0 the flame held every frame, 1 it slipped, 2 bad args.

const LOGIN_TIMEOUT := 20.0
const HEALER := 67
const WATCH_FRAMES := 60
const WALK := 0.45
const LEGS := [["move_right"], ["move_left"], ["move_down"], ["move_up"],
	["move_right", "move_down"], ["move_left", "move_up"]]
## Anything past float noise is a slip; a real one is most of a pixel.
const SLIP_PX := 0.05


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("usage: <host> <data_port> <email> <password> <character>")
		quit(2)
		return
	var config := ClientConfig.new()
	config.host = args[0]
	config.data_port = int(args[1])
	config.email = args[2]
	config.password = args[3]
	config.character_uuid = args[4]
	config.autoconnect = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.config = config
	root.add_child(main)
	await process_frame

	var deadline := Time.get_ticks_msec() + int(LOGIN_TIMEOUT * 1000.0)
	while not main.client.is_in_game():
		if Time.get_ticks_msec() > deadline:
			push_error("never reached in-game")
			quit(1)
			return
		await process_frame
	await _settle(1.5)

	var slips := 0
	var creeping := 0
	for leg in LEGS:
		for action in leg:
			Input.action_press(action)
		await _settle(WALK)
		for action in leg:
			Input.action_release(action)
		var watched := await _watch(main)
		if watched.is_empty():
			push_error("no Healer in view")
			quit(1)
			return
		print("[stop] %-20s camera moved on %2d frames, the flame slipped on %d%s" % [
			"-".join(leg), watched["creep"], watched["slips"].size(),
			"" if watched["slips"].is_empty() else ": " + ", ".join(watched["slips"])])
		slips += watched["slips"].size()
		creeping += watched["creep"]
	print("[stop] %d frames of camera creep after six stops, %d slips" % [creeping, slips])
	quit(1 if slips > 0 else 0)


## The frames after a stop: how many moved the camera, and on which the
## flame's distance from the world's origin changed.
func _watch(main: Node) -> Dictionary:
	var creep := 0
	var slips := PackedStringArray()
	var last_camera := Vector2.INF
	var last_gap := Vector2.INF
	for frame in WATCH_FRAMES:
		await process_frame
		var to_screen: Transform2D = main.get_viewport().get_canvas_transform()
		var flame: Variant = _flame(main)
		if flame == null:
			return {}
		var gap: Vector2 = to_screen * PixelSnap.world(main._world.entities, flame) - to_screen.origin
		var camera: Vector2 = main._camera.position
		if last_camera != Vector2.INF and camera != last_camera:
			creep += 1
		if last_gap != Vector2.INF and gap.distance_to(last_gap) > SLIP_PX:
			slips.append("f%d %+.2f,%+.2f px" % [frame, gap.x - last_gap.x, gap.y - last_gap.y])
		last_camera = camera
		last_gap = gap
	return {"creep": creep, "slips": slips}


func _flame(main: Node) -> Variant:
	for id in main.state.entities.enemies:
		var enemy: Dictionary = main.state.entities.enemies[id]
		if int(enemy.get("enemy_id", -1)) == HEALER:
			return main.state.entities.render_position(enemy)
	return null


func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
