extends GutTest

## What colour a tile is from above: the web client's rules, damaging first.

var content: GameData


func before_each():
	content = GameData.new()
	content.library.tiles = {
		1: _tile("Grass_Floor", {}),
		2: _tile("Stone_Pillar_Wall", {"hasCollision": 1, "isWall": 1}),
		3: _tile("Water_Shallow", {"slows": 1}),
		4: _tile("Broken", {}),
		9: _tile("Anvil", {"hasCollision": 1}),
		25: _tile("Lava_0", {"slows": 1, "damaging": 1}),
		30: _tile("Sand_Floor", {}),
		31: _tile("Cobble_Path", {}),
		32: _tile("Obsidian_Floor", {}),
		33: _tile("Ocean_Deep", {"slows": 1, "hasCollision": 1}),
		34: _tile("Beach_Grass", {}),
	}


static func _tile(name: String, data: Dictionary) -> Dictionary:
	return {"name": name, "data": data}


func _same(a: Color, b: Color, note := "") -> void:
	assert_almost_eq(a.r, b.r, 0.01, note)
	assert_almost_eq(a.g, b.g, 0.01, note)
	assert_almost_eq(a.b, b.b, 0.01, note)


func test_the_collision_layer_wins_and_is_grey():
	assert_eq(MinimapPalette.for_cell(content, 1, 2), MinimapPalette.WALL, "a wall over grass")
	assert_eq(MinimapPalette.for_cell(content, 3, 9), MinimapPalette.STONE, "a prop, solid but not a wall, over water")


func test_a_cell_with_nothing_on_it_is_a_hole():
	assert_eq(MinimapPalette.for_cell(content, 0, 0), MinimapPalette.VOID)
	assert_eq(MinimapPalette.for_cell(content, -1, -1), MinimapPalette.VOID, "a cell never sent")


func test_a_liquid_is_blue_by_flag():
	assert_eq(MinimapPalette.for_cell(content, 3, -1), MinimapPalette.WATER)


func test_a_floor_that_burns_is_red_even_though_it_also_slows():
	# Both references test the liquid flag first, and every shipped lava
	# tile slows too, so they paint lava as water. The red is for this.
	assert_eq(MinimapPalette.for_cell(content, 25, -1), MinimapPalette.LAVA)


func test_a_slowing_tile_with_collision_is_not_a_liquid():
	# Deep water on the base layer: the web client's `slows && !hasCollision`.
	assert_eq(MinimapPalette.for_base(content, 33), MinimapPalette.WATER, "...but its name still says water")
	assert_eq(MinimapPalette.for_base(content, 34), MinimapPalette.SAND, "beach before grass: the first rule that matches wins")


func test_the_name_says_what_a_floor_looks_like():
	assert_eq(MinimapPalette.for_base(content, 1), MinimapPalette.GRASS)
	assert_eq(MinimapPalette.for_base(content, 30), MinimapPalette.SAND)
	assert_eq(MinimapPalette.for_base(content, 31), MinimapPalette.STONE)
	assert_eq(MinimapPalette.for_base(content, 32), MinimapPalette.DARK)


func test_an_unknown_name_hashes_to_a_brown_of_its_own():
	# hsl((4 * 37) % 60 + 20, 30%, 35%) = hsl(48, 30%, 35%), spelled out.
	_same(MinimapPalette.for_base(content, 4), Color(0.455, 0.413, 0.245), "tile 4")
	assert_ne(MinimapPalette.hashed(4), MinimapPalette.hashed(5), "two unknown floors tell apart")


func test_a_tile_the_content_does_not_know_is_the_default():
	assert_eq(MinimapPalette.for_base(content, 999), MinimapPalette.DEFAULT)


func test_without_content_only_the_layers_are_known():
	assert_eq(MinimapPalette.for_cell(null, 1, 2), MinimapPalette.STONE, "solid, but whether it is a wall is unknown")
	assert_eq(MinimapPalette.for_cell(null, 1, -1), MinimapPalette.DEFAULT)
	assert_eq(MinimapPalette.for_cell(null, 0, -1), MinimapPalette.VOID)


func test_hsl_matches_the_css_it_came_from():
	_same(MinimapPalette.from_hsl(0.0, 1.0, 0.5), Color.RED)
	_same(MinimapPalette.from_hsl(0.5, 0.0, 0.5), Color(0.5, 0.5, 0.5), "no saturation is grey")
	_same(MinimapPalette.from_hsl(0.3, 0.5, 0.0), Color.BLACK, "no lightness is black")
