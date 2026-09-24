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


func test_the_camera_puts_the_worlds_origin_on_a_whole_pixel():
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.5, 2.5)
	add_child_autofree(camera)
	camera.make_current()
	PixelSnap.camera(camera, Vector2(100.13, 57.71))
	var origin := camera.get_viewport().get_canvas_transform().origin
	assert_almost_eq(origin.x, roundf(origin.x), 0.0001, "a whole pixel across")
	assert_almost_eq(origin.y, roundf(origin.y), 0.0001, "and down")
	# Never further than half a pixel, 0.2 world units at 2.5x.
	assert_almost_eq(camera.position.x, 100.13, 0.2)
	assert_almost_eq(camera.position.y, 57.71, 0.2)
	assert_ne(camera.position, Vector2(100.13, 57.71), "moved off the fraction")


func test_a_body_and_the_ground_keep_their_distance_as_the_camera_creeps():
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child_autofree(camera)
	camera.make_current()
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	# The flame snapped to the pixel grid against the world's origin, where
	# the ground is drawn from, while the camera slides a tenth at a time.
	var gaps := {}
	for step in 20:
		PixelSnap.camera(camera, Vector2(10.0 + step * 0.1, 20.0))
		var to_screen := canvas.get_global_transform_with_canvas()
		var flame := to_screen * PixelSnap.world(canvas, Vector2(3.3, 7.7))
		gaps[flame - to_screen.origin] = true
	assert_eq(gaps.size(), 1, "the flame never slips against the ground: %s" % [gaps.keys()])


func test_the_followed_body_stays_on_one_pixel_at_a_browsers_zoom():
	var camera := Camera2D.new()
	# A browser's 1.25: half a 28-unit player is 17.5 pixels, so the body
	# the camera centres on stands on a half pixel.
	camera.zoom = Vector2(1.25, 1.25)
	add_child_autofree(camera)
	camera.make_current()
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	var spots := {}
	for step in 40:
		var feet := Vector2(1000.0, 800.0) + Vector2(0.37, 0.37) * step
		PixelSnap.camera(camera, feet + Vector2(14.0, 14.0), feet)
		var origin := camera.get_viewport().get_canvas_transform().origin
		assert_almost_eq(origin, origin.round(), Vector2(0.001, 0.001), "the ground on the grid")
		var body := canvas.get_global_transform_with_canvas() * PixelSnap.world(canvas, feet)
		spots[body.round()] = true
	assert_eq(spots.size(), 1, "the body never hops: %s" % [spots.keys()])
