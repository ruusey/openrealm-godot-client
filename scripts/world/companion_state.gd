class_name CompanionState
extends RefCounted

## The account's AI companions, as last sent by the server
## (CompanionRosterPacket: a JSON array of companions, each with class, stats,
## skill points, equipment and an active flag, plus the summon economy). Account-
## scoped, so RealmState keeps it across realms rather than clearing it on a
## transition.
##
## Only one companion deploys at a time, and it stays out until recalled; a short
## summon cooldown gates swapping. The cooldown (and any deploy expiry, 0 = none)
## arrive as server epoch-millisecond deadlines, read against the wall clock the
## same way party cooldowns are.

var roster: Array = []
## Owned/bench capacity: how many companions this account may save (1..20, bought
## with fame). Deploy-at-once cap is always 1. Defaults to 1 until the first roster.
var owned_cap := 1
const MAX_OWNED_CAP := 20
## The one deployed companion's uuid ("" = none out).
var deployed_uuid := ""
## Epoch ms the next summon is allowed (0 = ready), and the epoch ms the current
## deploy auto-recalls (0 = no expiry).
var summon_ready_at_ms := 0
var deployed_until_ms := 0
## Which companion the summon hotkey (C) targets. Defaults to the deployed one,
## else the first owned; a panel click overrides it.
var selected_uuid := ""
## Bumped on every change so the panel knows to rebuild.
var version := 0

## Server epoch ms is read against this; a scripted render pins it.
var wall_clock: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


func apply_roster(data: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(str(data.get("json", "[]")))
	roster = parsed if parsed is Array else []
	owned_cap = int(data.get("ownedCap", owned_cap))
	deployed_uuid = str(data.get("deployedUuid", ""))
	summon_ready_at_ms = int(data.get("summonReadyAtMs", 0))
	deployed_until_ms = int(data.get("deployedUntilMs", 0))
	# Keep the hotkey target valid: prefer the deployed one, else the first owned.
	if selected_uuid == "" or find(selected_uuid).is_empty():
		selected_uuid = deployed_uuid if deployed_uuid != "" else _first_uuid()
	version += 1


func count() -> int:
	return roster.size()


func active_count() -> int:
	return 1 if deployed_uuid != "" else 0


func find(uuid: String) -> Dictionary:
	for c in roster:
		if str(c.get("companionUuid", "")) == uuid:
			return c
	return {}


func _first_uuid() -> String:
	return str(roster[0].get("companionUuid", "")) if not roster.is_empty() else ""


## The companion the summon hotkey acts on (selected, else deployed, else first).
func target_uuid() -> String:
	if selected_uuid != "" and not find(selected_uuid).is_empty():
		return selected_uuid
	if deployed_uuid != "":
		return deployed_uuid
	return _first_uuid()


func is_deployed() -> bool:
	return deployed_uuid != ""


## True while the deployed companion has no expiry.
func deploy_never_expires() -> bool:
	return deployed_uuid != "" and deployed_until_ms == 0


func summon_ready() -> bool:
	return wall_clock.call() >= summon_ready_at_ms


## Ms until the next summon is allowed (0 once ready).
func summon_cooldown_remaining_ms() -> int:
	return max(0, summon_ready_at_ms - int(wall_clock.call()))


## Ms until the deployed companion auto-recalls (0 if not deployed or no expiry).
func deployed_remaining_ms() -> int:
	if deployed_uuid == "" or deployed_until_ms == 0:
		return 0
	return max(0, deployed_until_ms - int(wall_clock.call()))


func clear() -> void:
	roster = []
	deployed_uuid = ""
	summon_ready_at_ms = 0
	deployed_until_ms = 0
	version += 1
