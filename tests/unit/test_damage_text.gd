extends GutTest

## The numbers that float off whatever was hit.

var state: RealmState
var texts: DamageText
var now := 1000


func before_each():
	state = RealmState.new(null, func() -> int: return now)
	texts = state.texts


func _hit(text: String, at: Vector2, effect_id := 0, entity_type := 0, target := 0) -> void:
	state.apply_packet("TextEffectPacket", {
		"textEffectId": effect_id, "entityType": entity_type, "targetEntityId": target,
		"text": text, "posX": at.x, "posY": at.y})


# --- colour ----------------------------------------------------------------

func test_each_effect_has_the_colour_both_references_give_it():
	assert_eq(DamageText.colour_of(0), Color(1.0, 0.25, 0.25), "damage is red")
	assert_eq(DamageText.colour_of(1), Color(0.25, 1.0, 0.25), "heal is green")
	assert_eq(DamageText.colour_of(2), Color(0.30, 0.55, 1.0), "armor pierce is blue")
	assert_eq(DamageText.colour_of(4), Color(1.0, 0.50, 0.25), "player info is orange")


func test_an_effect_id_we_do_not_know_still_shows():
	assert_eq(DamageText.colour_of(99), Color.WHITE, "white rather than invisible")
	assert_eq(DamageText.colour_of(-1), Color.WHITE)


# --- where it lands --------------------------------------------------------

func test_the_servers_impact_point_wins():
	# For a bullet hit this is where the shot actually struck, which is not
	# where the enemy is by the time the packet arrives.
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(7, 1, Vector2(500, 500))]})
	_hit("12", Vector2(64, 96), 0, GameConstants.ENTITY_ENEMY, 7)
	assert_eq(texts.texts[0]["pos"], Vector2(64, 96))


func test_a_zero_position_falls_back_to_the_target():
	state.apply_packet("LoadPacket", {
		"players": [WireHelper.player(3, "me", Vector2(10, 20))],
		"enemies": [WireHelper.enemy(7, 1, Vector2(30, 40))],
	})
	_hit("5", Vector2.ZERO, 0, GameConstants.ENTITY_PLAYER, 3)
	assert_eq(texts.texts[0]["pos"], Vector2(10, 20), "heals and status arrive this way")

	_hit("9", Vector2.ZERO, 1, GameConstants.ENTITY_ENEMY, 7)
	assert_eq(texts.texts[1]["pos"], Vector2(30, 40))


func test_a_number_about_us_lands_where_we_are_not_where_the_roster_last_saw_us():
	# The live probe's case: fighting on the move, our roster entry trails the
	# server's snapshots while the predicted position has gone on ahead.
	state.local.id = 3
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(3, "me", Vector2(832, 172))]})
	state.local.position = Vector2(777, 153)
	state.local.previous_position = Vector2(777, 153)
	_hit("Melee Combat Mastery 25%", Vector2.ZERO, 4, GameConstants.ENTITY_PLAYER, 3)
	assert_eq(texts.texts[0]["pos"] + Vector2(0, DamageText.INFO_LANE), Vector2(777, 153),
		"at the predicted position, above it in the info lane")
	_hit("-40", Vector2.ZERO, 0, GameConstants.ENTITY_PLAYER, 3)
	assert_eq(texts.texts[1]["pos"], Vector2(777, 153), "damage we take too")
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(4, "them", Vector2(500, 500))]})
	_hit("-7", Vector2.ZERO, 0, GameConstants.ENTITY_PLAYER, 4)
	assert_eq(texts.texts[2]["pos"], Vector2(500, 500), "anyone else is still where the roster has them")


func test_a_zero_position_can_fall_back_to_the_bullet():
	state.projectiles.bullets[9] = Projectile.from_wire({
		"id": 9, "pos": {"x": 70.0, "y": 80.0}, "angle": 0.0, "magnitude": 0.0,
		"range": 100.0, "flags": []}, now)
	_hit("3", Vector2.ZERO, 0, GameConstants.ENTITY_BULLET, 9)
	assert_eq(texts.texts[0]["pos"], Vector2(70, 80))


func test_an_unknown_target_does_not_stop_the_number():
	_hit("3", Vector2.ZERO, 0, GameConstants.ENTITY_ENEMY, 404)
	assert_eq(texts.texts.size(), 1)
	assert_eq(texts.texts[0]["pos"], Vector2.ZERO)


# --- merging ---------------------------------------------------------------

func test_a_burst_of_identical_hits_reads_as_one_number():
	_hit("5", Vector2(100, 100))
	_hit("5", Vector2(104, 98))
	assert_eq(texts.texts.size(), 1, "one number, not two")
	assert_eq(texts.texts[0]["text"], "5 x2")


func test_merging_keeps_counting_past_the_second_hit():
	# The web client compares against the text it has already rewritten to
	# carry the count, so it merges once and then starts a new number -- which
	# its own comment ("8 wizard shots -> one big number") says is not the
	# intent. Comparing against the original text is that comment's behaviour.
	for i in 8:
		_hit("5", Vector2(100, 100))
	assert_eq(texts.texts.size(), 1)
	assert_eq(texts.texts[0]["text"], "5 x8")


func test_a_different_number_is_its_own_text():
	_hit("5", Vector2(100, 100))
	_hit("7", Vector2(100, 100))
	assert_eq(texts.texts.size(), 2)


func test_the_same_number_far_away_is_a_separate_hit():
	_hit("5", Vector2(100, 100))
	_hit("5", Vector2(100 + DamageText.MERGE_PX + 1.0, 100))
	assert_eq(texts.texts.size(), 2)


func test_a_stale_number_is_not_merged_into():
	_hit("5", Vector2(100, 100))
	state.advance(DamageText.MERGE_WINDOW * 2.0, Vector2.ZERO, 0.0)
	_hit("5", Vector2(100, 100))
	assert_eq(texts.texts.size(), 2, "far enough apart in time to be a second hit")


func test_damage_and_status_never_merge_into_each_other():
	# Separated by colour, which is what makes the reference's explicit lane
	# check here unreachable: every effect id has a colour of its own.
	_hit("5", Vector2(100, 100), 0)
	_hit("5", Vector2(100, 100), DamageText.INFO_EFFECT)
	assert_eq(texts.texts.size(), 2)
	assert_ne(texts.texts[0]["colour"], texts.texts[1]["colour"])


# --- stacking --------------------------------------------------------------

func test_the_stack_step_is_the_native_clients():
	# A world-unit lane step, drawn at the camera's 2x under a 24px label:
	# a step under the glyph height stacks a burst on top of itself.
	assert_eq(DamageText.STACK_STEP, 14.0)
	assert_gt(DamageText.STACK_STEP * 2.0, float(FloatingLabels.DAMAGE_SIZE))


func test_numbers_landing_together_step_up_the_screen():
	_hit("5", Vector2(100, 100))
	_hit("7", Vector2(100, 100))
	_hit("9", Vector2(100, 100))
	assert_eq(texts.texts[0]["pos"].y, 100.0, "the first sits on the hit")
	assert_eq(texts.texts[1]["pos"].y, 100.0 - DamageText.STACK_STEP)
	assert_eq(texts.texts[2]["pos"].y, 100.0 - DamageText.STACK_STEP * 2.0)


func test_the_stack_stops_growing():
	for i in 10:
		_hit(str(i), Vector2(100, 100))
	var highest: float = 100.0 - DamageText.STACK_STEP * DamageText.MAX_STACK
	assert_eq(texts.texts[9]["pos"].y, highest, "capped rather than a tower")


func test_status_labels_ride_their_own_lane():
	_hit("5", Vector2(100, 100), 0)
	_hit("SLOWED", Vector2(100, 100), DamageText.INFO_EFFECT)
	assert_eq(texts.texts[0]["pos"].y, 100.0)
	assert_eq(texts.texts[1]["pos"].y, 100.0 - DamageText.INFO_LANE,
		"above the damage, and not stacked against it")


# --- life ------------------------------------------------------------------

func test_a_number_floats_up_and_expires():
	_hit("5", Vector2(100, 100))
	state.advance(0.5, Vector2.ZERO, 0.0)
	assert_lt(DamageText.render_position(texts.texts[0]).y, 100.0, "it rises")
	assert_eq(texts.texts.size(), 1)

	state.advance(DamageText.LIFE, Vector2.ZERO, 0.0)
	assert_eq(texts.texts.size(), 0, "and goes")


func test_it_holds_full_alpha_before_it_fades():
	# Stepped in seconds rather than in the constants: written in terms of
	# both, the two cancel and the assertion holds whatever they say.
	_hit("5", Vector2(100, 100))
	assert_eq(DamageText.alpha_of(texts.texts[0]), 1.0)
	state.advance(0.3, Vector2.ZERO, 0.0)
	assert_eq(DamageText.alpha_of(texts.texts[0]), 1.0,
		"still at full: the model outlives the fade by a fifth of a second")
	state.advance(0.65, Vector2.ZERO, 0.0)
	assert_almost_eq(DamageText.alpha_of(texts.texts[0]), 0.5, 0.02)


func test_the_numbers_the_behaviour_is_made_of():
	# Spelled out, because every test below steps by them.
	assert_eq(DamageText.MERGE_PX, 24.0)
	assert_eq(DamageText.STACK_PX, 20.0)
	assert_eq(DamageText.INFO_LANE, 20.0)
	assert_eq(DamageText.MAX_STACK, 4)
	assert_eq(DamageText.RISE_PX_PER_SEC, 19.8)
	assert_almost_eq(DamageText.LIFE, 92.0 / 60.0, 0.0001, "the web client's 92 frames")
	assert_almost_eq(DamageText.FADE_LIFE, 70.0 / 60.0, 0.0001, "against which it fades")


func test_a_number_rises_at_the_rate_the_web_client_floats_its_own():
	_hit("5", Vector2(100, 100))
	state.advance(1.0, Vector2.ZERO, 0.0)
	assert_almost_eq(DamageText.render_position(texts.texts[0]).y, 100.0 - 19.8, 0.1)


func test_the_same_number_directly_above_is_a_separate_hit():
	# Every other merge test varies x, which leaves the vertical half of the
	# proximity test unexercised.
	_hit("5", Vector2(100, 100))
	_hit("5", Vector2(100, 100 + DamageText.MERGE_PX + 1.0))
	assert_eq(texts.texts.size(), 2)


func test_a_merge_starts_the_number_it_lands_on_over():
	_hit("5", Vector2(100, 100))
	state.advance(DamageText.MERGE_WINDOW * 0.5, Vector2.ZERO, 0.0)
	var aged: float = texts.texts[0]["life"]
	_hit("5", Vector2(100, 100))
	assert_eq(texts.texts[0]["text"], "5 x2")
	assert_gt(texts.texts[0]["life"], aged, "so a sustained burst does not blink out mid-count")


func test_a_fading_number_stops_holding_its_lane():
	# Stacking counts only numbers still in their first stretch of life; one
	# nearly gone should not push a fresh one off the top.
	_hit("5", Vector2(100, 100))
	state.advance(DamageText.LIFE * 0.7, Vector2.ZERO, 0.0)
	_hit("7", Vector2(100, 100))
	assert_eq(texts.texts[1]["pos"].y, 100.0)


func test_a_fresh_number_draws_bigger_than_a_spent_one():
	# The web client's 0.8 + 0.4 * fade: a fifth bigger on arrival, a fifth
	# smaller by the end, with the base size in the middle.
	assert_almost_eq(FloatingLabels.number_scale(1.0), 1.2, 0.0001)
	assert_almost_eq(FloatingLabels.number_scale(0.0), 0.8, 0.0001)
	assert_eq(FloatingLabels.DAMAGE_SIZE, 24, "the web client's 24px bold")


func test_a_realm_change_takes_them_with_it():
	_hit("5", Vector2(100, 100))
	state.begin_transition()
	assert_eq(texts.texts.size(), 0)
