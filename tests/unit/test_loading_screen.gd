extends GutTest

## The wait for the content, and what it protects.

var data: GameData
var screen: LoadingScreen


func before_each():
	data = GameData.new()
	screen = LoadingScreen.new()
	screen.setup(data)
	add_child_autofree(screen)


func test_covers_the_screen_until_the_content_is_ready():
	screen._process(0.0)
	assert_true(screen.visible)
	assert_eq(screen._progress.text, "content ...", "no tables yet, so no count to give")
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	assert_true(data.ready)
	assert_true(screen.is_processing(), "still waiting")
	screen._process(0.0)
	assert_false(screen.visible)
	assert_false(screen.is_processing(), "loaded: nothing more to wait for, so it stops asking")


func test_counts_the_sheets_as_they_land():
	assert_eq(LoadingScreen.caption(0, 0), "content ...")
	assert_eq(LoadingScreen.caption(12, 51), "sprites 12 / 51")
	# The fixture names two sheets; one is deliberately broken and still counts.
	data.library.tiles = {1: {"spriteKey": "entity/atlas.png"}, 2: {"spriteKey": "nope.png"}}
	screen._process(0.0)
	assert_eq(screen._progress.text, "sprites 0 / 2")
	await data.sprites.preload_sheets(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")), data.library.sheet_keys())
	screen._process(0.0)
	assert_eq(screen._progress.text, "sprites 2 / 2")


func test_does_nothing_without_content():
	var bare := LoadingScreen.new()
	add_child_autofree(bare)
	bare.visible = true
	bare._process(0.0)
	assert_false(bare.visible)


func test_the_hall_draws_no_stone_and_asks_for_no_sheet_until_ready():
	# The bug this fixes: the backdrop asked for its sheets on its first
	# frame, before the browser had fetched them, and every ask was a
	# content warning on the login screen.
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	var backdrop := LoginBackdrop.new()
	backdrop.game_data = data
	backdrop.hall.wall_tile = 6
	backdrop.hall.floor_tile = 1
	backdrop.torch_tile = 9
	backdrop.candelabra_tile = 2
	add_child_autofree(backdrop)
	backdrop.size = Vector2(64, 64)
	data.ready = false
	backdrop.step(1.0 / 60.0)
	await wait_process_frames(2)
	assert_eq(backdrop.drawn["tiles"], 0)
	assert_eq(backdrop.drawn["torches"], 0)
	var early := data.sprites.errors.filter(func(e: String) -> bool: return e.contains("not preloaded"))
	assert_eq(early, [], "and no sheet was asked for early")
	assert_gt(backdrop.field.count, 0, "the fire needs no content")
	data.ready = true
	backdrop.step(1.0 / 60.0)
	await wait_process_frames(2)
	assert_eq(backdrop.drawn["tiles"], 4)


func test_the_boot_splash_is_this_screen():
	# The engine shows its splash before the main scene runs; on the web the
	# same image and colour are the page's splash while the engine loads.
	# Both must match this screen or the boot visibly changes twice.
	assert_eq(ProjectSettings.get_setting("application/boot_splash/bg_color"), LoadingScreen.BACKGROUND)
	var path: String = ProjectSettings.get_setting("application/boot_splash/image")
	assert_eq(path, "res://assets/boot_splash.png")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(1280, 960), "the loading screen, captured")
	assert_almost_eq(image.get_pixel(10, 10).r, LoadingScreen.BACKGROUND.r, 0.02, "its corner is the background")
	assert_false(ProjectSettings.get_setting("application/boot_splash/use_filter"), "pixel text stays crisp")
