extends SceneTree

## Frames per second with a horde on screen.
##
## Logs in, turns admin mode and god mode on, spawns COUNT of ENEMY at the
## player's feet with the server's own /spawn, and samples the frames for a
## few seconds before and after -- wall time per frame, the process step,
## draw calls, what was drawn -- with vsync off, so the number is the
## client's throughput rather than the display's refresh. One line per
## phase, a screenshot of the horde, and a failure when the horde phase
## averages under FLOOR_FPS or any frame in it hitches past HITCH_MS.
##
##   godot --path . --resolution 1280x720 --script tests/visual/live_performance.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws] [enemy] [count]
##
## /admin, /godmode and /spawn are restricted to the moderator provision;
## the seeded ru@jrealm.com is a sys admin on a fresh stack (AGENTS.md says
## what to do on a stale one). Enemy 210 fires, so the horde phase is a
## hundred enemies and several hundred bullets; god mode is what keeps the
## player alive under them. The horde stays in the realm afterwards.
##
## Exit codes: 0 fast enough, 1 too slow or a command did not take, 2 bad
## arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
const SAMPLE_SECONDS := 4.0
const ENEMY := 210
const COUNT := 100
const FLOOR_FPS := 30.0
const HITCH_MS := 250.0

var _drive: LiveDriver
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws] [enemy] [count]")
		quit(2)
		return
	var enemy := int(args[7]) if args.size() > 7 else ENEMY
	var count := int(args[8]) if args.size() > 8 else COUNT

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
	# And no frame cap either: the project's 240 would otherwise be the
	# ceiling this measures, not the client's throughput.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("[perf] window %s at scale %.0f, vsync off, uncapped" % [root.size, root.content_scale_factor])

	var before: Dictionary = await FrameSampler.sample(self, SAMPLE_SECONDS, _main._world)
	print(FrameSampler.describe("before", before))

	if not await _drive.toggle_on("/admin", "Admin mode") or not await _drive.toggle_on("/godmode", "God mode"):
		quit(1)
		return
	var enemies_before: int = state.entities.enemies.size()
	if not await _drive.command("/spawn %d %d" % [enemy, count], "Spawned %d of enemy %d" % [count, enemy]):
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT,
			func() -> bool: return state.entities.enemies.size() >= enemies_before + count):
		push_error("the server said it spawned them but only %d of %d arrived" % [
			state.entities.enemies.size() - enemies_before, count])
		quit(1)
		return
	await _drive.settle(1.0)

	var horde: Dictionary = await FrameSampler.sample(self, SAMPLE_SECONDS, _main._world)
	print(FrameSampler.describe("horde of %d" % count, horde))
	_drive.capture("performance_horde")

	var slow: bool = horde["fps"] < FLOOR_FPS
	var hitched: bool = horde["max_ms"] > HITCH_MS
	if slow:
		push_error("%.1f fps with the horde is under the %.0f floor" % [horde["fps"], FLOOR_FPS])
	if hitched:
		push_error("a frame took %.0f ms with the horde, past the %.0f ms hitch limit" % [horde["max_ms"], HITCH_MS])
	quit(1 if slow or hitched else 0)

