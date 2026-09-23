extends GutTest

## Status effects wash a colour over the character carrying them. A plain
## multiply, matching the web client's sprite.tint -- the native's colour
## matrices mix channels, which a modulate cannot reproduce.


func test_no_effects_leaves_the_sprite_alone():
	assert_eq(StatusTint.of([]), StatusTint.CLEAR)
	assert_eq(StatusTint.of([9999]), StatusTint.CLEAR, "an effect with no tint")


func test_a_known_effect_tints():
	assert_eq(StatusTint.of([StatusTint.POISONED]), Color(0.25, 0.8, 0.25))
	assert_eq(StatusTint.of([StatusTint.BERSERK]), Color(1.0, 0.4, 0.27))


func test_only_one_effect_shows_and_the_order_decides():
	# The web client tests these in a fixed else-if chain, so the first match
	# wins however the ids arrive.
	var both := [StatusTint.POISONED, StatusTint.INVINCIBLE]
	assert_eq(StatusTint.of(both), StatusTint.of([StatusTint.INVINCIBLE]),
		"invincible outranks poisoned")
	both.reverse()
	assert_eq(StatusTint.of(both), StatusTint.of([StatusTint.INVINCIBLE]),
		"and the wire order does not change that")


func test_every_entry_is_a_distinct_id():
	var seen := {}
	for entry in StatusTint.PRIORITY:
		var id: int = entry[0]
		assert_false(seen.has(id), "effect %d listed twice" % id)
		seen[id] = true
