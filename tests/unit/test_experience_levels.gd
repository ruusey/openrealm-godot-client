extends GutTest

## The server's ExperienceModel over exp-levels.json: the level a total
## falls in, one more past the table, and fame every 2500 beyond it.

var levels: ExperienceLevels


func before_each():
	levels = ExperienceLevels.new()
	levels.parse({"levelExperienceMap": {"1": "0-100", "3": "301-600", "2": "101-300"}})


func test_parses_the_table_whatever_order_it_comes_in():
	assert_true(levels.loaded())
	assert_eq(levels.max_level, 3)
	assert_eq(levels.max_experience, 600)
	assert_eq(levels.ranges[2], [101, 300])


func test_the_level_is_the_range_the_total_falls_in():
	assert_eq(levels.level_for(0), 1)
	assert_eq(levels.level_for(100), 1, "the max is inclusive")
	assert_eq(levels.level_for(101), 2)
	assert_eq(levels.level_for(600), 3)
	assert_eq(levels.level_for(601), 4, "past the table is one level more than it holds")


func test_fame_is_every_2500_past_the_table():
	assert_eq(levels.fame_for(600), 0)
	assert_eq(levels.fame_for(601), 0, "not until a whole 2500")
	assert_eq(levels.fame_for(3100), 1)
	assert_eq(levels.fame_for(600 + 2500 * 7 + 2499), 7)


func test_progress_counts_from_the_levels_floor():
	assert_eq(levels.progress_for(0), [0, 100])
	assert_eq(levels.progress_for(200), [99, 199])
	assert_eq(levels.progress_for(601), [0, 0], "no range past the table")


func test_an_unloaded_table_is_level_one_and_no_fame():
	var none := ExperienceLevels.new()
	assert_false(none.loaded())
	assert_eq(none.level_for(99999), 1)
	assert_eq(none.fame_for(99999), 0)
	assert_eq(none.progress_for(5), [0, 0])


func test_a_malformed_row_is_skipped_not_fatal():
	levels.parse({"levelExperienceMap": {"1": "0-100", "x": "1-2", "2": "banana"}})
	assert_eq(levels.ranges.keys(), [1])


func test_the_fixtures_table_is_read_with_the_content():
	var data := GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	# The fixture's one deliberate error is its broken sheet, not the table.
	assert_eq(data.library.errors, [])
	assert_eq(data.levels.level_for(200), 2)
	assert_eq(data.levels.max_experience, 600)
