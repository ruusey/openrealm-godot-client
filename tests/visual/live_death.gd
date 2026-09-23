extends SceneTree

## Dies on a live server, and checks that the character is gone.
##
## Death is permadeath -- the server deletes the character on the ack -- so
## this makes a throwaway character first, through the real sign-in and
## class grid, and kills that one. The nexus is the one place enemies
## cannot be fought, so it takes a portal out of it first (LiveRealm), and a
## hundred of enemy 210 are spawned at its feet there with the admin
## /spawn, god mode off -- twenty were not enough: they were gone again
## inside a minute and the character had regenerated. The ack ends the
## session: the server disconnects us in answer to it, the death screen
## goes up, and on dismissing it a fresh sign-in has to show the character
## in the graveyard, not the list.
##
##   godot --path . --script tests/visual/live_death.gd -- \
##     <host> <data_port> <email> <password> <class_id> <out_dir> [ws] [enemy] [count]
##
## Every run adds a character to the account and then buries it.
##
## Exit codes: 0 dead and buried, 1 survived or the account still lists it,
## 2 bad arguments.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
## Enemy 210's shots against a level-one character with no armour.
const DEATH_TIMEOUT := 60.0
const ENEMY := 210
const COUNT := 100

var _drive: LiveDriver
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <class_id> <out_dir> [ws] [enemy] [count]")
		quit(2)
		return
	var enemy := int(args[7]) if args.size() > 7 else ENEMY
	var count := int(args[8]) if args.size() > 8 else COUNT

	_drive = LiveDriver.new(self, args[5])
	var config := LiveDriver.config_from(args)
	config.character_uuid = ""
	config.autoconnect = false
	await _drive.boot(config)
	_main = _drive.main
	var made := await _create(int(args[4]))
	if made == "":
		quit(1)
		return
	quit(0 if await _die(enemy, count) and await _buried(made) else 1)


## A character to lose, entered on straight away with "Create & play".
func _create(class_id: int) -> String:
	var login: LoginScreen = _main.screens.login
	await login._on_login_pressed()
	if not login._stage.creator.visible:
		push_error("sign-in did not reach the class grid: %s" % login._status.text)
		return ""
	if not login._stage.creator.options.has(class_id):
		push_error("no class %d in the content; have %s" % [class_id, login._stage.creator.options.keys()])
		return ""
	var before: int = login._stage.picker.alive_count()
	login._stage.creator.options[class_id].button_pressed = true
	await login._stage.creator._create(true)
	if login._stage.picker.alive_count() != before + 1:
		push_error("the account did not gain a character: %s" % login._status.text)
		return ""
	var made: String = login._stage.picker.selected().get("characterUuid", "")
	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return _main.client.is_in_game()):
		push_error("never reached in-game on the new character; client state = %d" % _main.client.state)
		return ""
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return _main.state.tiles.tile_count() > 300):
		push_error("the map never streamed in")
		return ""
	await _drive.settle(1.0)
	print("created %s, in the realm as playerId=%d hp %d" % [made, _main.state.local.id, _main.state.local.health])
	return made


func _die(enemy: int, count: int) -> bool:
	var state: RealmState = _main.state
	var death: DeathScreen = _main.screens.death
	# Turning admin on clears god mode, which is the point: we are here to die.
	if not await _drive.toggle_on("/admin", "Admin mode"):
		return false
	if not await LiveRealm.leave_nexus(_drive):
		return false
	if await _drive.command("/spawn %d %d" % [enemy, count], "Spawned %d of enemy %d" % [count, enemy]) == "":
		return false
	var name: String = state.local.name
	# The crowd, a moment in: what a survivor was standing among.
	await _drive.settle(6.0)
	_drive.capture("death_crowd")
	var fell := await _drive.wait(DEATH_TIMEOUT, func() -> bool: return death.visible)
	if not fell:
		push_error("still alive after %.0fs among %d of enemy %d: hp %d, effects %s, %d enemies (nearest %.0f px), %d bullets, state %d" % [
			DEATH_TIMEOUT, count, enemy, state.local.health, state.local.effects,
			state.entities.enemies.size(), _nearest_enemy_px(), state.projectiles.bullets.size(),
			_main.client.state])
		return false
	await _drive.settle(1.5)
	print("%s died; client state %d, in game %s" % [name, _main.client.state, _main.client.is_in_game()])
	_drive.capture("death_screen")
	if _main.client.is_in_game():
		push_error("dead, and still playing")
		return false
	return true


## Dismissing the screen drops the stale list; signing in again must show the
## character in the graveyard and nowhere else.
func _buried(made: String) -> bool:
	var login: LoginScreen = _main.screens.login
	var death: DeathScreen = _main.screens.death
	death._on_pressed()
	await _drive.settle(0.5)
	if not login.visible or login._stage.picker.visible:
		push_error("dismissing the death screen did not return to sign-in")
		return false
	await login._on_login_pressed()
	var picker: CharacterPicker = login._stage.picker
	var is_it := func(c: Dictionary) -> bool: return c.get("characterUuid", "") == made
	var among_living: bool = picker._pages[CharacterPicker.ALIVE].any(is_it)
	var among_buried: bool = picker._pages[CharacterPicker.GRAVEYARD].any(is_it)
	print("after death: %d living, %d in the graveyard; %s is %s" % [picker.alive_count(),
		picker.dead_count(), made,
		"buried" if among_buried else ("STILL LISTED" if among_living else "GONE ENTIRELY")])
	# The picker fills on the frame after the account arrives; show its
	# graveyard page, which is where the character has to be.
	await _drive.settle(0.3)
	picker.tabs.current_tab = CharacterPicker.GRAVEYARD
	await _drive.settle(0.3)
	_drive.capture("death_graveyard")
	return among_buried and not among_living


func _nearest_enemy_px() -> float:
	var state: RealmState = _main.state
	var closest := INF
	for id in state.entities.enemies:
		closest = minf(closest, state.local.position.distance_to(state.entities.render_position(state.entities.enemies[id])))
	return closest
