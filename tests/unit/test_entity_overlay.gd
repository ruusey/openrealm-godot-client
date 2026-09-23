extends GutTest

## The UI pinned to the world: tags, captions and numbers as pooled Controls.

var state: RealmState
var overlay: EntityOverlay
var now := 5000


func before_each():
	now = 5000
	state = RealmState.new(null, func() -> int: return now)
	overlay = EntityOverlay.new()
	overlay.setup(state)
	add_child_autofree(overlay)


func _tag(kind: String, id: int) -> EntityTag:
	return overlay._tags._live.get([kind, id])


func test_a_player_gets_a_tag_at_its_screen_position_with_the_web_clients_layout():
	state.local.id = 1
	state.local.name = "Ruu"
	state.local.health = 50
	state.local.mana = 25
	state.local.stats = {"hp": 100, "mp": 50}
	state.local.position = Vector2(10.3, 20.6)
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "", Vector2.ZERO)]})
	overlay.refresh()
	var tag := _tag("player", 1)
	assert_not_null(tag)
	assert_eq(tag.position, Vector2(10.0, 21.0), "the world point on a whole pixel (no camera: 1x)")
	assert_eq(tag.size, Vector2(32.0, 32.0), "PLAYER_RENDER_SIZE at 1x")
	assert_eq(tag._name.text, "Ruu")
	# What draws is the LabelSettings colour -- a theme override is ignored --
	# which is how the local green once passed here and drew white.
	assert_eq(tag._name.label_settings.font_color, Color(0.6, 1.0, 0.6), "our own name, green")
	assert_eq(tag._name.label_settings.font_size, 16)
	assert_eq(tag._name.label_settings.outline_size, 3)
	assert_eq(tag._hp_back.position, Vector2(0.0, 32.0 + EntityTag.BAR_DROP))
	assert_eq(tag._hp.size, Vector2(16.0, EntityTag.BAR_HEIGHT), "half health, half width")
	assert_eq(tag._mp.size, Vector2(16.0, EntityTag.BAR_HEIGHT))
	assert_lt(tag._name.position.y + tag._name.size.y, tag._hp_back.position.y, "the name sits over the bars")


func test_a_remote_player_is_named_from_the_roster_in_off_white_and_culled_off_camera():
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO),
		WireHelper.player(2, "Mingau", Vector2(40, 0)), WireHelper.player(3, "Far", Vector2(9000, 9000))]})
	overlay.refresh()
	assert_eq(overlay.tag_count(), 2, "the far one has no tag")
	assert_eq(_tag("player", 2)._name.text, "Mingau")
	assert_eq(_tag("player", 2)._name.label_settings.font_color, Color("eeeeee"), "the web's no-role colour")
	assert_same(_tag("player", 2)._name.label_settings, EntityTag.name_settings(Color("eeeeee")),
		"one style a colour, shared by every tag")
	assert_null(_tag("player", 3))


func test_a_name_over_a_head_is_its_chat_roles_colour_ours_included():
	state.local.id = 1
	var us := WireHelper.player(1, "Ruu", Vector2.ZERO)
	var mod := WireHelper.player(2, "Mingau", Vector2(40, 0))
	mod["chatRole"] = "mod"
	state.apply_packet("LoadPacket", {"players": [us, mod]})
	overlay.refresh()
	assert_eq(_tag("player", 2)._name.label_settings.font_color, Color("40c040"), "a moderator, green")
	assert_eq(_tag("player", 1)._name.label_settings.font_color, Color(0.6, 1.0, 0.6), "no role: our own green")
	us["chatRole"] = "sysadmin"
	state.apply_packet("LoadPacket", {"players": [us]})
	overlay.refresh()
	assert_eq(_tag("player", 1)._name.label_settings.font_color, Color("ff4040"),
		"a role outranks our green, as the web shows an admin their own colour")


func test_chips_stack_over_the_head_in_table_order_and_are_counted():
	state.local.id = 1
	state.local.stats = {"hp": 100, "mp": 50}
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO),
		WireHelper.player(2, "You", Vector2(40, 0))]})
	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 50, "mana": 10,
		"effectIds": [6, 17], "effectTimes": [], "effectStacks": [1, 3]})
	state.apply_packet("PlayerStatePacket", {"playerId": 2, "health": 50, "mana": 10,
		"effectIds": [21], "effectTimes": [], "effectStacks": [1]})
	overlay.refresh()
	assert_eq(overlay.chips, 3, "two on us, one on them")
	var head: HeadStack = _tag("player", 1)._head
	assert_eq(head._chips.get_child(0).get_child(0).text, "Invuln")
	assert_eq(head._chips.get_child(1).get_child(0).text, "Pois x3")
	assert_eq(head._chips.get_child(0).custom_minimum_size, HeadStack.CHIP_SIZE)
	assert_lt(head._chips.position.y, 0.0, "stacked upward from the head")
	assert_eq(head.position, Vector2(16.0, -EntityTag.CHIP_LIFT), "18 over the head, centred")
	# The same set again rebuilds nothing.
	var first_chip := head._chips.get_child(0)
	overlay.refresh()
	assert_eq(head._chips.get_child(0), first_chip)
	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 50, "mana": 10,
		"effectIds": [], "effectTimes": [], "effectStacks": []})
	overlay.refresh()
	assert_eq(overlay.chips, 1)
	assert_false(head._chips.visible)


func test_unknown_ids_and_empty_slots_are_no_chip():
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO)]})
	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 50, "mana": 10,
		"effectIds": [-1, 99], "effectTimes": [], "effectStacks": []})
	overlay.refresh()
	assert_eq(overlay.chips, 0)


func test_what_a_player_said_floats_over_their_head_and_only_theirs():
	state.local.id = 1
	state.local.name = "Ruu"
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO),
		WireHelper.player(2, "Mingau", Vector2(40, 0)), WireHelper.player(3, "Far", Vector2(9000, 9000))]})
	state.apply_packet("TextPacket", {"from": "Mingau", "to": "", "message": "hi"})
	state.apply_packet("TextPacket", {"from": "Far", "to": "", "message": "unseen"})
	state.apply_packet("TextPacket", {"from": "SYSTEM", "to": "", "message": "Welcome"})
	overlay.refresh()
	assert_eq(overlay.bubbles, 1, "one over Mingau; Far is off camera, SYSTEM has no head")
	var head: HeadStack = _tag("player", 2)._head
	assert_eq(head._bubble_text.text, "hi")
	assert_lt(head._bubble.position.y, 0.0, "over the head")
	state.apply_packet("TextPacket", {"from": "Ruu", "to": "", "message": "a line long enough to wrap onto a second row of the bubble, easily"})
	overlay.refresh()
	assert_eq(overlay.bubbles, 2, "and ours over us")
	var ours: HeadStack = _tag("player", 1)._head
	assert_lte(ours._bubble_text.custom_minimum_size.x, HeadStack.BUBBLE_WRAP, "wrapped at 180")
	now += ChatBubbles.BASE_MS + 2 * ChatBubbles.PER_CHAR_MS - 250
	overlay.refresh()
	assert_almost_eq(head._bubble.modulate.a, 0.5, 0.01, "fading through its last half second")
	now += 5000
	overlay.refresh()
	assert_eq(overlay.bubbles, 0, "gone when their time is up")


func test_a_bubble_sits_over_the_chips_when_there_are_any():
	state.local.id = 1
	state.local.name = "Ruu"
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO)]})
	state.apply_packet("TextPacket", {"from": "Ruu", "to": "", "message": "hi"})
	overlay.refresh()
	var head: HeadStack = _tag("player", 1)._head
	var alone := head._bubble.position.y
	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 50, "mana": 10,
		"effectIds": [6], "effectTimes": [], "effectStacks": []})
	overlay.refresh()
	assert_lt(head._bubble.position.y, alone, "lifted by a chip")
	assert_lt(head._bubble.position.y + head._bubble.size.y, head._chips.position.y + 0.01)


func test_an_enemy_gets_a_bar_only_while_hurt_and_chips_the_moment_effects_arrive():
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(3, 1, Vector2.ZERO, 0, 100)]})
	overlay.refresh()
	var tag := _tag("enemy", 3)
	assert_not_null(tag)
	assert_false(tag._hp.visible, "the bar is the wound, not the creature")
	assert_false(tag._name.visible)
	state.entities.enemies[3]["health"] = 40
	state.entities.enemies[3]["effects"] = [6]
	overlay.refresh()
	assert_true(tag._hp.visible)
	assert_almost_eq(tag._hp.size.x, tag._hp_back.size.x * 0.4, 0.001)
	assert_eq(tag._hp.position.y, -EntityTag.ENEMY_BAR_LIFT)
	assert_eq(overlay.chips, 1)


func test_a_tag_is_freed_with_its_entity():
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(3, 1, Vector2.ZERO, 0, 100)]})
	overlay.refresh()
	assert_eq(overlay.tag_count(), 1)
	state.apply_packet("UnloadPacket", {"enemies": [3]})
	overlay.refresh()
	assert_eq(overlay.tag_count(), 0, "swept, not left behind")


func test_a_caption_is_placed_under_the_near_portal_only():
	state.apply_packet("LoadPacket", {"portals": [
		WireHelper.portal(6, 1, Vector2(12, 12), "Deep Beach", 2),
		WireHelper.portal(7, 1, Vector2(9000, 9000), "Far Beach", 1),
		WireHelper.portal(8, 1, Vector2(50, 12)),
	]})
	overlay.refresh()
	assert_eq(overlay.captions, 1, "the near one with a realm behind it")
	var label: Label = overlay._labels._captions._live[6]
	assert_eq(label.text, "Deep Beach  -  T2")
	assert_eq(label.label_settings.font_color, PortalCard.TIERED)
	assert_false(label.has_theme_stylebox_override("normal"), "no card unless we stand on it")
	assert_gt(label.position.y, 12.0 + GameConstants.TILE_SIZE, "under the portal")
	assert_eq(label.label_settings.font_size, FloatingLabels.CAPTION_SIZE)


func test_the_portal_we_stand_on_expands_into_its_card():
	state.local.id = 1
	state.local.position = Vector2(12, 12)
	state.apply_packet("LoadPacket", {"portals": [
		WireHelper.portal(6, 1, Vector2(12, 12), "Deep Beach", 2),
		WireHelper.portal(7, 1, Vector2(300, 12), "Far Beach", 1),
	]})
	overlay.refresh()
	var near: Label = overlay._labels._captions._live[6]
	assert_string_contains(near.text, "Deep Beach   [T2]")
	assert_string_contains(near.text, "0 in realm")
	assert_string_contains(near.text, "Modifiers revealed on entry")
	assert_true(near.has_theme_stylebox_override("normal"), "boxed")
	assert_eq(near.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	var far: Label = overlay._labels._captions._live[7]
	assert_eq(far.text, "Far Beach", "tier 1 and no difficulty: no badge")
	assert_false(far.has_theme_stylebox_override("normal"))
	# Walk away: the card folds back into the line and the box goes.
	state.local.position = Vector2(200, 200)
	overlay.refresh()
	assert_eq(near.text, "Deep Beach  -  T2")
	assert_false(near.has_theme_stylebox_override("normal"))


func test_combat_numbers_are_centred_fade_and_shrink_and_are_culled():
	state.apply_packet("TextEffectPacket", {"textEffectId": 0, "entityType": 1,
		"targetEntityId": 0, "text": "42", "posX": 12.0, "posY": 12.0})
	state.apply_packet("TextEffectPacket", {"textEffectId": 0, "entityType": 1,
		"targetEntityId": 0, "text": "7", "posX": 9000.0, "posY": 9000.0})
	overlay.refresh()
	assert_eq(overlay.texts, 1, "the one in view")
	var label: Label = overlay._labels._numbers._live[0]
	assert_eq(label.text, "42")
	assert_eq(label.label_settings.font_size, 24)
	assert_almost_eq(label.scale.x, 1.2, 0.0001, "fresh: a fifth bigger")
	assert_almost_eq(label.modulate.a, 1.0, 0.0001)
	assert_almost_eq(label.position.x + label.size.x * 0.5, 12.0, 1.0, "centred on the hit")
	state.advance(DamageText.LIFE + 0.1, Vector2.ZERO, 0.0)
	overlay.refresh()
	assert_eq(overlay.texts, 0, "gone when spent")
	assert_eq(overlay._labels._numbers.size(), 0, "and its label with it")


func test_without_a_state_there_is_nothing():
	var bare := EntityOverlay.new()
	add_child_autofree(bare)
	bare.refresh()
	assert_eq(bare.tag_count(), 0)
	assert_eq(bare.chips + bare.bubbles + bare.captions + bare.texts, 0)
