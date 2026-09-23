extends GutTest

## World positions moved to whole screen pixels, through whatever the canvas
## transform is.


func test_snaps_through_a_fractional_zoomed_canvas():
	var parent := Node2D.new()
	parent.position = Vector2(0.25, 0.75)
	parent.scale = Vector2(2.0, 2.0)
	add_child_autofree(parent)
	var canvas := Node2D.new()
	parent.add_child(canvas)
	# (10.3, 5.2) lands on screen at (20.85, 11.15); the nearest pixel is
	# (21, 11), which is (10.375, 5.125) in the world.
	var snapped := PixelSnap.world(canvas, Vector2(10.3, 5.2))
	assert_almost_eq(snapped.x, 10.375, 0.0001)
	assert_almost_eq(snapped.y, 5.125, 0.0001)
	var on_screen: Vector2 = canvas.get_global_transform_with_canvas() * snapped
	assert_almost_eq(on_screen.x, 21.0, 0.0001, "a whole pixel")
	assert_almost_eq(on_screen.y, 11.0, 0.0001)


func test_a_whole_pixel_is_left_alone():
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	assert_eq(PixelSnap.world(canvas, Vector2(7.0, 3.0)), Vector2(7.0, 3.0))
	assert_eq(PixelSnap.world(canvas, Vector2(7.4, 3.6)), Vector2(7.0, 4.0))
