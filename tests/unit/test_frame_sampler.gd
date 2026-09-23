extends GutTest

## The summary maths behind the live performance test's verdict.


func test_summarises_frames_into_fps_and_percentiles():
	var frames: Array[float] = [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 60.0]
	var s := FrameSampler.summarise(frames, 300, {"enemies": 102, "bullets": 478})
	assert_eq(s["frames"], 10)
	assert_eq(s["total_ms"], 150.0)
	assert_almost_eq(s["fps"], 66.667, 0.01, "frames over the wall time they took, not over the mean")
	assert_eq(s["mean_ms"], 15.0)
	assert_eq(s["max_ms"], 60.0)
	assert_eq(s["p95_ms"], 60.0, "the tenth of ten is the 95th percentile")
	assert_eq(s["draw_calls"], 300)


func test_p95_sits_below_a_single_hitch_in_a_long_run():
	var frames: Array[float] = []
	for i in 99:
		frames.append(8.0)
	frames.append(200.0)
	var s := FrameSampler.summarise(frames, 0, {})
	assert_eq(s["p95_ms"], 8.0, "one hitch in a hundred is the max, not the p95")
	assert_eq(s["max_ms"], 200.0)


func test_no_frames_is_an_empty_summary():
	var none: Array[float] = []
	assert_eq(FrameSampler.summarise(none, 0, {}), {})
	assert_string_contains(FrameSampler.describe("x", {}), "no frames")


func test_the_line_names_what_was_drawn():
	var frames: Array[float] = [4.0, 4.0]
	var line := FrameSampler.describe("horde", FrameSampler.summarise(frames, 12, {"enemies": 3, "bullets": 4}))
	assert_string_contains(line, "250.0 fps")
	assert_string_contains(line, "draw calls 12")
	assert_string_contains(line, "3 enemies, 4 bullets")
