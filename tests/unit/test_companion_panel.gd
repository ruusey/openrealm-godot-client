extends GutTest

## The companion panel: its stats against the class caps, the stat-potion box that
## only lights for a stat potion, the class preview, and the deploy readouts.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content)
	state.local.id = 7
	state.local.class_id = 0
	state.companions.apply_roster({"json": JSON.stringify([{"companionUuid": "a", "characterClass": 2,
		"companionName": "Bob", "stats": {"hp": 670, "mp": 100, "def": 3, "availableSkillPoints": 2,
		"abilitySkillPoints": {}}, "items": []}]), "ownedCap": 3, "deployedUuid": "a"})


func _open() -> CompanionPanel:
	var panel := CompanionPanel.new()
	panel.setup(state, content, null)
	add_child_autofree(panel)
	panel.toggle()
	panel._process(0.0)
	return panel


func _texts(panel: CompanionPanel) -> Array:
	return panel.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func test_stats_read_against_the_class_caps():
	var texts := _texts(_open())
	assert_true("HP 670" in texts, "a maxed stat is just its value")
	assert_true("MP 100/385 (+285)" in texts, "any other shows its cap and what is left")
	assert_true("Stats  (1/8 maxed)" in texts)


func test_a_nexus_deploy_has_no_time_limit():
	assert_eq(_open()._status.text, "Deployed in the Nexus - no time limit here")
	var cell := CompanionSummonCell.new()
	add_child_autofree(cell)
	cell.update_from(state.companions)
	assert_eq(cell._text.text, "Recall\n(C)")


func test_a_deploy_counts_down_to_its_return_and_then_the_cooldown():
	state.companions.wall_clock = func() -> int: return 1_000_000
	state.companions.deployed_until_ms = 1_000_000 + 272_000
	state.companions.summon_ready_at_ms = 1_000_000 + 572_000
	assert_eq(_open()._status.text, "Deployed - 4:32 until it returns home")
	var cell := CompanionSummonCell.new()
	add_child_autofree(cell)
	cell.update_from(state.companions)
	assert_eq(cell._text.text, "Recall\n4:32")
	var phone: TouchCluster = autofree(TouchCluster.new(true))
	phone._show_companion(state.companions)
	assert_eq(phone._companion.text, "Recall\n4:32")
	state.companions.deployed_uuid = ""
	cell.update_from(state.companions)
	assert_eq(cell._text.text, "Summon\n9:32")
	phone._show_companion(state.companions)
	assert_eq(phone._companion.text, "9:32")


func test_the_class_preview_lists_the_kit():
	var texts := _texts(_open())
	assert_true("Passive: Arcane Well" in texts)
	assert_true("1: Fire Breath" in texts)


func test_a_missed_drop_is_caught_and_only_a_stat_potion_feeds():
	var panel := _open()
	assert_true(panel._root is InventoryLayout.DropSink, "a release on the panel is not a throw")
	var drop: CompanionStatDrop = panel.find_children("*", "CompanionStatDrop", true, false)[0]
	state.local.inventory.put(6, {"itemId": 104})
	assert_true(drop._can_drop_data(Vector2.ZERO, {"slot": 6}), "taken, so it is not thrown")
	assert_false(drop._accepted({"slot": 6}), "but gear does not feed")
	assert_true(CompanionStatDrop.is_stat_potion({"consumable": true, "stats": {"def": 1}}))
	assert_false(CompanionStatDrop.is_stat_potion({"consumable": true, "stats": {"hp": 0}}), "an HP potion")
	assert_false(CompanionStatDrop.is_stat_potion({"consumable": false, "stats": {"dex": 4}}), "a ring")
