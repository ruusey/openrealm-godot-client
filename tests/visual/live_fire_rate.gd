extends SceneTree

## Fires at the rate we compute against a live server, and reports the cadence
## the character's real stats produce.
##
## What it cannot tell you is how many shots were ACCEPTED: the server does not
## echo a shooter its own bullets, so the count of ours coming back is always
## zero and acceptance is invisible from here. The server's own log is where
## that shows -- as a packet rate. The quarter-second placeholder pushed 28
## kbit/s of PlayerShootPacket at a character the server would answer twice a
## second; the computed rate pushes 0.3.
##
##   godot --path . --script tests/visual/live_fire_rate.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws]

const LOGIN_TIMEOUT := 20.0
const FIRING_SECONDS := 6.0

var _drive: LiveDriver
var _sent := 0
## A member, not a local: a lambda captures locals BY VALUE, so a cadence kept
## in one never advances and this fired every frame instead.
var _next_shot := 0
var _ours := {}
var _from_server := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws]")
		quit(2)
		return

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main := _drive.main
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	# Stats arrive with the first UpdatePacket, and the rate depends on them.
	await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return not main.state.local.stats.is_empty())
	await _drive.settle(0.5)

	var interval: float = main.input.interval()
	print("dex %d, weapon %d -> %.0f ms between shots (placeholder was 250)" % [
		int(main.state.local.stats.get("dex", -1)),
		int(main.state.local.equipped_weapon().get("itemId", -1)),
		interval * 1000.0])

	var until := Time.get_ticks_msec() + int(FIRING_SECONDS * 1000.0)
	await _drive.wait(FIRING_SECONDS + 2.0, func() -> bool:
		_note_bullets()
		if Time.get_ticks_msec() >= until:
			return true
		if Time.get_ticks_msec() >= _next_shot:
			_next_shot = Time.get_ticks_msec() + int(interval * 1000.0)
			_fire()
		return false)
	await _drive.settle(1.0)
	_note_bullets()

	print("fired %d in %.0fs (one every %.0f ms), server sent back %d of them" % [
		_sent, FIRING_SECONDS, interval * 1000.0, _from_server.size()])
	_drive.capture("fire_rate")
	quit(0)


func _fire() -> void:
	var state: RealmState = _drive.main.state
	var shot: Dictionary = state.projectiles.fire_basic_attack(
		state.local.centre() + Vector2(0.0, 96.0))
	if shot.is_empty():
		return
	_sent += 1
	_ours[int(shot.get("projectileId", -1))] = true
	_drive.main.client.send("PlayerShootPacket", shot)


## Bullets the server sent back for our own shots. A predicted one is keyed by
## the id we chose and told the server about, so anything carrying our id that
## we did not key ourselves came from the server.
func _note_bullets() -> void:
	var state: RealmState = _drive.main.state
	for id in state.projectiles.bullets:
		var bullet: Dictionary = state.projectiles.bullets[id]
		if int(bullet.get("src_entity_id", 0)) == state.local.id and not _ours.has(id):
			_from_server[id] = true
