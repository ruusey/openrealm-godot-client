extends SceneTree

## Fights something on a live server and waits for the number to come back.
##
## Combat text is inbound-only: the client cannot make one appear by itself,
## so the only honest check is to hit an enemy and see whether the server's
## TextEffectPacket turns into something on screen. The nexus is the one
## place enemies cannot be attacked, so this takes a portal out of it first
## (LiveRealm), and the target is spawned at our feet there with the
## server's own /spawn, which is admin-only; god mode keeps us alive while
## it shoots back.
##
##   godot --path . --script tests/visual/live_combat.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws] [enemy]
##
## Exit codes: 0 a number arrived, 1 never got one, 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
const FIGHT_TIMEOUT := 40.0
## 80 hp and no defence: a few basic shots, and it shoots back.
const ENEMY := 210
## A rate the server accepts at any DEX -- this script is about whether the
## number comes back, not about the cadence.
const FIRE_INTERVAL := 0.5
## Close enough that a basic shot reaches, without standing on top of it.
const ENGAGE_PX := 100.0

var _drive: LiveDriver
var _next_shot := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws] [enemy]")
		quit(2)
		return
	var enemy := int(args[7]) if args.size() > 7 else ENEMY

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main := _drive.main

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return main.state.tiles.tile_count() > 300):
		push_error("the map never streamed in")
		quit(1)
		return
	await _drive.settle(1.0)
	quit(0 if await _spawn(enemy) and await _fight() else 1)


## One enemy, at our feet: a count of one puts it exactly there, and gets
## no SYSTEM line back (only a count above one is confirmed), so the enemy
## arriving is the answer.
func _spawn(enemy: int) -> bool:
	var state: RealmState = _drive.main.state
	if not await _drive.toggle_on("/admin", "Admin mode") or not await _drive.toggle_on("/godmode", "God mode"):
		return false
	if not await LiveRealm.leave_nexus(_drive):
		return false
	var before: int = state.entities.enemies.size()
	if not _drive.main.chat_actions.say("/spawn %d 1" % enemy):
		push_error("could not send /spawn")
		return false
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return state.entities.enemies.size() > before):
		push_error("no enemy arrived after /spawn %d 1; the chat said: %s" % [enemy,
			state.chat.lines.slice(-3).map(func(entry: Dictionary) -> String: return ChatLog.rendered(entry))])
		return false
	print("enemy %d spawned; %d in the realm" % [enemy, state.entities.enemies.size()])
	return true


func _fight() -> bool:
	var state: RealmState = _drive.main.state
	if not await _drive.wait(LOAD_TIMEOUT,
			func() -> bool: return not state.entities.enemies.is_empty()):
		push_error("no enemies in realm %d" % state.tiles.realm_id)
		return false

	var landed := await _drive.wait(FIGHT_TIMEOUT, func() -> bool:
		var target := _closest_enemy()
		if target == Vector2.ZERO:
			return false
		if _drive.distance_to(target) > ENGAGE_PX:
			_drive.steer_to(target)
		else:
			_drive.halt()
		_shoot_at(target)
		return not state.texts.texts.is_empty())
	_drive.halt()

	if not landed:
		push_error("fought for %.0fs and no TextEffectPacket ever came back" % FIGHT_TIMEOUT)
		return false
	var first: Dictionary = state.texts.texts[0]
	print("combat text: \"%s\" at %s, %d on screen" % [
		first["text"], first["pos"], state.texts.texts.size()])
	_drive.capture("combat")
	return true


## The same two lines PlayerInput runs on a held mouse button, at the same
## rate -- firing every frame instead is 30 kbit/s of packets the server's
## own rate gate throws away.
func _shoot_at(target: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_shot:
		return
	_next_shot = now + int(FIRE_INTERVAL * 1000.0)
	var shot: Dictionary = _drive.main.state.projectiles.fire_basic_attack(target)
	if not shot.is_empty():
		_drive.main.client.send("PlayerShootPacket", shot)


func _closest_enemy() -> Vector2:
	var state: RealmState = _drive.main.state
	var found := Vector2.ZERO
	var closest := INF
	for id in state.entities.enemies:
		var at: Vector2 = state.entities.render_position(state.entities.enemies[id])
		var distance := state.local.position.distance_to(at)
		if distance < closest:
			closest = distance
			found = at
	return found
