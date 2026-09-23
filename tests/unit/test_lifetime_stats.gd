extends GutTest

## LifetimeStats: the web client's stats card, as rows of text.

const REPORT := {
	"projectilesFired": 12345.0, "projectilesHit": 300.0, "projectilesMissed": 100.0,
	"damageDealtTotal": 1234567.0, "damageTakenTotal": 999.0, "killsTotal": 7.0,
	"bossKills": 1.0, "deaths": 2.0, "abilityCastsTotal": 40.0, "playTimeSeconds": 5430.0,
	"pvpMatches": 3.0, "pvpWins": 2.0, "xpEarned": 1000.0,
	"dungeonCompletionsByDungeonId": {"1": 2.0, "5": 9.0, "3": 4.0},
}


func _value(sections: Array, label: String) -> String:
	for section in sections:
		for row in section[1]:
			if row[0] == label:
				return row[1]
	return "<missing %s>" % label


func test_sections_come_in_the_web_clients_order():
	var sections := LifetimeStats.sections(REPORT)
	assert_eq(sections.map(func(s: Array) -> String: return s[0]),
		["Combat", "Abilities", "Items & Progression", "Social & PvP"])
	assert_eq(sections[0][1].map(func(r: Array) -> String: return r[0]), ["Shots fired",
		"Shots hit", "Shots missed", "Accuracy", "Damage dealt", "Damage taken", "Kills",
		"Boss kills", "Deaths", "K/D ratio"])
	assert_eq(sections[1][1].size(), 7)
	assert_eq(sections[2][1].size(), 6)
	assert_eq(sections[3][1].size(), 7)


func test_counts_are_grouped_by_thousands():
	var sections := LifetimeStats.sections(REPORT)
	assert_eq(_value(sections, "Shots fired"), "12,345")
	assert_eq(_value(sections, "Damage dealt"), "1,234,567")
	assert_eq(_value(sections, "Damage taken"), "999")
	assert_eq(_value(sections, "XP earned"), "1,000")
	assert_eq(LifetimeStats.grouped(-1234), "-1,234")
	assert_eq(LifetimeStats.grouped(0), "0")


func test_the_derived_rows():
	var sections := LifetimeStats.sections(REPORT)
	assert_eq(_value(sections, "Accuracy"), "75%", "hit over hit and missed")
	assert_eq(_value(sections, "K/D ratio"), "3.50")
	assert_eq(_value(sections, "Time played"), "91 min", "5430 s rounds to 91")
	assert_eq(_value(sections, "PvP win rate"), "67%")


func test_a_never_played_character_reads_as_zeros_and_dashes():
	var sections := LifetimeStats.sections({"killsTotal": null})
	assert_eq(_value(sections, "Kills"), "0", "a null counter is zero")
	assert_eq(_value(sections, "Accuracy"), "-", "nothing to divide by")
	assert_eq(_value(sections, "PvP win rate"), "-")
	assert_eq(_value(sections, "Time played"), "0 min")
	assert_eq(LifetimeStats.dungeons({}), [])


func test_no_deaths_shows_the_kills_as_the_ratio():
	assert_eq(_value(LifetimeStats.sections({"killsTotal": 1500.0}), "K/D ratio"), "1,500")


func test_dungeons_are_listed_most_completed_first():
	assert_eq(LifetimeStats.dungeons(REPORT), [
		["Dungeon 5", "9"], ["Dungeon 3", "4"], ["Dungeon 1", "2"]])
	assert_eq(LifetimeStats.dungeons({"dungeonCompletionsByDungeonId": null}), [])
