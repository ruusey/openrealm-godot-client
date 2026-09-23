extends GutTest

## What a class can cast, and what each cast costs.

var content: GameData


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))


func test_the_hotbar_is_the_classs_default():
	assert_eq(content.abilities.hotbar(2), [13006, 13007, 13008, 0])
	assert_eq(content.abilities.hotbar(0), [13000, 0, 13002, 0])
	assert_eq(content.abilities.hotbar(99), [0, 0, 0, 0], "an unknown class binds nothing")
	assert_eq(content.abilities.hotbar_id(2, 1), 13007)
	assert_eq(content.abilities.hotbar_id(2, 5), 0)
	assert_eq(content.abilities.hotbar_id(2, -1), 0)


func test_the_passive_and_the_definitions():
	assert_eq(content.abilities.passive(2).get("name"), "Arcane Well")
	assert_true(content.abilities.passive(99).is_empty())
	assert_eq(content.abilities.ability(13006).get("name"), "Fire Breath")
	assert_true(content.abilities.ability(1).is_empty())


func test_icons_come_off_the_ability_sheet():
	assert_not_null(content.abilities.icon(13006))
	assert_eq(content.abilities.icon(13006).region, Rect2(32, 0, 16, 16), "16px cells")
	assert_null(content.abilities.icon(13008), "no sprite key, no icon")


func test_the_point_cap_is_the_contents_or_five():
	assert_eq(content.abilities.cap(13007), 3)
	assert_eq(content.abilities.cap(13008), 5, "a declared zero means the default")
	assert_eq(content.abilities.cap(1), 5)


func test_points_shorten_the_cooldown_down_to_the_floor():
	assert_eq(content.abilities.cooldown_ms(13006, 0), 2500)
	assert_eq(content.abilities.cooldown_ms(13006, 3), 1900)
	assert_eq(content.abilities.cooldown_ms(13006, 100), 500, "floored where the server floors")
	assert_eq(content.abilities.cooldown_ms(1, 0), 0)


func test_points_shorten_a_cast_at_half_the_rate():
	assert_eq(content.abilities.cast_ms(13007, 0), 1200)
	assert_eq(content.abilities.cast_ms(13007, 2), 950)
	assert_eq(content.abilities.cast_ms(13007, 10), 150, "floored at 150")
	assert_eq(content.abilities.cast_ms(13006, 5), 0, "an instant cast stays instant")


func test_the_projectile_group_is_the_first_such_effect():
	assert_eq(content.abilities.projectile_group(13006), 12)
	assert_eq(content.abilities.projectile_group(13007), 0)
	assert_eq(content.abilities.projectile_group(1), 0)


func test_a_target_is_clamped_to_the_reach():
	var centre := Vector2(100, 100)
	assert_eq(content.abilities.clamp_target(13006, centre, centre + Vector2(1000, 0)), centre + Vector2(352, 0))
	assert_eq(content.abilities.clamp_target(13006, centre, centre + Vector2(10, 0)), centre + Vector2(10, 0))
	assert_eq(content.abilities.clamp_target(13002, centre, centre + Vector2(10, 0)), centre, "a self-cast")
	assert_eq(content.abilities.clamp_target(1, centre, centre + Vector2(10, 0)), centre + Vector2(10, 0),
		"no definition, no reach, the point stands")


func test_the_sheet_is_preloaded_with_the_rest():
	assert_string_contains(content.summary(), "5 abilities")
	assert_true("atlas.png" in content.library.sheet_keys())
