extends SceneTree

## How evenly the OTHER things on screen move under a chosen latency:
## enemies, and any other player in view.
##
##   godot --path . --resolution 800x600 --script tests/visual/live_remote_motion.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [lag_ms] [jitter_ms] [count]
##
## `lag_ms` is LagTransport's one-way delay on every byte, so the server's
## corrections arrive as late as they would from a distant server. It
## turns admin and god mode on, spawns COUNT of enemy 210 at the player's
## feet with the server's own /spawn, and for FRAMES frames records how far
## every moving enemy in view -- and every other player, which is what
## tests/visual/live_walker.gd is for -- was drawn from where it was the
## frame before. Then the live movement test's judgement: a frame that
## barely moved is a stall, and motion is uneven with more than one stall
## in twenty, a spread over the bound, or a jump past five means. Before
## the sampler searched its whole buffer, a peer read as three stalls in
## four and an enemy as a jump of thirty means. Displacements are scaled
## to a 60Hz frame by each frame's real length, so the engine's own pacing
## is not what is judged.
##
## Enemies here have minds of their own -- they close in, slow near their
## target, stop to fire, start again -- so a frame counts only while the
## server's last two words about the enemy were velocities (the 100ms
## after a restart is drawn as a near-stall on purpose: the whole remote
## view is that far in the past), their spread is reported and not judged,
## and their jump bound is a quarter tile outright rather than a multiple
## of a mean that milling enemies keep small. A run with no other player
## in view judges enemies alone.
##
## Exit codes: 0 even, 1 uneven or a command did not take, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
const ENEMY := 210
const COUNT := 8
const FRAMES := 240
const MAX_STALLS := FRAMES / 20
const MAX_JUMP := 5.0
const MAX_SPREAD := 0.5
## The freeze-and-jump this exists to catch was 83px; a correction closing
## at the native client's 256 px/s is under 4px a frame.
const MAX_ENEMY_JUMP_PX := 8.0
const VIEW_PX := 10.0 * GameConstants.TILE_SIZE
const NOMINAL_FRAME_MS := 1000.0 / 60.0

var _drive: LiveDriver
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [lag_ms] [jitter_ms] [count]")
		quit(2)
		return
	var config := LiveDriver.config_from(args)
	config.lag_ms = float(args[6]) if args.size() > 6 else 0.0
	config.lag_jitter_ms = float(args[7]) if args.size() > 7 else 0.0
	var count := int(args[8]) if args.size() > 8 else COUNT

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(config)
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
	print("in game at lag %.0f ms (jitter %.0f), ping reads %d ms" % [
		config.lag_ms, config.lag_jitter_ms, _main.client.stats.ping_ms])

	# Other players first, in the nexus, where the walker paces: it cannot
	# follow us through a portal, and enemies do not keep in the nexus.
	var uneven := 0
	var frames := await _trace(state, false)
	print("%-8s %s" % ["players", _roster(state, "players")])
	uneven += _judge_kind("players", frames["players"])

	if not await _drive.toggle_on("/admin", "Admin mode") or not await _drive.toggle_on("/godmode", "God mode"):
		quit(1)
		return
	if not await LiveRealm.leave_nexus(_drive):
		quit(1)
		return
	var enemies_before: int = state.entities.enemies.size()
	if not await _drive.command("/spawn %d %d" % [ENEMY, count], "Spawned %d of enemy %d" % [count, ENEMY]):
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT,
			func() -> bool: return state.entities.enemies.size() >= enemies_before + count / 2):
		push_error("only %d of %d spawned enemies arrived" % [state.entities.enemies.size() - enemies_before, count])
		quit(1)
		return
	await _drive.settle(1.0)
	frames = await _trace(state, true)
	_drive.capture("remote_motion_%.0fms" % config.lag_ms)
	print("%-8s %s" % ["enemies", _roster(state, "enemies")])
	uneven += _judge_kind("enemies", frames["enemies"])
	print("ping %d ms   jitter %d ms" % [_main.client.stats.ping_ms, _main.client.stats.jitter_ms])
	quit(1 if uneven > 0 else 0)


## Frames as MotionTrace.measure takes them, one list per kind: every
## moving remote entity in view contributes its displacement each frame.
func _trace(state: RealmState, walk: bool) -> Dictionary:
	var frames := {"players": [], "enemies": []}
	var last := {}
	var last_ms := Time.get_ticks_msec()
	for frame in FRAMES + 1:
		# Enemy 210 chases only past its 240px attack range, so walk: away
		# for the first half, then back through them, which turns every one
		# of them round -- a velocity correction apiece.
		if walk and frame == 0:
			Input.action_press("move_right")
		elif walk and frame == FRAMES / 2:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif walk and frame == FRAMES:
			_drive.halt()
		await process_frame
		var now := Time.get_ticks_msec()
		var delta := float(now - last_ms)
		last_ms = now
		var seen := {}
		for kind in ["players", "enemies"]:
			var table: Dictionary = state.entities[kind]
			for id in table:
				if id == state.local.id or not _moving(table[id], now):
					continue
				var at: Vector2 = state.entities.render_position(table[id])
				if at.distance_to(state.local.render_position()) > VIEW_PX:
					continue
				seen[id] = at
				# Per frame of a 60Hz display, whatever this machine's pacing
				# does: process_frame fires 8, 3 and 14 ms apart in a fixed
				# cycle on a 120Hz screen, and every drawn thing shares it.
				if last.has(id) and frame > 0 and delta > 0.0:
					frames[kind].append([delta, 1, at.distance_to(last[id]) * NOMINAL_FRAME_MS / delta])
		last = seen
	return frames


## What the roster held when the trace ended: how many, how many the server
## last gave a velocity, and how old their newest samples are.
static func _roster(state: RealmState, kind: String) -> String:
	var table: Dictionary = state.entities[kind]
	var now := Time.get_ticks_msec()
	var with_velocity := 0
	var ages := PackedStringArray()
	for id in table:
		if id == state.local.id:
			continue
		var snapshots: Array = table[id]["snaps"]
		if snapshots.is_empty():
			continue
		if snapshots[-1]["vel"] != Vector2.ZERO:
			with_velocity += 1
		ages.append("%d" % int(float(now) - snapshots[-1]["t"]))
	return "%d in the roster, %d with a velocity, newest samples %s ms old" % [
		table.size() - (1 if table.has(state.local.id) else 0), with_velocity, " ".join(ages)]


## The server's last two words on the entity were velocities, recently.
static func _moving(entity: Dictionary, now: int) -> bool:
	var snapshots: Array = entity.get("snaps", [])
	if snapshots.is_empty() or snapshots[-1]["vel"] == Vector2.ZERO:
		return false
	if snapshots.size() > 1 and snapshots[-2]["vel"] == Vector2.ZERO:
		return false
	var stale := EntitySnapshots.PEER_STALE_MS if entity.get("kind", -1) == GameConstants.ENTITY_PLAYER \
		else EntitySnapshots.STALE_MS
	return float(now) - snapshots[-1]["t"] < stale


func _judge_kind(kind: String, frames: Array) -> int:
	if frames.is_empty():
		print("%-8s no moving %s in view" % [kind, kind])
		return 0
	var measured := MotionTrace.measure(frames, 0)
	print("%-8s %s" % [kind, MotionTrace.summary(measured)])
	return _judge(kind, measured)


func _judge(kind: String, m: Dictionary) -> int:
	var faults := PackedStringArray()
	var stalls_allowed := maxi(MAX_STALLS, m["frames"] / 20)
	if m["stalls"] > stalls_allowed:
		faults.append("%d frames that barely moved" % m["stalls"])
	if kind == "enemies":
		if m["max"] > MAX_ENEMY_JUMP_PX:
			faults.append("a jump of %.2f px, past a quarter tile" % m["max"])
	else:
		if m["sd"] > MAX_SPREAD * m["mean"]:
			faults.append("spread %.2f over half the mean %.2f" % [m["sd"], m["mean"]])
		if m["max"] > MAX_JUMP * m["mean"]:
			faults.append("a jump of %.2f past five means" % m["max"])
	if faults.is_empty():
		return 0
	push_error("%s move unevenly: %s" % [kind, "; ".join(faults)])
	return 1
