extends SceneTree

## Casts a hotbar ability against a live server and waits for its answer.
##
## The unit suite proves what the client sends; this proves the server takes
## it. A cast the server accepts comes back as the ability's projectiles in
## the next LoadPacket -- flagged as ours, which is what claims the predicted
## copies -- and as a PlayerStatePacket carrying the mana it charged. A cast
## it refuses comes back as nothing at all, which is the whole reason the
## client gates before sending.
##
##   godot --path . --script tests/visual/live_ability.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws]
##
## Exit codes: 0 the server answered the cast, 1 it did not, 2 bad arguments,
## 3 the class casts nothing from its first slot.

const LOGIN_TIMEOUT := 20.0
const ANSWER_TIMEOUT := 5.0
const CAST_OFFSET := Vector2(96.0, 0.0)

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws] [slot]")
		quit(2)
		return
	var slot := int(args[7]) if args.size() > 7 else 0

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main := _drive.main
	var state: RealmState = main.state

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	var before: int = state.abilities.version
	if not await _drive.wait(ANSWER_TIMEOUT, func() -> bool: return state.abilities.version > before):
		push_error("no UpdatePacket ever arrived")
		quit(1)
		return
	await _drive.settle(1.0)

	var ability_id: int = main.game_data.abilities.hotbar_id(state.local.class_id, slot)
	var definition: Dictionary = main.game_data.abilities.ability(ability_id)
	if definition.is_empty() or main.game_data.abilities.projectile_group(ability_id) == 0:
		push_error("slot %d of class %d fires no projectiles; nothing to wait for" % [slot, state.local.class_id])
		quit(3)
		return
	var mana_before: int = state.local.mana
	print("casting %s (mp %d of %d) at %s" % [definition.get("name", "?"),
		int(definition.get("mpCost", 0)), mana_before, state.local.centre() + CAST_OFFSET])
	if not main.caster.cast(slot, state.local.centre() + CAST_OFFSET):
		push_error("the client refused the cast")
		quit(1)
		return
	_drive.capture("ability_cast")

	# The server's copies of the shots claim the predictions, or arrive on
	# their own if the prediction had already expired.
	var answered := await _drive.wait(ANSWER_TIMEOUT, func() -> bool:
		for id in state.projectiles.bullets:
			if id > 0 or state.projectiles.bullets[id].get("server_id", 0) != 0:
				return true
		return false)
	if not answered:
		push_error("the server never sent the ability's projectiles")
		quit(1)
		return
	# Long enough for a trailing shot to leave a trail behind it.
	await _drive.settle(0.5)
	print("server answered: %d bullets on screen, %d particles behind them, mana %d -> %d" % [
		state.projectiles.bullets.size(), state.particles.count, mana_before, state.local.mana])
	_drive.capture("ability_answered")
	quit(0)
