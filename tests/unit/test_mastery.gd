extends GutTest

## The Skills window: the server's curve, the XP off SkillsPacket, and the
## panel that shows it.

var state: RealmState


func before_each():
	state = RealmState.new()
	state.local.id = 7


func _skills(player_id: int, xp: Array) -> Dictionary:
	var data := {"playerId": player_id}
	for index in xp.size():
		data["xp%d" % index] = xp[index]
	return data


func test_the_curve_is_the_servers():
	assert_eq(Mastery.total_xp_for_level(0), 0)
	assert_eq(Mastery.total_xp_for_level(1), 510)
	assert_eq(Mastery.total_xp_for_level(2), 2040)
	assert_eq(Mastery.total_xp_for_level(99), 4998510)
	assert_eq(Mastery.total_xp_for_level(120), 4998510, "capped at 99")


func test_a_level_starts_exactly_at_its_total():
	assert_eq(Mastery.level_for_xp(0), 0)
	assert_eq(Mastery.level_for_xp(509), 0)
	assert_eq(Mastery.level_for_xp(510), 1)
	assert_eq(Mastery.level_for_xp(2039), 1)
	assert_eq(Mastery.level_for_xp(2040), 2)
	assert_eq(Mastery.level_for_xp(4998509), 98)
	assert_eq(Mastery.level_for_xp(4998510), 99)
	assert_eq(Mastery.level_for_xp(90000000), 99)


func test_the_bar_is_the_way_into_the_level():
	assert_eq(Mastery.progress(0), 0.0)
	assert_almost_eq(Mastery.progress(1275), 0.5, 0.001, "halfway from 510 to 2040")
	assert_eq(Mastery.progress(4998510), 1.0, "full at the cap")


func test_the_hover_card_is_the_webs():
	var card := Mastery.describe(0, 2040)
	assert_string_contains(card, "Damage with ranged (light) weapons.")
	assert_string_contains(card, "Effect: +0.1% ranged damage / level")
	assert_string_contains(card, "Now: +0.2% ranged damage")
	assert_string_contains(card, "Current XP: 2,040")
	assert_string_contains(card, "Next level: 4,590 XP")
	assert_string_contains(card, "Remaining: 2,550 XP")
	assert_string_contains(Mastery.describe(6, 0), "+0.15% ally buff duration / level")
	assert_string_contains(Mastery.describe(8, 4998510), "Max level reached")


func test_skills_packet_is_ours_only_and_survives_a_realm_change():
	state.apply_packet("SkillsPacket", _skills(99, [5, 5, 5, 5, 5, 5, 5, 5, 5]))
	assert_eq(state.progress.mastery_xp[0], 0, "someone else's")
	state.apply_packet("SkillsPacket", _skills(7, [510, 1, 2, 3, 4, 5, 6, 7, 2040]))
	assert_eq(state.progress.mastery_xp, [510, 1, 2, 3, 4, 5, 6, 7, 2040])
	state.reset_world()
	assert_eq(state.progress.mastery_xp[8], 2040, "the server does not send it again on arrival")


func test_the_panel_shows_each_skill_and_follows_the_packet():
	var panel := MasteryPanel.new()
	panel.setup(state)
	add_child_autofree(panel)
	await wait_process_frames(1)
	panel._process(0.0)
	assert_false(panel.visible, "shut until asked for")
	panel.toggle()
	panel._process(0.0)
	assert_true(panel.visible)
	assert_eq(panel._cells.size(), 9)
	assert_eq(panel._cells[0][1].text, "Level 0 / 99")
	state.apply_packet("SkillsPacket", _skills(7, [2040, 0, 0, 0, 0, 0, 0, 0, 4998510]))
	panel._process(0.0)
	assert_eq(panel._cells[0][1].text, "Level 2 / 99")
	assert_eq(panel._cells[8][1].text, "Level 99 / 99")
	assert_eq(panel._cells[8][2].value, 1.0)
	assert_string_contains(panel._cells[0][0].tooltip_text, "Remaining: 2,550 XP")
	panel.close()
	panel._process(0.0)
	assert_false(panel.visible)


func test_its_key_opens_it_in_a_realm_only():
	var panel := MasteryPanel.new()
	panel.setup(state)
	add_child_autofree(panel)
	await wait_process_frames(1)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	panel._unhandled_input(key)
	assert_true(panel.shown, "J, the default")
	panel._unhandled_input(key)
	assert_false(panel.shown)
	state.local.id = 0
	panel._unhandled_input(key)
	assert_false(panel.shown, "not from the sign-in screen")
	assert_true(KeyBindings.ACTIONS.has("toggle_masteries"), "and it can be rebound")
