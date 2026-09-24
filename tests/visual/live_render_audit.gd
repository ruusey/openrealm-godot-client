extends SceneTree

## Where the nexus's draw calls go, and whether anything is drawing or
## running that should not be.
##
## Logs in, lets the nexus stream in, then reads the frame's draw calls --
## the rendering server's own count for the whole frame, read from it
## directly, so nothing drawn can be
## missing from it -- and measures each top-level layer (the world, the
## overlay, every panel) drawn on its own. Prints one line a layer, largest
## first, and fails when:
##   - the frame exceeds BUDGET draw calls,
##   - anything draws with every layer hidden,
##   - a screen that has no business in a realm (sign-in, loading, death)
##     is drawing, or
##   - anything under a hidden layer is still processing (RenderAudit), the
##     way the sign-in torches once ran behind the whole session.
##
##   godot --path . --resolution 1280x720 --script tests/visual/live_render_audit.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws] [budget]
##
## Windowed: headless draws nothing, so every count would read zero. Leave
## the window in front, as for the captures.
##
## Exit codes: 0 within budget and nothing astray, 1 otherwise or never got
## in, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
## The idle nexus draws 269 at 1280x720: 234 before the ground was kept in
## chunks (GroundChunk), which cost 35 more -- each chunk replays the
## ground's passes, and the small nexus sits where four meet -- for half the
## frame time. The budget leaves room for a few players passing through.
const BUDGET := 290
## Frames to let a change settle before it is read, and frames read.
const SETTLE := 3
const SAMPLES := 10
## Screens that are for outside a realm; drawing in one is a leak.
const NOT_IN_GAME := ["LoginScreen", "LoadingScreen", "DeathScreen"]

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws] [budget]")
		quit(2)
		return
	var budget := int(args[7]) if args.size() > 7 else BUDGET
	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main: Node = _drive.main
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return main.state.tiles.tile_count() > 300):
		push_error("the map never streamed in")
		quit(1)
		return
	await _drive.settle(1.0)
	quit(0 if await _audit(root, budget) else 1)


## Audited from `top`, the SceneTree's root Window -- the engine's own root,
## above Main, with nothing over it -- so a layer added anywhere in the tree
## is attributed. Each layer is measured ALONE -- every other one
## hidden and stopped -- because hiding just the one while the rest run
## lets a restored panel move its neighbours, and one layer's calls were
## booked to another (-21 on the chat, +24 on the nearby list). With every
## layer hidden the frame must draw nothing; whatever it does draw is
## outside any layer, and is reported as such.
func _audit(top: Node, budget: int) -> bool:
	var total := await _calls()
	var objects := FrameCounts.objects()
	var primitives := FrameCounts.primitives()
	var drawn := RenderAudit.visible_by_layer(top)
	var shown := RenderAudit.layers(top).filter(
		func(layer) -> bool: return layer.visible and drawn.has(RenderAudit.label(layer)))
	var rows := []
	for layer in shown:
		rows.append([await _alone(shown, layer), drawn[RenderAudit.label(layer)], RenderAudit.label(layer)])
	var stray := await _alone(shown, null)
	rows.append([stray, 0, "(outside any layer)"])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("[render] %d draw calls, %d objects, %d primitives in the nexus (budget %d)" % [total,
		objects, primitives, budget])
	for row in rows:
		print("[render]   %4d calls  %4d items  %s" % row)
	var ok := total > 0 and total <= budget and stray == 0
	if total <= 0:
		push_error("no draw calls at all -- run it windowed, not headless")
	elif total > budget:
		push_error("%d draw calls is over the budget of %d" % [total, budget])
	if stray > 0:
		push_error("%d draw calls with every layer hidden" % stray)
	for name in NOT_IN_GAME:
		if drawn.has(name):
			push_error("%s is drawing in a realm (%d items)" % [name, drawn[name]])
			ok = false
	var idle := RenderAudit.hidden_work(top)
	for line in idle:
		push_error("processing while hidden: " + line)
	return ok and idle.is_empty()


## The frame's draw calls with only `layer` showing (none, for null), every
## other layer hidden and stopped; all put back afterwards.
func _alone(shown: Array, layer: Node) -> int:
	var modes := {}
	for other in shown:
		modes[other] = other.process_mode
		other.process_mode = Node.PROCESS_MODE_DISABLED
		other.visible = other == layer
	var calls := await _calls()
	for other in shown:
		other.visible = true
		other.process_mode = modes[other]
	await _frames(SETTLE)
	return calls


## The frame's draw calls, the median of a few frames once settled. The
## rendering server's own count for the whole frame, every viewport, so
## nothing drawn can be missing from it. (Viewport.get_render_info is no
## substitute: it counts the 3D scene only and reads 0 here.)
func _calls() -> int:
	await _frames(SETTLE)
	var seen: Array[int] = []
	for i in SAMPLES:
		await process_frame
		seen.append(FrameCounts.draw_calls())
	seen.sort()
	return seen[seen.size() / 2]


func _frames(count: int) -> void:
	for i in count:
		await process_frame
