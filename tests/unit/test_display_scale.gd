extends GutTest

## DisplayScale: the window is the base, the scale is a whole number.


func test_the_scale_steps_at_whole_multiples_of_the_base():
	assert_eq(DisplayScale.factor_for(Vector2i(1280, 720)), 1.0)
	assert_eq(DisplayScale.factor_for(Vector2i(2559, 1440)), 1.0, "one short of 2x on either axis is 1x")
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1439)), 1.0)
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1440)), 2.0)
	assert_eq(DisplayScale.factor_for(Vector2i(3024, 1964)), 2.0, "a 16-inch MacBook's screen")
	assert_eq(DisplayScale.factor_for(Vector2i(3840, 2160)), 3.0, "4K")
	assert_eq(DisplayScale.factor_for(Vector2i(5120, 2880)), 4.0, "5K")


func test_a_window_smaller_than_the_base_is_still_drawn_at_one():
	assert_eq(DisplayScale.factor_for(Vector2i(800, 600)), 1.0)
	assert_eq(DisplayScale.factor_for(Vector2i(1, 1)), 1.0)


func test_the_short_axis_decides():
	assert_eq(DisplayScale.factor_for(Vector2i(3440, 1440)), 2.0, "ultrawide: the height caps it")
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 4000)), 2.0, "tall: the width caps it")


func test_apply_makes_the_window_the_base_and_the_factor_the_scale():
	var window := Window.new()
	window.size = Vector2i(1900, 1000)
	DisplayScale.apply(window)
	assert_eq(window.content_scale_size, Vector2i(1900, 1000), "no expansion to a base aspect, so no margins")
	assert_eq(window.content_scale_factor, 1.0)
	window.size = Vector2i(3024, 1964)
	DisplayScale.apply(window)
	assert_eq(window.content_scale_size, Vector2i(3024, 1964))
	assert_eq(window.content_scale_factor, 2.0, "the world sees 1512x982 drawn at exactly 2")
	window.free()


func test_the_players_own_scale_beats_the_automatic_one():
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1440), 1.25), 1.25, "a desktop at 1.25")
	assert_eq(DisplayScale.factor_for(Vector2i(2340, 1080), 2.5, true), 2.5, "a phone past the 2x default")
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1440), 0.0), 2.0, "0 is automatic")


func test_choosing_a_scale_applies_it_to_the_window_at_once_and_on_every_resize():
	var window := Window.new()
	window.size = Vector2i(1900, 1000)
	var display := DisplayScale.new()
	display.window = window
	display.chosen = 2.25
	assert_eq(window.content_scale_factor, 2.25)
	window.size = Vector2i(1200, 900)
	display._on_resized()
	assert_eq(window.content_scale_factor, 2.25, "a resize keeps the player's choice")
	display.chosen = 0.0
	assert_eq(window.content_scale_factor, 1.0, "back to automatic")
	display.free()
	window.free()


func test_a_scale_reads_as_a_player_would_write_it():
	assert_eq(DisplayScale.label(1.75), "1.75")
	assert_eq(DisplayScale.label(2.0), "2")
	assert_eq(DisplayScale.label(1.5), "1.5")


func test_apply_ignores_a_window_with_no_size_yet():
	var window := Window.new()
	window.content_scale_size = Vector2i(7, 7)
	window.size = Vector2i(0, 0)
	DisplayScale.apply(window)
	assert_eq(window.content_scale_size, Vector2i(7, 7), "left alone rather than set to nothing")
	window.free()


func test_in_the_tree_it_follows_every_resize_of_its_window():
	var window := Window.new()
	window.size = Vector2i(1280, 720)
	var scale := DisplayScale.new()
	scale.window = window
	add_child(scale)
	assert_eq(window.content_scale_size, Vector2i(1280, 720), "applied on entering")
	assert_eq(window.content_scale_factor, 1.0)
	window.size = Vector2i(2560, 1440)
	window.size_changed.emit()
	assert_eq(window.content_scale_size, Vector2i(2560, 1440))
	assert_eq(window.content_scale_factor, 2.0)
	remove_child(scale)
	scale.free()
	window.size = Vector2i(3840, 2160)
	window.size_changed.emit()
	assert_eq(window.content_scale_factor, 2.0, "no longer followed once out of the tree")
	window.free()


func test_under_a_headless_display_it_leaves_the_shared_window_alone():
	var root := get_tree().root
	var was := root.content_scale_size
	var scale := DisplayScale.new()
	add_child(scale)
	assert_null(scale.window, "there is no screen to fill")
	assert_eq(root.content_scale_size, was)
	remove_child(scale)
	scale.free()


func test_main_carries_one():
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var config := ClientConfig.new()
	config.autoconnect = false
	main.config = config
	add_child_autofree(main)
	var found := false
	for child in main.get_children():
		found = found or child is DisplayScale
	assert_true(found)


## What the world is drawn at on screen: the camera's zoom times the canvas's.
func _world_on_screen(window: Window, camera: Camera2D) -> float:
	return camera.zoom.x * window.content_scale_factor


func test_the_ui_scale_leaves_the_world_where_it_was():
	var window := Window.new()
	window.size = Vector2i(1900, 1000)
	var camera := Camera2D.new()
	var display := DisplayScale.new()
	display.window = window
	display.camera = camera
	assert_eq(_world_on_screen(window, camera), 2.0, "two pixels a world unit at 1x, as always")
	display.chosen = 2.5
	assert_eq(window.content_scale_factor, 2.5, "the UI grows")
	assert_almost_eq(_world_on_screen(window, camera), 2.0, 0.0001, "the world does not")
	assert_almost_eq(camera.zoom.x, 0.8, 0.0001)
	display.world_chosen = 3.0
	assert_almost_eq(_world_on_screen(window, camera), 6.0, 0.0001, "the world zoom alone moves the world")
	assert_eq(window.content_scale_factor, 2.5, "and leaves the UI")
	window.size = Vector2i(3024, 1964)
	display._on_resized()
	assert_almost_eq(_world_on_screen(window, camera), 6.0, 0.0001, "kept through a resize")
	display.world_chosen = 0.0
	assert_almost_eq(_world_on_screen(window, camera), 4.0, 0.0001, "automatic: the window's whole-number fit")
	display.free()
	camera.free()
	window.free()


func test_the_settings_drive_both_scales():
	var settings := GameSettings.new()
	var display := DisplayScale.new()
	display.follow(settings)
	settings.set_scale(ScaleRow.WORLD, 2.5)
	assert_eq(display.world_chosen, 2.5)
	assert_eq(display.chosen, 0.0, "the UI's untouched")
	settings.set_scale(ScaleRow.UI, 1.5)
	assert_eq(display.chosen, 1.5)
	display.free()


func test_every_page_and_the_phone_app_draw_the_ui_at_2x_and_the_world_at_1_25x():
	# A laptop's browser, a 1080p monitor's, a 4K one's and a phone's.
	for size in [Vector2i(2400, 1500), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(2340, 1080)]:
		assert_eq(DisplayScale.factor_for(size, 0.0, true), 2.0, "UI 2x at %s" % size)
		assert_eq(DisplayScale.auto_world(size, true), 1.25, "world 1.25x at %s" % size)
	assert_almost_eq(DisplayScale.camera_zoom(Vector2i(1920, 1080), 0.0, 0.0, true), 1.25, 0.0001,
		"the camera: 2 x 1.25 over the UI's 2")
	assert_almost_eq(DisplayScale.camera_zoom(Vector2i(1920, 1080), 3.0, 0.0, true), 2.0 * 1.25 / 3.0, 0.0001,
		"a bigger UI, the same world")


func test_the_desktop_app_keeps_the_whole_number_fit():
	assert_eq(DisplayScale.factor_for(Vector2i(1280, 720)), 1.0)
	assert_eq(DisplayScale.auto_world(Vector2i(1280, 720)), 1.0)
	assert_eq(DisplayScale.auto_world(Vector2i(2560, 1440)), 2.0)


func test_a_players_choice_beats_the_web_defaults():
	var window := Window.new()
	window.size = Vector2i(2400, 1500)
	var camera := Camera2D.new()
	var display := DisplayScale.new()
	display.web = true
	display.window = window
	display.camera = camera
	assert_eq(window.content_scale_factor, 2.0)
	assert_almost_eq(_world_on_screen(window, camera), 2.5, 0.0001, "1.25x auto")
	display.chosen = 1.5
	display.world_chosen = 2.0
	assert_eq(window.content_scale_factor, 1.5)
	assert_almost_eq(_world_on_screen(window, camera), 4.0, 0.0001, "2x chosen")
	display.free()
	camera.free()
	window.free()
