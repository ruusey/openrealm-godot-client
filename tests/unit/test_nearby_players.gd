extends GutTest

## Who is listed as nearby, the colour a name takes, and the tooltip.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 1


func _load(players: Array) -> void:
	state.apply_packet("LoadPacket", {"players": players})


func test_everyone_in_the_roster_but_you_and_your_party_at_most_sixteen():
	var players: Array = [WireHelper.player(1, "Ruu", Vector2.ZERO)]
	for i in range(2, 22):
		players.append(WireHelper.player(i, "P%d" % i, Vector2(i, 0)))
	_load(players)
	var listed := NearbyPlayers.list(state.entities, 1)
	assert_eq(listed.size(), 16, "capped at sixteen")
	assert_eq(listed[0]["name"], "P2", "in the roster's order, never ourselves")
	listed = NearbyPlayers.list(state.entities, 1, [2, 3])
	assert_eq(listed[0]["name"], "P4", "a party member has a row of its own")
	assert_eq(NearbyPlayers.list(state.entities, 99).size(), 16)


func test_a_name_takes_its_roles_colour_and_an_admin_is_bold():
	assert_eq(NearbyPlayers.role_colour("sysadmin"), Color("ff4040"))
	assert_eq(NearbyPlayers.role_colour("admin"), Color("4080e0"))
	assert_eq(NearbyPlayers.role_colour("mod"), Color("40c040"))
	assert_eq(NearbyPlayers.role_colour("editor"), Color("a040c0"))
	assert_eq(NearbyPlayers.role_colour("demo"), Color("cccccc"))
	assert_eq(NearbyPlayers.role_colour(""), Color("eeeeee"))
	assert_eq(NearbyPlayers.role_colour("stranger"), Color("eeeeee"))
	assert_true(NearbyPlayers.bold("admin"))
	assert_true(NearbyPlayers.bold("sysadmin"))
	assert_false(NearbyPlayers.bold("mod"))


func test_the_tooltip_is_the_webs_header_with_the_level_from_the_experience():
	var wire := WireHelper.player(2, "Mingau", Vector2.ZERO, 0, 2)
	wire["chatRole"] = "mod"
	_load([wire])
	var player: Dictionary = state.entities.players[2]
	assert_eq(NearbyPlayers.tooltip(player, content), "Mingau  [mod]\nLv ? Wizard\nHP: 0/0\nMP: 0/0",
		"no UpdatePacket yet: no experience, no level")
	state.apply_packet("UpdatePacket", {"playerId": 2, "playerName": "Mingau", "stats": {"hp": 320, "mp": 140},
		"health": 250, "mana": 90, "experience": 200, "inventory": [], "hpPotions": 0, "mpPotions": 0, "dyeId": 0})
	assert_eq(player.get("experience", -1), 200, "PlayerSync keeps a remote's experience")
	assert_eq(NearbyPlayers.tooltip(player, content), "Mingau  [mod]\nLv 2 Wizard\nHP: 250/320\nMP: 90/140")
	var plain := WireHelper.player(3, "", Vector2.ZERO, 0, 0)
	_load([plain])
	assert_eq(NearbyPlayers.tooltip(state.entities.players[3], content).split("\n")[0], "Barbarian",
		"no name and no role: the class stands in, no badge")


func test_chat_colours_a_sender_by_name_then_role_then_its_own_blue():
	assert_eq(NameColours.chat_sender("Zed", "mod"), Color("40c040"))
	assert_eq(NameColours.chat_sender("Zed", ""), Color("4080e0"), "chat's default is blue")
	assert_eq(NameColours.chat_sender("Zed", "Ruu"), Color("4080e0"), "a recipient's name is no role")
	assert_eq(NameColours.chat_sender("Overseer", "sysadmin"), Color("e8c840"), "the name wins")
	assert_eq(NameColours.chat_sender("SYSTEM", ""), Color("c8a86e"))


func test_over_a_head_you_are_green_until_you_hold_a_role():
	var green := Color(0.6, 1.0, 0.6)
	assert_eq(NameColours.over_head("", true, green), green)
	assert_eq(NameColours.over_head("stranger", true, green), green, "an unknown role is no role")
	assert_eq(NameColours.over_head("admin", true, green), Color("4080e0"))
	assert_eq(NameColours.over_head("", false, green), Color("eeeeee"))
	assert_eq(NameColours.over_head("demo", false, green), Color("cccccc"))
