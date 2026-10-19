extends GutTest

## A layer's phone boost gives way to a panel wider or taller than the
## screen, never below one, and a desktop's boost of one never moves.


func test_a_panel_that_fits_keeps_the_whole_boost():
	assert_eq(TouchFrame.fitted(2.0, Vector2(1688, 780), Vector2(400, 300)), 2.0)


func test_a_panel_wider_than_the_screen_takes_less():
	var factor := TouchFrame.fitted(2.0, Vector2(780, 1688), Vector2(560, 300))
	assert_almost_eq(factor * 560.0, 780.0 - TouchFrame.MARGIN * 2.0, 0.01)


func test_the_boost_never_goes_under_one():
	assert_eq(TouchFrame.fitted(2.0, Vector2(400, 800), Vector2(900, 300)), 1.0)
	assert_eq(TouchFrame.fitted(1.0, Vector2(400, 800), Vector2(900, 300)), 1.0)


func test_a_row_of_buttons_too_wide_for_the_screen_wraps_above():
	var cluster: TouchCluster = autofree(TouchCluster.new(true))
	cluster.show_combat(true)
	cluster.place(Vector2(390, 844), Vector2(20, 8))
	for button in [cluster._hp, cluster._mp, cluster._nexus, cluster._companion]:
		assert_true(button.position.x >= 0.0, "on screen")
	assert_lt(cluster._companion.position.y, cluster._hp.position.y, "the last one a row up")
