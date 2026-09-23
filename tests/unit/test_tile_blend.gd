extends GutTest

## Which neighbouring terrain types are worth feathering together. Tiles of
## near-enough the same material are left with a hard edge, because a fringe
## between them only muddies both.

var content: GameData
var blending: TileBlend


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	blending = TileBlend.new()


func test_a_tile_never_blends_with_itself():
	assert_false(blending.blends(content, 1, 1))


func test_two_materials_apart_in_colour_do_blend():
	assert_true(blending.blends(content, 1, 3), "grass against swamp")


func test_the_same_art_under_two_ids_does_not_blend():
	# Fixture tile 8 is tile 1's sprite under another id: identical colour, so
	# the gate holds them apart even though the ids differ.
	assert_false(blending.blends(content, 1, 8))


func test_a_tile_without_a_signature_blends_rather_than_guessing():
	# No pixels to compare -- blending is the safe answer, and matches both
	# reference clients' fallback.
	assert_true(blending.blends(content, 1, 9999))
	assert_true(blending.blends(content, 1, 5), "NoSprite in the fixture")


func test_signatures_are_worked_out_once():
	var first: Variant = blending.signature(content, 1)
	assert_not_null(first)
	assert_eq(blending.signature(content, 1), first, "cached")
