extends GutTest

## The options: what each switch hides, that a choice is kept, and the
## panel's controls.

const PATH := "user://test_settings.cfg"

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_each():
	SpriteOutline.enabled = true
	WallBandPass.enabled = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_every_switch_starts_on_and_a_choice_is_kept():
	for table in [GameSettings.DISPLAY, GameSettings.GRAPHICS]:
		for key in table:
			assert_true(state.settings.is_on(key), key)
	state.settings.load_from(PATH)
	state.settings.set_on("show_names", false)
	state.settings.set_on("vsync", false)
	var again := GameSettings.new()
	again.load_from(PATH)
	assert_false(again.is_on("show_names"), "read back by a new session")
	assert_false(again.is_on("vsync"))
	assert_true(again.is_on("show_chat_bubbles"), "untouched ones keep their default")


func test_an_empty_path_keeps_nothing():
	state.settings.set_on("show_names", false)
	assert_false(FileAccess.file_exists(PATH), "a test's settings never reach the disk")
	assert_false(state.settings.is_on("show_names"), "but still apply")


func test_outlines_and_wall_bands_follow_their_switches():
	state.settings.set_on("sprite_outlines", false)
	assert_false(SpriteOutline.enabled)
	state.settings.set_on("wall_bands", false)
	assert_false(WallBandPass.enabled)
	state.settings.set_on("sprite_outlines", true)
	assert_true(SpriteOutline.enabled)


func test_other_players_bullets_hide_but_ours_and_enemies_never_do():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO),
		WireHelper.player(2, "them", Vector2(10, 0))]})
	var theirs := {"src_entity_id": 2}
	var ours := {"src_entity_id": 1}
	var enemy := {"src_entity_id": 77}
	assert_false(BulletRenderer._hidden(state, theirs), "on by default")
	state.settings.set_on("show_other_bullets", false)
	assert_true(BulletRenderer._hidden(state, theirs))
	assert_false(BulletRenderer._hidden(state, ours))
	assert_false(BulletRenderer._hidden(state, enemy))


func test_ability_effects_by_owner_and_all_at_once():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO),
		WireHelper.player(2, "them", Vector2(10, 0))]})
	var theirs := {"owner": 2}
	var ours := {"owner": 1}
	var boss := {"owner": 500}
	state.settings.set_on("show_ally_effects", false)
	assert_false(EffectRenderer.shown(state, theirs))
	assert_true(EffectRenderer.shown(state, ours))
	assert_true(EffectRenderer.shown(state, boss), "an enemy's warning always shows")
	state.settings.set_on("ability_animations", false)
	assert_false(EffectRenderer.shown(state, ours), "all animations off: even ours")
	assert_false(EffectRenderer.shown(state, boss))


func test_other_players_leave_the_ground_pass_and_the_overlay():
	state.local.position = Vector2.ZERO
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO),
		WireHelper.player(2, "them", Vector2(10, 0))]})
	var view := Rect2(-500, -500, 1000, 1000)
	var players := func() -> int:
		return EntityQueue.new().build(state, content, view).filter(
			func(e: Dictionary) -> bool: return e["kind"] == "players").size()
	assert_eq(players.call(), 2)
	state.settings.set_on("show_other_players", false)
	assert_eq(players.call(), 1, "only ourselves")


func test_the_overlay_drops_names_chips_bubbles_and_numbers():
	var overlay := EntityOverlay.new()
	overlay.setup(state)
	add_child_autofree(overlay)
	await wait_process_frames(1)
	state.local.name = "Ruu"
	state.local.effects = [4]
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO)]})
	state.apply_packet("TextPacket", {"from": "Ruu", "to": "Player", "message": "hello"})
	state.apply_packet("TextEffectPacket", {"textEffectId": 0, "entityType": 1, "targetEntityId": 0,
		"text": "-5", "posX": 1.0, "posY": 1.0})
	overlay.refresh()
	var tag: EntityTag = overlay._tags.acquire(["player", 1])
	assert_true(tag._name.visible)
	assert_gt(overlay.chips, 0)
	assert_eq(overlay.bubbles, 1)
	assert_eq(overlay._labels.texts, 1)
	for key in ["show_names", "show_status_chips", "show_chat_bubbles", "show_damage_numbers"]:
		state.settings.set_on(key, false)
	overlay.refresh()
	assert_false(tag._name.visible, "no name")
	assert_eq(overlay.chips, 0, "no chips")
	assert_eq(overlay.bubbles, 0, "no bubble")
	assert_eq(overlay._labels.texts, 0, "no numbers")


func test_the_transition_cover_can_be_switched_off():
	var screen := TransitionScreen.new()
	screen.setup(state, content)
	add_child_autofree(screen)
	state.begin_transition()
	screen._process(0.1)
	assert_true(screen.visible)
	state.settings.set_on("show_transition_screen", false)
	screen._process(0.1)
	assert_false(screen.visible)


func test_the_panel_has_a_box_a_setting_and_a_click_flips_it():
	var panel := OptionsPanel.new()
	panel.setup(state.settings, null)
	add_child_autofree(panel)
	await wait_process_frames(1)
	assert_eq(panel.boxes.size(), GameSettings.DISPLAY.size() + GameSettings.GRAPHICS.size())
	assert_true(panel.boxes["vsync"].button_pressed)
	panel.boxes["vsync"].button_pressed = false
	assert_false(state.settings.is_on("vsync"), "the click is the setting")
	state.settings.set_on("show_names", false)
	panel.refresh()
	assert_false(panel.boxes["show_names"].button_pressed, "and the boxes follow the settings")
	panel.toggle()
	panel._process(0.0)
	assert_false(panel.visible, "never up outside a realm")


func test_an_unknown_or_unchanged_switch_does_nothing():
	var told := [0]
	state.settings.changed.connect(func() -> void: told[0] += 1)
	state.settings.set_on("no_such_setting", false)
	state.settings.set_on("show_names", true)
	assert_eq(told[0], 0, "nothing changed, so nothing is said or saved")
	assert_true(state.settings.is_on("no_such_setting"), "an unknown key reads as on, as a default would")
	state.settings.set_on("show_names", false)
	assert_eq(told[0], 1)
