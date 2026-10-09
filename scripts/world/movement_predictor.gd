class_name MovementPredictor
extends RefCounted

## Client-side prediction and server reconciliation for the local player.
##
## The server runs a fixed 64Hz tick, so prediction steps at that same fixed
## rate rather than per rendered frame -- that is what keeps the client's
## integration identical to the server's. Each step is sequence-numbered; the
## server acks with the position it produced, and we rewind to it and replay
## every input it has not seen, so a correction never costs the player input
## they already made.

## Divergence beyond this (px) is a visible correction worth counting and
## smoothing. Smaller errors are still adopted -- see apply_position_ack.
const VISIBLE_CORRECTION_PX := 2.0
## Past this the player was moved by something other than walking (teleport,
## realm change): snap outright, with no smoothing to unwind.
const TELEPORT_PX := 64.0
const MAX_INPUT_HISTORY := 256
## Never replay more than this after a stall (window drag, breakpoint).
const MAX_CATCHUP_TICKS := 8.0

var input_seq := 0
var corrections := 0
var last_correction_px := 0.0
var unacked_inputs := 0
## Applied pixels-per-tick as of the last predict(), for the walk cadence:
## the speed the player is really moving at, slow tiles included.
var pace_px := 0.0

var _player: LocalPlayer
var _tiles: TileMapState
var _history: Array = []   # [{seq, input: Vector2, position: Vector2}]
var _send_policy := MoveSendPolicy.new()
var _accumulator := 0.0


func _init(player: LocalPlayer, tiles: TileMapState) -> void:
	_player = player
	_tiles = tiles


## Steps prediction at the fixed tick rate and returns the inputs worth
## sending, as [{seq, vx, vy}, ...].
func predict(delta: float, input: Vector2) -> Array:
	var to_send: Array = []
	if not _player.is_present():
		return to_send

	_accumulator = minf(_accumulator + delta, GameConstants.TICK_DELTA * MAX_CATCHUP_TICKS)
	while _accumulator >= GameConstants.TICK_DELTA:
		_accumulator -= GameConstants.TICK_DELTA
		input_seq += 1
		var before := _player.position
		_player.position = step(before, input)
		_player.previous_position = before
		_history.append({"seq": input_seq, "input": input, "position": _player.position,
			"snapshot": _effect_snapshot()})
		if _history.size() > MAX_INPUT_HISTORY:
			_history.pop_front()
		if _send_policy.should_send(input):
			to_send.append({"seq": input_seq, "vx": input.x, "vy": input.y})

	# What is left over is how far this frame sits into the next tick.
	_player.tick_alpha = _accumulator / GameConstants.TICK_DELTA
	unacked_inputs = _history.size()
	_player.moving = input.length() > 0.001
	pace_px = pace_at(_player.position) if _player.moving else 0.0
	if _player.moving:
		_player.face_toward(input)
	return to_send


## One 64Hz movement tick, mirroring RealmManagerServer.applyMovementTick
## and the step both reference clients replay with: clamp to a unit vector,
## pixels-per-tick from SPD and the speed effects, the slow-tile divisor,
## then each axis tested from where the tick STARTED -- not X and then Y
## from the moved X -- and, when neither is blocked alone but the diagonal
## is, the smaller axis gives way so the player slides along a corner
## instead of cutting it. A paralysed player does not move at all.
func step(position: Vector2, input: Vector2) -> Vector2:
	if input.length_squared() <= 0.000001 or _player.effects.has(LocalPlayer.PARALYZED):
		return position
	return _move(position, input, pace_at(position))


## The movement math shared by the live step and reconciliation replay: clamp to
## a unit vector, then each axis tested from where the tick STARTED, sliding along
## a corner when only the diagonal is blocked.
func _move(position: Vector2, input: Vector2, pace: float) -> Vector2:
	var vector := input
	if vector.length() > 1.0:
		vector = vector.normalized()
	var delta := vector * pace
	var size := GameConstants.PLAYER_SIZE
	var x_blocked := _tiles.blocks(position + Vector2(delta.x, 0.0), size)
	var y_blocked := _tiles.blocks(position + Vector2(0.0, delta.y), size)
	if not x_blocked and not y_blocked and delta.x != 0.0 and delta.y != 0.0 \
			and _tiles.blocks(position + delta, size):
		if absf(delta.x) >= absf(delta.y):
			y_blocked = true
		else:
			x_blocked = true
	return Vector2(position.x if x_blocked else position.x + delta.x,
		position.y if y_blocked else position.y + delta.y)


## Pixels per tick from here, after the slow-tile divisor. Mirrors the
## server's `collidesSlowTile(p) ? 3.0f : 1.0f`, sampled where it samples.
func pace_at(position: Vector2) -> float:
	var pace := _player.speed_per_tick()
	if _tiles.slows(position, GameConstants.PLAYER_SIZE):
		pace /= 3.0
	return pace


## One replayed tick during reconciliation, run at EXACTLY the SPD/SPEEDY/SLOWED/
## PARALYZED that were true when the input was made (its snapshot) -- NOT the current
## set. Honouring the current effect retroactively re-slowed every still-unacked input
## the instant a slow landed, shortening the whole window at once; with an RTT of
## inputs in flight that correction regularly blew past the smoothing cap and the
## player visibly snapped backward. Replaying each input at its own captured speed
## keeps the replay identical to what was predicted, so the slow's arrival trickles in
## as tiny per-ack corrections the smoother absorbs instead of one hard jump.
func _replay_step(position: Vector2, input: Vector2, snap: Dictionary) -> Vector2:
	if input.length_squared() <= 0.000001 or snap.get("paralyzed", false):
		return position
	var base := _snapshot_speed_per_tick(snap)
	if _tiles.slows(position, GameConstants.PLAYER_SIZE):
		base /= 3.0
	return _move(position, input, base)


## The per-tick speed from a captured input snapshot, matching speed_per_tick() as it
## was AT PREDICTION TIME. Uses only the snapshot (never the current effect set) so a
## slow landing or ending mid-history doesn't retroactively rewrite the whole window.
func _snapshot_speed_per_tick(snap: Dictionary) -> float:
	var tiles_per_second := 4.0 + 5.6 * (float(snap.get("spd", 15)) / 75.0)
	if snap.get("speedy", false):
		tiles_per_second *= 1.5
	if snap.get("slowed", false):
		tiles_per_second *= 0.5
	return tiles_per_second * float(GameConstants.TILE_SIZE) / GameConstants.TICK_RATE


## The effect state to record with an input, for accurate replay later. Effects
## and SPD change rarely, so the same immutable snapshot is shared across the
## inputs that saw identical state -- a fresh dict is built only when it changes,
## not 64 times a second. Safe to share: replay reads the snapshot, never mutates it.
var _snapshot_cache: Dictionary = {}

func _effect_snapshot() -> Dictionary:
	var slowed := _player.effects.has(LocalPlayer.SLOWED)
	var speedy := _player.effects.has(LocalPlayer.SPEEDY)
	var paralyzed := _player.effects.has(LocalPlayer.PARALYZED)
	var spd := float(_player.stats.get("spd", 15))
	if _snapshot_cache.is_empty() or _snapshot_cache["slowed"] != slowed \
			or _snapshot_cache["speedy"] != speedy \
			or _snapshot_cache["paralyzed"] != paralyzed or _snapshot_cache["spd"] != spd:
		_snapshot_cache = {"slowed": slowed, "speedy": speedy, "paralyzed": paralyzed, "spd": spd}
	return _snapshot_cache


func apply_position_ack(data: Dictionary) -> void:
	var acked_seq := int(data.get("seq", -1))
	var server_position := Vector2(data.get("posX", 0.0), data.get("posY", 0.0))

	# Drop what the server has seen and keep everything after it -- never
	# look for the exact sequence. The server acks lastProcessedInputSeq at
	# 32Hz, and on a tick no packet reached it, it steps us anyway and then
	# acks the SAME seq again: an ack for an input already dropped is the
	# ordinary case, not a lost history. Treating it as one -- snapping to
	# the server's position and clearing every unacked input -- put the
	# player an RTT's worth of inputs back, and the next real ack was not in
	# the history either. That was a 15px sawtooth on a real connection,
	# invisible on loopback. Both references drop `<= seq` and replay the
	# rest, and so does this.
	# seq is monotonic and history is append-ordered, so the acked inputs are a
	# contiguous prefix: drop it in place instead of allocating a filtered Array
	# and a lambda on every 32Hz ack. Equivalent to keeping every `seq > acked`.
	while not _history.is_empty() and int(_history[0]["seq"]) <= acked_seq:
		_history.pop_front()

	# Replay from the server's position and adopt the result *always*, even
	# when the error looks negligible. The server re-applies the last input on
	# any tick no packet reached it, so keeping our own prediction because the
	# gap looked small lets it compound.
	var replayed := server_position
	for entry in _history:
		replayed = _replay_step(replayed, entry["input"], entry.get("snapshot", {}))
		entry["position"] = replayed

	var predicted := _player.position
	var slide_from := _player.previous_position
	var error := predicted.distance_to(replayed)
	_player.position = replayed
	unacked_inputs = _history.size()
	if error > TELEPORT_PX:
		# Settled on the new place by the assignment: nothing to slide from.
		pass
	else:
		# Carried along with the position, so the correction is the render
		# offset's to unwind and not something the frame slides across.
		_player.previous_position = slide_from + (replayed - predicted)
	if error <= VISIBLE_CORRECTION_PX:
		return

	corrections += 1
	last_correction_px = error
	# A teleport has nothing to unwind visually; smaller jumps ease back.
	_player.set_smoothing(Vector2.ZERO if error > TELEPORT_PX else predicted - replayed)


## Drops every unacked input. A realm change is not a mispredict: there is
## nothing to replay onto a map we have not been sent yet, and replaying
## across the boundary would only fight the spawn position that follows.
func clear_pending() -> void:
	_history.clear()
	unacked_inputs = 0


func pending_input_count() -> int:
	return _history.size()
