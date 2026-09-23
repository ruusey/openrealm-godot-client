class_name LifetimeStats
extends RefCounted

## A character's lifetime metrics as the web client's stats card lays them
## out (`_renderCharacterStats`): four sections of label and value in its
## order, then the dungeons completed, most first.
##
## Pure: the report in, rows of text out. Every counter the service has not
## seen yet is absent or zero -- a never-played character gets an all-zero
## report, not an error -- so each reads as 0 rather than failing.

const DUNGEONS := "Dungeon completions"
const NONE_YET := "None yet."


## [[title, [[label, value], ...]], ...], values already formatted.
static func sections(m: Dictionary) -> Array:
	var hit := _n(m, "projectilesHit")
	var shots := hit + _n(m, "projectilesMissed")
	var kills := _n(m, "killsTotal")
	var deaths := _n(m, "deaths")
	var pvp := _n(m, "pvpMatches")
	return [
		["Combat", [
			["Shots fired", count(m, "projectilesFired")],
			["Shots hit", count(m, "projectilesHit")],
			["Shots missed", count(m, "projectilesMissed")],
			["Accuracy", percent(hit, shots)],
			["Damage dealt", count(m, "damageDealtTotal")],
			["Damage taken", count(m, "damageTakenTotal")],
			["Kills", count(m, "killsTotal")],
			["Boss kills", count(m, "bossKills")],
			["Deaths", count(m, "deaths")],
			["K/D ratio", "%.2f" % (float(kills) / deaths) if deaths > 0 else grouped(kills)],
		]],
		["Abilities", [
			["Ability casts", count(m, "abilityCastsTotal")],
			["Ability damage", count(m, "abilityDamageDealt")],
			["Enemies affected", count(m, "abilityEnemiesAffected")],
			["Allies affected", count(m, "abilityAlliesAffected")],
			["Ally buff seconds", count(m, "abilityBuffSecondsAlly")],
			["Enemy debuff seconds", count(m, "abilityDebuffSecondsEnemy")],
			["Friendly debuff seconds", count(m, "abilityDebuffSecondsFriendly")],
		]],
		["Items & Progression", [
			["Loot picked up", count(m, "itemsPickedUp")],
			["Items enchanted", count(m, "itemsEnchanted")],
			["HP potions drank", count(m, "hpPotionsDrank")],
			["MP potions drank", count(m, "mpPotionsDrank")],
			["XP earned", count(m, "xpEarned")],
			["Skill points spent", count(m, "skillPointsSpent")],
		]],
		["Social & PvP", [
			["Time played", "%s min" % grouped(roundi(_n(m, "playTimeSeconds") / 60.0))],
			["Trades", count(m, "tradesCompleted")],
			["Chat messages", count(m, "chatMessagesSent")],
			["PvP matches", count(m, "pvpMatches")],
			["PvP wins", count(m, "pvpWins")],
			["PvP losses", count(m, "pvpLosses")],
			["PvP win rate", percent(_n(m, "pvpWins"), pvp)],
		]],
	]


## ["Dungeon <id>", count] per dungeon, the most completed first; empty
## when there are none, which the card shows as NONE_YET.
static func dungeons(m: Dictionary) -> Array:
	var by_id = m.get("dungeonCompletionsByDungeonId")
	var rows: Array = []
	if not by_id is Dictionary:
		return rows
	for id in by_id:
		rows.append(["Dungeon %s" % id, int(by_id[id])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return rows.map(func(row: Array) -> Array: return [row[0], grouped(row[1])])


static func count(m: Dictionary, key: String) -> String:
	return grouped(_n(m, key))


## A whole number with thousands separators, as toLocaleString writes it.
static func grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## "-" when there is nothing to divide by, as the web client shows it.
static func percent(part: int, whole: int) -> String:
	return "%d%%" % roundi(part * 100.0 / whole) if whole > 0 else "-"


## A counter as an int: JSON numbers arrive as floats, a missing or null
## one is zero.
static func _n(m: Dictionary, key: String) -> int:
	var value = m.get(key)
	return int(value) if value is float or value is int else 0
