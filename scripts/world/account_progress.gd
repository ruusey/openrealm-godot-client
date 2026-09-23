class_name AccountProgress
extends RefCounted

## What the account has earned that outlives a realm: the nine skill
## masteries (SkillsPacket) and the quest log with its star total
## (QuestStatePacket). Both are ours only, both arrive whole -- at login and
## whenever they change -- and neither is sent again on a realm change, so
## nothing here is cleared with the world.
##
## The quest log is the server's JSON, as the web client reads it:
## `{stars, quests: [{id, name, desc, cat, scoped, status, auto, repeatable,
## stars, objectives: [{label, progress, target}], rewards: [...]}]}`. A
## payload that does not parse empties the list rather than keeping a stale
## one, as the web's catch does.

const ACTIVE := "ACTIVE"
const AVAILABLE := "AVAILABLE"
const COMPLETE := "COMPLETE"

## XP per account-wide skill, by the server's ordinal (Mastery.SKILLS).
var mastery_xp: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0]
## The public quest score, shown on the HUD and under our name.
var stars := 0
var quests: Array = []
## Bumped on every change, so a view redraws only then.
var version := 0


func apply(name: String, data: Dictionary, local_id: int) -> void:
	if int(data.get("playerId", 0)) != local_id:
		return
	match name:
		"SkillsPacket":
			for index in Mastery.SKILLS.size():
				mastery_xp[index] = int(data.get("xp%d" % index, 0))
		"QuestStatePacket":
			stars = int(data.get("stars", 0))
			# A JSON of its own, not JSON.parse_string: a payload that does not
			# parse is an answer here, not an engine error on the console.
			var reader := JSON.new()
			var parsed: Variant = reader.data if reader.parse(String(data.get("json", ""))) == OK else null
			var list: Variant = parsed.get("quests") if parsed is Dictionary else null
			quests = list if list is Array else []
	version += 1


## Active first, then available, then complete, keeping the server's order
## within each -- the web's rank sort.
func sorted_quests() -> Array:
	var out: Array = []
	for status in [ACTIVE, AVAILABLE, COMPLETE]:
		for quest in quests:
			if status_of(quest) == status:
				out.append(quest)
	for quest in quests:
		if not status_of(quest) in [ACTIVE, AVAILABLE, COMPLETE]:
			out.append(quest)
	return out


## A quest's status, with the web's default for one that names none.
static func status_of(quest: Dictionary) -> String:
	return String(quest.get("status", AVAILABLE)).to_upper()
