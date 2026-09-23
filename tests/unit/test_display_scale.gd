extends GutTest

## DisplayScale: the window is the base, the scale is a whole number.


func test_the_scale_steps_at_whole_multiples_of_the_base():
	assert_eq(DisplayScale.factor_for(Vector2i(1280, 720)), 1)
	assert_eq(DisplayScale.factor_for(Vector2i(2559, 1440)), 1, "one short of 2x on either axis is 1x")
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1439)), 1)
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 1440)), 2)
	assert_eq(DisplayScale.factor_for(Vector2i(3024, 1964)), 2, "a 16-inch MacBook's screen")
	assert_eq(DisplayScale.factor_for(Vector2i(3840, 2160)), 3, "4K")
	assert_eq(DisplayScale.factor_for(Vector2i(5120, 2880)), 4, "5K")


func test_a_window_smaller_than_the_base_is_still_drawn_at_one():
	assert_eq(DisplayScale.factor_for(Vector2i(800, 600)), 1)
	assert_eq(DisplayScale.factor_for(Vector2i(1, 1)), 1)


func test_the_short_axis_decides():
	assert_eq(DisplayScale.factor_for(Vector2i(3440, 1440)), 2, "ultrawide: the height caps it")
	assert_eq(DisplayScale.factor_for(Vector2i(2560, 4000)), 2, "tall: the width caps it")


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
