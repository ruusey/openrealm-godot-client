class_name RealmTransition
extends RefCounted

## Leaving one realm and arriving in the next.
##
## Three steps, each driven by something different, which is why they are one
## object rather than three stray flags:
##
##   begin()          we asked to leave -- tear the realm down at once
##   apply_load_map() the next realm's tiles arrive
##   snap_local()     the server finally says where we are standing
##
## The last two are separate on purpose: the tiles land before the position
## does, and until it lands prediction is still running from where we stood in
## the realm we left. The native client keeps the same two flags apart for the
## same reason.

## How long to wait for an answer before giving up on it. The web client
## bounds the same wait (TRANSITION_MAX_MS), because the reply can be dropped
## and neither flag is a state to be stuck in: one would leave the HUD
## claiming an arrival that never came, the other would snap us to a stale
## position the next time any entity moved.
const MAX_WAIT_MS := 6000

## True between asking to leave and the tiles answering. What tells the HUD an
## empty world is deliberate rather than broken.
var pending := false
## True until the server states our position in the new realm.
##
## The web client clears this on the tiles instead, to dismiss its transition
## splash even when the position packet is lost -- and gives up the snap in
## that case. We have no splash to dismiss and the snap is the whole point, so
## this one waits for the position and is bounded by the timeout above.
var awaiting_snap := false
## What the server called the realm we are entering. The LoadMapPacket carries
## an id and no name, so this comes from a SYSTEM line -- which the server
## sends AFTER it: `sendImmediateLoadMap(...)` then `onPlayerJoin(...)`, and
## onPlayerJoin is what writes the name. Waiting for it only while `pending`
## is up therefore never sees it, because the tiles are what clear `pending`.
var zone := ""
## True from asking to leave until a name arrives, which outlasts `pending` on
## purpose.
var _naming := false

var _state: RealmState
var _clock: Callable
var _started_ms := 0


func _init(state: RealmState, clock: Callable) -> void:
	_state = state
	_clock = clock


## Everything realm-scoped goes; the player stays, because it is the one
## entity that crosses. Prediction starts over too: a map we have not been
## sent yet shares no collision with the one under our feet, so replaying
## unacked inputs into it would only fight the spawn position that follows.
func begin() -> void:
	pending = true
	awaiting_snap = true
	zone = ""
	_naming = true
	_started_ms = _clock.call()
	_state.tiles.clear()
	_state.entities.clear_but(_state.local.id)
	_state.projectiles.clear()
	# Bullets that vanish with the realm did not land anywhere.
	_state.particles.clear()
	_state.texts.clear()
	_state.movement.clear_pending()
	_state.local.smooth_offset = Vector2.ZERO
	# The picture goes with the tiles: the web client nulls its grid here and
	# resets the minimap on the missing grid.
	_state.minimap.clear_realm()


## The first SYSTEM line addressed to us after we asked to leave names where
## we went. The first, not the last: the server says more than one thing, and
## the rest are about the realm rather than its name.
##
## Two filters, and both are load-bearing.
##
## It has to arrive AFTER the tiles. Every path that names a realm calls
## `sendImmediateLoadMap` and then `onPlayerJoin`; a refusal -- a purifying
## realm, a full dungeon -- sends its apology and returns without either. Take
## the first SYSTEM line of the wait and the caption becomes "Entering This
## realm has been purified ...", which reads as a destination.
##
## And it has to be addressed to us. `onPlayerJoin` sets `to` to the player's
## name, while the global announcements that land in the same window -- a
## player joining or leaving, an amulet shattering -- are broadcast with `to`
## empty, and a line addressed to someone else is about them. The web client
## reads any SYSTEM line at all here and takes whichever arrives first.
func apply_text(data: Dictionary) -> void:
	if not _naming or pending or String(data.get("from", "")) != ChatLog.SYSTEM:
		return
	if not _addressed_to_us(String(data.get("to", ""))):
		return
	zone = String(data.get("message", ""))
	_naming = false


func _addressed_to_us(to: String) -> bool:
	if to == "":
		return false
	# Before the first UpdatePacket we do not know our own name, and a line
	# addressed to anyone is better evidence than none.
	return to == _state.local.name or _state.local.name == ""


## Gives up on an answer that never arrived.
func expire() -> void:
	if not pending and not awaiting_snap and not _naming:
		return
	if _clock.call() - _started_ms <= MAX_WAIT_MS:
		return
	pending = false
	awaiting_snap = false
	_naming = false


## A realm or map change invalidates every entity we were holding: the
## server's delta ledger is per-realm and starts over.
##
## Except on the initial connect (realm 0), where the wipe would race the
## server's first LoadPacket and erase entities that have already landed --
## the native client records that as one to two seconds of empty map.
func apply_load_map(data: Dictionary) -> void:
	var connecting := _state.tiles.realm_id == 0
	var changed := _state.tiles.apply_load_map(data)
	if changed and not connecting:
		_state.entities.clear_but(_state.local.id)
		_state.projectiles.clear()
		_state.particles.clear()
	# Painted from the tiles just applied, so the lookup sees both layers.
	_state.minimap.apply_load_map(data, _state.tiles, changed)
	pending = false


## Adopts the first position the server states for us in the new realm.
##
## That correction is a teleport, not a mispredict; counting it as one would
## bury a real prediction bug in the noise, so the history goes with it. The
## native client snaps from the same flag, on the same packet.
func snap_local(data: Dictionary) -> void:
	if not awaiting_snap:
		return
	for entry in data.get("movements", []):
		if int(entry.get("entityType", 0)) != GameConstants.ENTITY_PLAYER:
			continue
		if int(entry.get("entityId", 0)) != _state.local.id:
			continue
		_state.local.position = Vector2(entry.get("posX", 0.0), entry.get("posY", 0.0))
		_state.local.smooth_offset = Vector2.ZERO
		_state.movement.clear_pending()
		awaiting_snap = false
		return
