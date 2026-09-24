extends GutTest

## The per-frame motion measurement behind the screenshot key.

var trace: MotionTrace


func before_each():
	trace = MotionTrace.new()


func test_even_motion_reads_as_a_steady_displacement():
	trace.start(0, 4)
	assert_true(trace.active())
	# Five positions make four frames, each a step of 2.4px in 8ms.
	for i in 5:
		var line := trace.sample(0.008, Vector2(2.4 * i, 0.0), i, 0)
		if i < 4:
			assert_eq(line, "", "still sampling")
		else:
			assert_string_contains(line, "4 frames in 32 ms (8.0 ms each)")
			assert_string_contains(line, "ticks/frame 1:4")
			assert_string_contains(line, "moved/frame 2.40 px (sd 0.00, min 2.40, max 2.40)")
			assert_string_contains(line, "corrections 0")
	assert_false(trace.active(), "done after the wanted frames")
	assert_eq(trace.sample(0.008, Vector2.ZERO, 9, 0), "", "and silent after")


func test_the_ghost_reads_as_alternating_displacement_and_ticks():
	# A 64Hz sprite on a 120Hz panel: a step every other frame.
	trace.start(2, 4)
	var positions := [0.0, 0.0, 4.8, 4.8, 9.6]
	var seqs := [0, 0, 1, 1, 2]
	var line := ""
	for i in 5:
		line = trace.sample(0.0083, Vector2(positions[i], 0.0), seqs[i], 5)
	assert_string_contains(line, "ticks/frame 0:2 1:2")
	assert_string_contains(line, "moved/frame 2.40 px (sd 2.40, min 0.00, max 4.80)")
	assert_string_contains(line, "corrections 3", "counted from the start of the trace")
	assert_eq(trace.last["ticks"], {0: 2, 1: 2})
	assert_eq(trace.last["stalls"], 2, "the two frames that did not move")
	assert_string_contains(line, "stalls 2")
	assert_almost_eq(trace.last["sd"], 2.4, 0.001, "and the numbers are there for a test to judge")


func test_observe_reads_the_realm_state():
	var state := RealmState.new(null)
	state.local.id = 1
	trace.start(0, 1)
	trace.observe(0.008, state)
	assert_true(trace.active(), "one position is no frame yet")
	trace.observe(0.008, state)
	assert_false(trace.active(), "the second completes it, and it printed")


func test_the_sprite_off_the_cameras_centre_is_the_worst_frame():
	# The camera follows the player exactly, so a sprite drawn anywhere but
	# the viewport's centre is a frame whose parts disagree.
	var to_screen := Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(100.0, 100.0))
	trace.start(0, 1)
	trace.sample_draw(to_screen, Vector2(100.0, 100.0), Vector2(600.0, 600.0))
	assert_eq(trace.off_centre, 0.0, "dead centre")
	trace.sample_draw(to_screen, Vector2(101.5, 100.0), Vector2(600.0, 600.0))
	assert_almost_eq(trace.off_centre, 3.0, 0.001, "1.5 world units at 2x is 3 pixels off")
	trace.sample_draw(to_screen, Vector2(100.5, 100.0), Vector2(600.0, 600.0))
	assert_almost_eq(trace.off_centre, 3.0, 0.001, "the worst, not the last")
	trace.sample(0.008, Vector2.ZERO, 0, 0)
	var line := trace.sample(0.008, Vector2(1.0, 0.0), 1, 0)
	assert_string_contains(line, "off-centre 3.00 px")
	assert_almost_eq(trace.last["off_centre"], 3.0, 0.001)
	trace.sample_draw(to_screen, Vector2(150.0, 100.0), Vector2(600.0, 600.0))
	assert_almost_eq(trace.off_centre, 3.0, 0.001, "nothing sampled once the trace is done")
	trace.start(0, 1)
	assert_eq(trace.off_centre, 0.0, "a new trace starts clean")
	trace.sample_draw(to_screen, Vector2(100.25, 100.25), Vector2(600.0, 600.0))
	assert_almost_eq(trace.off_centre, 0.5, 0.001, "half a pixel on each axis is half a pixel, not 0.71")


func test_an_empty_trace_says_so():
	assert_eq(MotionTrace.measure([], 0), {})
	assert_eq(MotionTrace.summary({}), "[trace] no frames")
