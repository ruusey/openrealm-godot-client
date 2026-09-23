extends GutTest

## Walk cadence. Distance-based, so the gait scales with speed and matches the
## web and native clients rather than running on its own timer.

var cycle: WalkCycle


func before_each():
	cycle = WalkCycle.new()


func _walk(pace: float, seconds: float) -> void:
	cycle.advance(pace, seconds)


func test_a_frame_swaps_every_28_pixels():
	# 28px at 1px/tick and 64 ticks/s is 28/64 s.
	_walk(1.0, 27.0 / 64.0)
	assert_eq(cycle.frame, 0, "not there yet")
	_walk(1.0, 2.0 / 64.0)
	assert_eq(cycle.frame, 1, "crossed 28px")


func test_the_gait_scales_with_speed():
	var slow := WalkCycle.new()
	var fast := WalkCycle.new()
	slow.advance(2.0, 1.0)
	fast.advance(6.0, 1.0)
	assert_eq(slow.frame, int(2.0 * 64.0 / WalkCycle.PX_PER_FRAME))
	assert_gt(fast.frame, slow.frame, "three times the speed, three times the footfalls")


func test_leftover_distance_carries_over():
	# Without a carry the cadence would drift against the distance travelled.
	_walk(1.0, 40.0 / 64.0)
	assert_eq(cycle.frame, 1)
	assert_almost_eq(cycle.distance, 12.0, 0.001, "40 - 28 carried into the next frame")


func test_a_long_frame_can_advance_several_frames():
	_walk(4.0, 1.0)
	assert_eq(cycle.frame, int(4.0 * 64.0 / WalkCycle.PX_PER_FRAME))


func test_standing_still_returns_to_the_idle_frame():
	_walk(4.0, 0.5)
	assert_gt(cycle.frame, 0)
	cycle.advance(0.0, 0.1)
	assert_eq(cycle.frame, 0, "a stopped character settles, not freezes mid-stride")
	assert_eq(cycle.distance, 0.0)


func test_a_crawl_counts_as_standing_still():
	# Matches `pace > 0.1f` in both reference clients.
	_walk(WalkCycle.MOVING_EPSILON, 10.0)
	assert_eq(cycle.frame, 0, "sub-epsilon drift is not a walk")


func test_a_slow_tile_stretches_the_gait():
	# pace is the APPLIED speed, so the server's 1/3 slow divisor reaches the
	# animation without the cycle knowing about tiles.
	var normal := WalkCycle.new()
	var slowed := WalkCycle.new()
	normal.advance(3.0, 1.0)
	slowed.advance(1.0, 1.0)
	assert_gt(normal.frame, slowed.frame, "three times the pace, three times the footfalls")
