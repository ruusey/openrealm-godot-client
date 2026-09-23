extends GutTest

## Side-bands and edge highlights on square walls.

var data: GameData
var state: RealmState


func before_each():
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(data, func() -> int: return 0)


## Fixture tile 2 is a square wall, 6 a tall one, 9 a prop, 1 the floor.
func _map(walls: Array) -> void:
	var tiles: Array = []
	for x in range(0, 6):
		for y in range(0, 6):
			tiles.append(WireHelper.tile(1, 0, x, y))
	for w in walls:
		tiles.append(WireHelper.tile(w[2] if w.size() > 2 else 2, 1, w[0], w[1]))
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapWidth": 6, "mapHeight": 6, "tiles": tiles})


func test_a_side_is_open_when_nothing_wall_like_is_beyond_it():
	_map([[2, 2], [3, 2], [2, 1, 6], [1, 2, 9]])
	var open := WallBands.exposure(state.tiles, data, Vector2i(2, 2))
	assert_false(open["e"], "a square wall to the east")
	assert_false(open["n"], "a tall wall counts as a wall")
	assert_true(open["w"], "a prop does not")
	assert_true(open["s"], "the floor")
	assert_false(WallBands.exposure(state.tiles, data, Vector2i(0, 0))["n"], "a cell never sent counts as solid")
	assert_true(WallBands.exposure(state.tiles, data, Vector2i(0, 0))["e"], "a floor with nothing on it is open")


func test_only_a_square_wall_gets_bands():
	assert_true(WallBands.is_square_wall(data, 2))
	assert_false(WallBands.is_square_wall(data, 6), "a tall wall carries its own face")
	assert_false(WallBands.is_square_wall(data, 9), "a prop")
	assert_false(WallBands.is_square_wall(data, 0))


func test_the_bands_are_the_web_clients_to_the_pixel():
	var cell := Rect2(64, 64, 32, 32)
	var all := {"n": true, "s": true, "w": true, "e": true}
	var bands := WallBands.bands(cell, all)
	assert_eq(bands.size(), 12, "three a side")
	# South: 28% of 64 is 18, three bands of 6 screen px = 3 world px, and
	# the east side is open so the bands run 12 screen px (6 world) longer.
	assert_eq(bands[0]["rect"], Rect2(64, 96, 32 + 6, 3))
	assert_eq(bands[0]["alpha"], 0.55)
	assert_eq(bands[2]["rect"], Rect2(64, 102, 38, 3))
	assert_eq(bands[2]["alpha"], 0.13)
	# East: 18% of 64 is 12, bands of 4 screen px = 2 world, starting a
	# screen pixel down because the north side is open too.
	assert_eq(bands[3]["rect"], Rect2(96, 65, 2, 31))
	assert_eq(bands[3]["alpha"], 0.42)
	# West: 13% of 64 is 8, bands of 3 screen px = 1.5 world, outward.
	assert_eq(bands[6]["rect"], Rect2(62.5, 64, 1.5, 32))
	assert_eq(bands[8]["rect"], Rect2(59.5, 64, 1.5, 32))
	# North: 12% of 64 is 8, bands of 3, inset a screen pixel each open end.
	assert_eq(bands[9]["rect"], Rect2(65, 62.5, 30, 1.5))
	assert_eq(bands[9]["alpha"], 0.28)


func test_a_side_with_a_wall_beyond_gets_no_band():
	var cell := Rect2(0, 0, 32, 32)
	var only_south := WallBands.bands(cell, {"n": false, "s": true, "w": false, "e": false})
	assert_eq(only_south.size(), 3)
	assert_eq(only_south[0]["rect"].size.x, 32.0, "not lengthened: the east is walled")
	assert_eq(WallBands.bands(cell, {"n": false, "s": false, "w": false, "e": false}), [])


func test_the_rim_and_the_highlight_follow_the_open_sides():
	var open := {"n": true, "s": false, "w": true, "e": false}
	assert_eq(WallBands.outline_offsets(open), [Vector2(-1, 0), Vector2(0, -1)])
	var lines := WallBands.highlights(Rect2(0, 0, 32, 32), open)
	assert_eq(lines.size(), 4, "two along the top, two down the left")
	assert_eq(lines[0]["rect"], Rect2(0, 0, 32, 1), "a screen pixel: half a world one")
	assert_eq(lines[0]["alpha"], 0.26)
	assert_eq(lines[2]["rect"], Rect2(0, 0, 0.5, 32))
	assert_eq(WallBands.highlights(Rect2(0, 0, 32, 32), {"n": false, "s": true, "w": false, "e": true}), [])


func test_the_tile_pass_draws_bands_for_square_walls_only():
	_map([[2, 2], [3, 2], [2, 4, 6]])
	var renderer := WorldRenderer.new()
	renderer.setup(state, data)
	add_child_autofree(renderer)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	camera.position = Vector2(80, 80)
	renderer.queue_redraw()
	await wait_process_frames(2)
	# Two square walls side by side: each has three open sides, nine bands.
	assert_eq(renderer.draw_stats["wall_bands"], 18)
	assert_gt(renderer.draw_stats["tiles"], 0)
