extends GutTest

## The minimap's arithmetic: where it looks and how its pixels map to the world.

const MAP := Vector2i(100, 50)


func test_the_window_is_the_zoomed_map_centred_on_the_player():
	var window := MinimapView.window(MAP, 0.5, Vector2(50, 25))
	assert_eq(window, Rect2(25, 12.5, 50, 25))


func test_the_window_stops_at_the_map_s_edges():
	assert_eq(MinimapView.window(MAP, 0.5, Vector2(3, 2)).position, Vector2.ZERO, "top left")
	assert_eq(MinimapView.window(MAP, 0.5, Vector2(99, 49)).position, Vector2(50, 25), "bottom right")


func test_the_whole_map_needs_no_centring():
	assert_eq(MinimapView.window(MAP, 1.0, Vector2(80, 10)), Rect2(0, 0, 100, 50))


func test_world_to_panel_and_back():
	var window := Rect2(25, 12.5, 50, 25)
	# Tile (50, 25) is the window's centre, so the panel's centre.
	var at := MinimapView.to_panel(Vector2(50, 25) * 32.0, window, 200.0)
	assert_eq(at, Vector2(100, 100))
	assert_eq(MinimapView.to_world(at, window, 200.0), Vector2(50, 25) * 32.0)
	assert_eq(MinimapView.to_panel(Vector2(25, 12.5) * 32.0, window, 200.0), Vector2.ZERO, "the window's corner")
	assert_eq(MinimapView.to_panel(Vector2.ZERO, Rect2(), 200.0), Vector2.ZERO, "no window, nowhere")


func test_a_new_map_opens_on_about_sixty_four_tiles():
	assert_eq(MinimapView.initial_zoom(Vector2i(128, 128)), 0.5, "the nexus: half of it")
	assert_eq(MinimapView.initial_zoom(Vector2i(40, 30)), 1.0, "a small map: all of it")
	assert_eq(MinimapView.initial_zoom(Vector2i(320, 320)), 0.2, "the beach: a fifth")
	assert_eq(MinimapView.initial_zoom(Vector2i(1000, 1000)), 0.1, "never tighter than a tenth")
	assert_eq(MinimapView.initial_zoom(Vector2i.ZERO), 1.0, "no map, no division")


func test_a_wheel_notch_is_a_twentieth_within_the_limits():
	assert_almost_eq(MinimapView.step(0.5, -1), 0.45, 0.0001)
	assert_almost_eq(MinimapView.step(0.5, 1), 0.55, 0.0001)
	assert_eq(MinimapView.step(0.05, -1), 0.05, "no closer than a twentieth")
	assert_eq(MinimapView.step(1.0, 1), 1.0, "no further than the whole map")


func test_the_marker_points_where_the_sprite_faces():
	assert_eq(MinimapView.heading("front", false), Vector2.DOWN)
	assert_eq(MinimapView.heading("back", false), Vector2.UP)
	assert_eq(MinimapView.heading("side", false), Vector2.RIGHT)
	assert_eq(MinimapView.heading("side", true), Vector2.LEFT)


func test_the_arrow_is_a_triangle_with_its_tip_forward():
	var up := MinimapView.arrow(Vector2(100, 100), Vector2.UP)
	assert_eq(up.size(), 3)
	assert_almost_eq(up[0].y, 95.0, 0.001, "tip 5 up")
	assert_almost_eq(up[1].x, 96.0, 0.001)
	var right := MinimapView.arrow(Vector2(100, 100), Vector2.RIGHT)
	assert_almost_eq(right[0].x, 105.0, 0.001, "tip 5 to the right")
	assert_almost_eq(right[0].y, 100.0, 0.001)
