class_name PartyState
extends RefCounted

## The party you are in, and the invite waiting for an answer.
##
## PartyUpdatePacket is the whole roster every time -- at most four, sent
## about twice a second and on every change -- with the leader's id; a
## partyId of 0 is the server saying you are in no party now, which is how
## leaving, a kick and a disband all arrive. An invite arrives as a SYSTEM
## line, "<name> invited you to a party. Type /party accept or /party
## decline.", which both references sniff for their prompt; it stands for
## the server's sixty seconds (PartyManager.INVITE_TIMEOUT_MS). A teammate's
## cooldown ends are epoch milliseconds, the server's clock, so they are
## read against the wall clock and not the tick clock the rest of the
## state runs on.

const MAX_SIZE := 4
const INVITE_TTL_MS := 60_000
const INVITE_MARK := " invited you to a party"
## SYSTEM lines that mean the invite is answered or gone.
const INVITE_OVER := ["Joined party.", "Invite declined.", "No pending party invite (or it expired).",
	"No pending party invite."]

var party_id := 0
var leader_id := 0
var members: Array = []
var invite_from := ""
## Bumped on every roster change, so a panel can rebuild only then.
var version := 0

var _clock: Callable
## The server's epoch milliseconds are read against this; a scripted render pins it.
var wall_clock: Callable
var _invite_at := 0


func _init(clock: Callable = func() -> int: return Time.get_ticks_msec(),
		wall: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)) -> void:
	_clock = clock
	wall_clock = wall


func clear() -> void:
	party_id = 0
	leader_id = 0
	members = []
	invite_from = ""
	version += 1


func apply_update(data: Dictionary) -> void:
	party_id = int(data.get("partyId", 0))
	leader_id = int(data.get("leaderId", 0)) if party_id != 0 else 0
	members = data.get("members", []) if party_id != 0 else []
	version += 1


func apply_text(data: Dictionary) -> void:
	if String(data.get("from", "")) != ChatLog.SYSTEM:
		return
	var message := String(data.get("message", ""))
	var mark := message.find(INVITE_MARK)
	if mark > 0:
		invite_from = message.left(mark)
		_invite_at = _clock.call()
	elif message in INVITE_OVER:
		invite_from = ""


func expire() -> void:
	if invite_from != "" and _clock.call() - _invite_at >= INVITE_TTL_MS:
		invite_from = ""


func in_party() -> bool:
	return party_id != 0 and not members.is_empty()


func is_leader(player_id: int) -> bool:
	return in_party() and leader_id == player_id


## Everyone but the given player, in the server's order.
func others(player_id: int) -> Array:
	return members.filter(func(m: Dictionary) -> bool: return int(m.get("playerId", 0)) != player_id)


func member_ids() -> Array:
	return members.map(func(m: Dictionary) -> int: return int(m.get("playerId", 0)))


## What is left of a teammate's cooldown in a hotbar slot, 1 at its start
## and 0 once it has run, against a cooldown of `total_ms`: the web
## client's overlay height, from the server's epoch-millisecond end.
func cooldown_fraction(member: Dictionary, slot: int, total_ms: int) -> float:
	var ends: Array = member.get("abilityCooldownEnds", [])
	if total_ms <= 0 or slot < 0 or slot >= ends.size():
		return 0.0
	var remaining := int(ends[slot]) - int(wall_clock.call())
	return clampf(float(remaining) / float(total_ms), 0.0, 1.0)
