extends GutTest

## How fast the server lets you shoot, and whether we agree with it.

## The server's own gate: it accepts a shot once more than this fraction of
## the interval has passed. Slack for jitter, not budget -- every interval we
## produce has to clear it.
const SERVER_TOLERANCE := 0.6


func _server_shots(dex: int, mul: float, effects: Array) -> float:
	# The Java, transcribed: truncate once, then scale.
	var shots := float(int((6.5 * (dex + 17.3)) / 75.0))
	if mul > 0.0:
		shots *= mul
	if effects.has(AttackRate.BERSERK):
		shots *= 1.5
	elif effects.has(AttackRate.DAZED):
		shots = 1.0
	return shots


# --- the formula -----------------------------------------------------------

func test_shots_per_second_by_dex():
	# Truncated, so it steps rather than sliding: the server does this once,
	# before anything else scales it.
	assert_eq(AttackRate.per_second(0, 1.0, []), 1.0, "even a DEX of nothing shoots")
	assert_eq(AttackRate.per_second(12, 1.0, []), 2.0)
	assert_eq(AttackRate.per_second(50, 1.0, []), 5.0)
	assert_eq(AttackRate.per_second(100, 1.0, []), 10.0)


func test_the_weapon_scales_it():
	# The shipped archetypes, as literals.
	assert_almost_eq(AttackRate.per_second(50, 0.55, []), 2.75, 0.001, "hammer")
	assert_almost_eq(AttackRate.per_second(50, 0.7, []), 3.5, 0.001, "tome")
	assert_almost_eq(AttackRate.per_second(50, 0.85, []), 4.25, 0.001, "bow")
	assert_almost_eq(AttackRate.per_second(50, 1.0, []), 5.0, 0.001, "sword")
	assert_almost_eq(AttackRate.per_second(50, 1.1, []), 5.5, 0.001, "chakram")
	assert_almost_eq(AttackRate.per_second(50, 1.25, []), 6.25, 0.001, "wand")
	assert_almost_eq(AttackRate.per_second(50, 1.5, []), 7.5, 0.001, "dagger")


func test_the_multiplier_is_not_truncated_after_the_fact():
	# The web client floors again here. A hammer at DEX 12 then fires at
	# 1010ms where the server demands more than 1090, and every shot in the
	# gap is spawned locally and dropped server-side.
	assert_almost_eq(AttackRate.per_second(12, 0.55, []), 1.1, 0.001,
		"two shots a second, hammered down to 1.1 -- not floored to 1")


func test_a_weapon_with_no_archetype_does_not_scale_it():
	assert_eq(AttackRate.per_second(50, 0.0, []), 5.0, "nor divides by nothing")


func test_berserk_comes_after_the_weapon():
	# The ordering only shows against a multiplier that is not 1.0, which is
	# why this row uses a hammer.
	assert_almost_eq(AttackRate.per_second(50, 0.55, [AttackRate.BERSERK]),
		2.75 * 1.5, 0.001)


func test_dazed_pins_it_to_one():
	assert_eq(AttackRate.per_second(100, 1.5, [AttackRate.DAZED]), 1.0)


func test_dazed_ignores_the_weapon_entirely():
	# It is an assignment, not a multiplier, so it has to come after the
	# weapon: applied before, a dazed hammer would be 0.55 a second.
	assert_eq(AttackRate.per_second(100, 0.55, [AttackRate.DAZED]), 1.0)


func test_berserk_beats_dazed():
	# The server's branch is an else-if; the web client tests them
	# independently with DAZED last, so DAZED wins there. The Java is the
	# tiebreaker.
	assert_almost_eq(AttackRate.per_second(50, 1.0, [AttackRate.DAZED, AttackRate.BERSERK]),
		7.5, 0.001)


func test_stunned_stops_it_entirely():
	assert_true(AttackRate.blocked([AttackRate.STUNNED]))
	assert_false(AttackRate.blocked([AttackRate.BERSERK, AttackRate.DAZED]))
	assert_false(AttackRate.blocked([]))


# --- the interval ----------------------------------------------------------

func test_the_interval_is_the_rate_plus_a_margin():
	assert_almost_eq(AttackRate.interval(50, 1.0, []), 0.21, 0.0001,
		"five a second, plus the 10ms both references add")


func test_every_interval_clears_the_servers_gate():
	# The assertion that catches an implementation that is merely close: the
	# server accepts a shot after SERVER_TOLERANCE of ITS interval, so ours
	# has to be at least that long for every combination, or shots are
	# spawned locally and refused.
	for dex in [0, 1, 12, 37, 50, 75, 100]:
		for mul in [0.55, 0.7, 0.85, 1.0, 1.1, 1.25, 1.5]:
			for effects in [[], [AttackRate.BERSERK], [AttackRate.DAZED]]:
				var ours := AttackRate.interval(dex, mul, effects)
				var gate := (1.0 / _server_shots(dex, mul, effects)) * SERVER_TOLERANCE
				assert_gt(ours, gate, "dex %d, mul %.2f, effects %s" % [dex, mul, effects])


func test_a_slower_weapon_waits_longer():
	assert_gt(AttackRate.interval(50, 0.55, []), AttackRate.interval(50, 1.5, []))


func test_the_old_placeholder_was_wrong_in_both_directions():
	# A flat quarter second fired too fast for a low-DEX character -- the
	# shots being dropped after the client had already drawn the bullet --
	# and too slow for a high-DEX one.
	assert_gt(AttackRate.interval(12, 1.0, []), 0.25, "too fast at DEX 12")
	assert_lt(AttackRate.interval(100, 1.0, []), 0.25, "too slow at DEX 100")


func test_where_berserk_sits_relative_to_the_weapon_cannot_matter():
	# Both are multipliers with no truncation between them, so the order is
	# arithmetic, not behaviour. Recorded because it looks like it should
	# matter -- the native client comments on the ordering, and it only
	# matters there because of a rounding step we do not have.
	var weapon_first := 5.0 * 0.55 * AttackRate.BERSERK_MULTIPLIER
	var berserk_first := 5.0 * AttackRate.BERSERK_MULTIPLIER * 0.55
	assert_almost_eq(weapon_first, berserk_first, 0.0001)
	assert_almost_eq(AttackRate.per_second(50, 0.55, [AttackRate.BERSERK]),
		weapon_first, 0.0001)
