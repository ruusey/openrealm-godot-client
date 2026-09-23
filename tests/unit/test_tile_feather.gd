extends GutTest

## Seam fringes between terrain types. The bake is what the web client's
## "Loading shaders" bar is doing, so the shapes and the fade direction have
## to match or the blend reads inside-out.

var content: GameData
var feathers: TileFeather


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	feathers = TileFeather.new()


func test_a_horizontal_fringe_spans_the_cell_and_is_shallow():
	# 8px cell, 15% depth -> 2px strip, upsampled 4x.
	var north := feathers.texture(content, 1, TileFeather.NORTH)
	assert_not_null(north)
	assert_eq(north.get_size(), Vector2(32, 8), "cell-wide, fringe-deep")


func test_a_vertical_fringe_is_the_other_way_round():
	var west := feathers.texture(content, 1, TileFeather.WEST)
	assert_not_null(west)
	assert_eq(west.get_size(), Vector2(8, 32))


func test_a_tile_with_no_art_has_no_fringe():
	assert_null(feathers.texture(content, 5, TileFeather.NORTH), "NoSprite in the fixture")
	assert_null(feathers.texture(content, 9999, TileFeather.NORTH))


func test_the_fringe_fades_away_from_the_seam():
	# A north fringe is drawn along the cell's top edge, so it must be
	# strongest at the top and vanish at the bottom. Inverted, the blend
	# reads as a hard line with a halo behind it.
	var image := feathers.texture(content, 1, TileFeather.NORTH).get_image()
	var seam := image.get_pixel(image.get_width() / 2, 0).a
	var away := image.get_pixel(image.get_width() / 2, image.get_height() - 1).a
	assert_gt(seam, away, "opaque at the seam, clear at the inner edge")
	assert_almost_eq(away, 0.0, 0.08)


func test_the_fringe_never_fully_hides_the_tile_beneath():
	# Peak alpha is half, so both sides show a mix at the seam rather than one
	# replacing the other.
	var image := feathers.texture(content, 1, TileFeather.SOUTH).get_image()
	var peak := 0.0
	for y in image.get_height():
		peak = maxf(peak, image.get_pixel(image.get_width() / 2, y).a)
	assert_lte(peak, TileFeather.PEAK_ALPHA + 0.02)


func test_fringes_are_baked_once_per_tile_and_direction():
	var first := feathers.texture(content, 1, TileFeather.EAST)
	assert_true(first == feathers.texture(content, 1, TileFeather.EAST), "cached")
	assert_false(first == feathers.texture(content, 1, TileFeather.WEST),
		"each direction is its own strip")
