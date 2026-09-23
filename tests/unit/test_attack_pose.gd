extends GutTest

## The swing a character plays while shooting. Wall-clock driven, plays once,
## and names its own clip -- all three of which differ from the walk cycle.

var pose: AttackPose


func before_each():
	pose = AttackPose.new()


# --- which clip -------------------------------------------------------------

func test_the_dominant_axis_picks_the_clip():
	assert_eq(AttackPose.clip_for(Vector2(10.0, 1.0)), "side")
	assert_eq(AttackPose.clip_for(Vector2(-10.0, 1.0)), "side")
	assert_eq(AttackPose.clip_for(Vector2(1.0, 10.0)), "down", "+Y is down the screen")
	assert_eq(AttackPose.clip_for(Vector2(1.0, -10.0)), "up")


func test_a_direction_with_no_dominant_axis_faces_front():
	# The web client's cast path picks the front clip for exactly this.
	assert_eq(AttackPose.clip_for(Vector2.ZERO), "down")


func test_the_tokens_are_not_the_walk_cycles():
	# Content names them attack_down and walk_front. Handing this a walk token
	# resolves to a clip that does not exist, and ClassSprites falls back to
	# idle without a word -- which looks like the attack simply not playing.
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		assert_false(AttackPose.clip_for(direction) in ["front", "back"],
			"%s produced a walk-cycle token" % direction)


func test_a_leftward_swing_mirrors():
	pose.begin(Vector2(-10.0, 1.0))
	assert_eq(pose.facing, "side")
	assert_true(pose.facing_left)

	pose.begin(Vector2(10.0, 1.0))
	assert_false(pose.facing_left)


func test_a_vertical_swing_leaves_the_mirror_alone():
	# There is nothing to mirror in attack_up or attack_down, and flipping on
	# the sign of a near-zero x would make a straight-up shot jitter.
	pose.begin(Vector2(-10.0, 1.0))
	assert_true(pose.facing_left)
	pose.begin(Vector2(-0.001, -10.0))
	assert_eq(pose.facing, "up")
	assert_true(pose.facing_left, "kept from the last side swing, not recomputed")


# --- timing -----------------------------------------------------------------

func test_nothing_plays_until_a_shot():
	assert_false(pose.is_active())
	pose.tick(1.0)
	assert_false(pose.is_active(), "ticking alone starts nothing")


func test_frames_advance_on_the_wall_clock():
	# Not on distance travelled. Both references are explicit, and the native
	# client records the trap: through the pace path, a standing-still attack
	# sticks on frame 0.
	pose.begin(Vector2.RIGHT)
	assert_eq(pose.frame, 0)
	pose.tick(AttackPose.FRAME_SECONDS * 0.5)
	assert_eq(pose.frame, 0, "half a frame is not a frame")
	pose.tick(AttackPose.FRAME_SECONDS * 0.6)
	assert_eq(pose.frame, 1)


func test_a_long_frame_advances_every_frame_it_covers():
	# A hitch should not swallow frames; the native client loops for this.
	pose.begin(Vector2.RIGHT)
	pose.tick(AttackPose.FRAME_SECONDS * 3.0 + 0.001)
	assert_eq(pose.frame, 3)


func test_the_swing_ends_on_its_own():
	pose.begin(Vector2.RIGHT)
	pose.tick(AttackPose.DURATION + 0.001)
	assert_false(pose.is_active())
	assert_eq(pose.frame, 0, "and resets, so the next shot starts at the beginning")


func test_it_lasts_the_whole_window():
	pose.begin(Vector2.RIGHT)
	pose.tick(AttackPose.DURATION * 0.9)
	assert_true(pose.is_active())


func test_a_new_shot_restarts_it():
	pose.begin(Vector2.RIGHT)
	pose.tick(AttackPose.FRAME_SECONDS * 2.5)
	assert_eq(pose.frame, 2)
	pose.begin(Vector2.RIGHT)
	assert_eq(pose.frame, 0, "mid-swing, a second shot starts over")


func test_the_counter_runs_past_a_short_clip():
	# Where a clip ends is the content layer's business -- this only counts,
	# and ClassSprites holds the last frame. Counting past a two-frame clip is
	# what proves the holding is not being done here by accident.
	pose.begin(Vector2.RIGHT)
	for i in 3:
		pose.tick(AttackPose.FRAME_SECONDS)
	assert_eq(pose.frame, 3, "three frames fit in the window")
	assert_true(pose.is_active(), "and the window is not over yet")


func test_the_window_bounds_how_far_it_can_get():
	# 300ms at 80ms a frame is four frames, and the fourth tick ends it.
	pose.begin(Vector2.RIGHT)
	for i in 10:
		pose.tick(AttackPose.FRAME_SECONDS)
	assert_false(pose.is_active())
