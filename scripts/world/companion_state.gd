class_name CompanionState
extends RefCounted

## The account's AI companions, as last sent by the server
## (CompanionRosterPacket: a JSON array of companions, each with class, stats,
## skill points, equipment and an active flag). Account-scoped, so RealmState
## keeps it across realms rather than clearing it on a transition.

var roster: Array = []
## Bumped on every change so the panel knows to rebuild.
var version := 0


func apply_roster(data: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(str(data.get("json", "[]")))
	roster = parsed if parsed is Array else []
	version += 1


func count() -> int:
	return roster.size()


func active_count() -> int:
	var n := 0
	for c in roster:
		if bool(c.get("active", false)):
			n += 1
	return n


func find(uuid: String) -> Dictionary:
	for c in roster:
		if str(c.get("companionUuid", "")) == uuid:
			return c
	return {}


func clear() -> void:
	roster = []
	version += 1
