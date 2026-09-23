extends GutTest

## The realm's name and difficulty along the top, and its cleansing.

var data: GameData
var state: RealmState
var banner: RealmBanner


func before_each():
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(data, func() -> int: return 0)
	banner = RealmBanner.new()
	banner.setup(state, data)
	add_child_autofree(banner)


func _land(map_id: int) -> void:
	state.local.id = 1
	state.apply_packet("LoadMapPacket", {"realmId": 5, "mapId": map_id, "tiles": [WireHelper.tile(1, 0, 0, 0)]})


func test_named_after_the_map_once_we_are_in_one():
	banner._process(0.0)
	assert_false(banner.visible, "no player")
	_land(31)
	banner._process(0.0)
	assert_true(banner.visible)
	assert_eq(banner._name.text, "Nexus Auru V1", "the fixture's map 31, underscores dropped")
	assert_false(banner._detail.visible, "nothing to say about purification")


func test_the_servers_name_wins_and_a_dungeon_has_no_other():
	_land(31)
	state.begin_transition()
	banner._process(0.0)
	assert_false(banner.visible, "not while entering")
	state.apply_packet("LoadMapPacket", {"realmId": 6, "mapId": -1, "dungeonId": 1, "tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("TextPacket", {"from": "SYSTEM", "to": "Ruu", "message": "Inferno Cavern"})
	banner._process(0.0)
	assert_eq(banner._name.text, "Inferno Cavern")


func test_the_difficulty_colours_the_name():
	_land(31)
	state.apply_packet("RealmPurificationPacket", {"realmId": 5, "progress": 0, "goal": 0, "difficulty": 2.5, "tier": 1, "modifiers": ""})
	banner._process(0.0)
	assert_eq(banner._name.text, "Nexus Auru V1   2.5")
	assert_eq(banner._name.get_theme_color("font_color"), Color8(180, 160, 40))
	assert_false(banner._detail.visible, "no goal, no purification line")
	assert_eq(RealmBanner.difficulty_colour(1.0), Color8(60, 180, 60))
	assert_eq(RealmBanner.difficulty_colour(6.0), Color8(220, 80, 40))
	assert_eq(RealmBanner.difficulty_colour(9.0), Color8(255, 40, 40))


func test_the_purification_line_while_there_is_a_goal():
	_land(31)
	state.apply_packet("RealmPurificationPacket", {"realmId": 5, "progress": 43, "goal": 100, "difficulty": 4.0, "tier": 2, "modifiers": "Frenzy, Fog"})
	banner._process(0.0)
	assert_true(banner._detail.visible)
	assert_eq(banner._detail.text, "Tier 2 - Purification 43%  -  Frenzy, Fog")
	assert_eq(RealmBanner.purification({"progress": 7, "goal": 10, "tier": 1}), "Realm Purification - 70%")
	assert_eq(RealmBanner.purification({"progress": 7, "goal": 0}), "")
	state.begin_transition()
	assert_eq(state.minimap.realm, {}, "the next realm starts unknown")


func test_does_nothing_without_a_state():
	var bare := RealmBanner.new()
	add_child_autofree(bare)
	bare.visible = true
	bare._process(0.0)
	assert_false(bare.visible)
