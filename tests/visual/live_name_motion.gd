extends SceneTree

## Walks the diagonals in a realm and watches the name under the player.
##
##   godot --path . --resolution 1280x720 --script tests/visual/live_name_motion.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ui_scale] [world_zoom]
##
## The scales are Options' two (0 automatic): a browser's are 2 and 1.25.
##
## The name is a Label on EntityOverlay, placed each frame from the
## player's position; the body is drawn by the world, snapped to the same
## pixel grid. Drawn together, the two keep one distance on every frame. On
## the moment each frame is drawn this reads both and counts the frames
## where that distance changed -- a name that wobbles against its body --
## and the frames where the body itself moved on screen: the camera follows
## it, so it holds one pixel. At a browser's scales (2 and 1.25) the pair
## hopped between two pixels on 140 to 167 frames of 180, which on a
## diagonal reads as a blurred name, until PixelSnap.camera took the body
## as its anchor.
##
## Windowed only. Exit 0 both held, 1 either moved or it never got there,
## 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
const LEG_SECONDS := 1.5
const LEGS := [["move_right", "move_down"], ["move_left", "move_up"],
	["move_left", "move_down"], ["move_right", "move_up"]]

var _main: Node
var _samples: Array = []
var _recording := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir>")
		quit(2)
		return
	var drive := LiveDriver.new(self, args[5])
	await drive.boot(LiveDriver.config_from(args))
	_main = drive.main
	if not await drive.wait(LOGIN_TIMEOUT, func() -> bool: return _main.client.is_in_game()):
		push_error("never reached in-game")
		quit(1)
		return
	if not await drive.toggle_on("/admin", "Admin mode") or not await drive.toggle_on("/godmode", "God mode"):
		quit(1)
		return
	if not await LiveRealm.leave_nexus(drive):
		quit(1)
		return
	if not await drive.wait(LOAD_TIMEOUT, func() -> bool: return _main.state.tiles.tile_count() > 300):
		push_error("the realm never streamed in")
		quit(1)
		return
	if args.size() > 7:
		_main.state.settings.set_scale("ui_scale", float(args[6]))
		_main.state.settings.set_scale("world_zoom", float(args[7]))
	await drive.settle(1.0)
	if args.size() > 7 and float(args[6]) > 0.0 and not is_equal_approx(root.content_scale_factor, float(args[6])):
		push_error("the UI scale did not take: %.2f" % root.content_scale_factor)
		quit(1)
		return
	print("[name] realm %d, window %s, canvas %.2fx, camera zoom %s" % [_main.state.tiles.realm_id,
		root.size, root.content_scale_factor, _main._camera.zoom])
	RenderingServer.frame_pre_draw.connect(_sample)

	var wobbles := 0
	for leg in LEGS:
		for action in leg:
			Input.action_press(action)
		await drive.settle(0.3)
		_samples.clear()
		_recording = true
		await drive.settle(LEG_SECONDS)
		_recording = false
		for action in leg:
			Input.action_release(action)
		wobbles += _report("-".join(leg))
		await drive.settle(0.4)
	quit(1 if wobbles > 0 else 0)


## The moment before the frame is drawn: where the body and the name are.
func _sample() -> void:
	if not _recording:
		return
	var local: LocalPlayer = _main.state.local
	var tag: EntityTag = _main.screens.overlay._tags._live.get(["player", local.id])
	if tag == null or not tag.visible:
		return
	var to_screen: Transform2D = _main.get_viewport().get_canvas_transform()
	var body: Vector2 = to_screen * PixelSnap.world(_main._world.entities, local.render_position())
	var name: Vector2 = tag.position + tag._name.position
	# To a hundredth: a realm's coordinates carry float noise past that.
	_samples.append({"body": body.snapped(Vector2(0.01, 0.01)), "name": name.snapped(Vector2(0.01, 0.01))})


func _report(leg: String) -> int:
	var gaps := {}
	var changes := PackedStringArray()
	var last := Vector2.INF
	for i in _samples.size():
		var s: Dictionary = _samples[i]
		var gap: Vector2 = s["name"] - s["body"]
		gaps[gap] = int(gaps.get(gap, 0)) + 1
		if last != Vector2.INF and gap.distance_to(last) > 0.01 and changes.size() < 12:
			changes.append("f%d %+.2f,%+.2f" % [i, gap.x - last.x, gap.y - last.y])
		last = gap
	var changed := 0
	for i in range(1, _samples.size()):
		var a: Vector2 = _samples[i - 1]["name"] - _samples[i - 1]["body"]
		var b: Vector2 = _samples[i]["name"] - _samples[i]["body"]
		if a.distance_to(b) > 0.01:
			changed += 1
	var spots := {}
	var hops := 0
	for i in _samples.size():
		spots[_samples[i]["body"]] = int(spots.get(_samples[i]["body"], 0)) + 1
		if i > 0 and _samples[i]["body"] != _samples[i - 1]["body"]:
			hops += 1
	print("[name] %-22s %d frames, name moved against the body on %d, %d distinct gaps %s%s" % [
		leg, _samples.size(), changed, gaps.size(), gaps,
		"" if changes.is_empty() else "\n         " + ", ".join(changes)])
	print("[name] %-22s the body hopped on screen on %d frames, over %d spots %s" % [leg, hops, spots.size(), spots])
	return changed + hops
