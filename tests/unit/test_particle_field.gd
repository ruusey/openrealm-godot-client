extends GutTest

## The particles behind projectiles: emitted per bullet, burst where one
## lands, stepped, faded and dropped.

const TRAIL_GROUP := 1
const IMPACT_GROUP := 2
const MUZZLE_GROUP := 3
const PLAIN_GROUP := 4
const FRAME := 1.0 / 60.0

var art: ProjectileArt
var field: ParticleField


func before_each():
	var library := ContentLibrary.new()
	library.projectile_groups = {
		TRAIL_GROUP: {"fx": [{"type": "trail", "rate": 60, "lifeMs": 1000, "size": 10, "spread": 0.5, "color": "0xff0000"}]},
		IMPACT_GROUP: {"fx": [{"type": "impact", "count": 5, "lifeMs": 400, "size": 8, "speed": 100, "color": "#00ff00"}]},
		MUZZLE_GROUP: {"fx": [{"type": "muzzle", "count": 3}]},
		PLAIN_GROUP: {"fx": [{"type": "spin", "rate": 6}]},
	}
	art = ProjectileArt.new(library)
	field = ParticleField.new(art)
	field.rng.seed = 7


func _bullet(group: int, at := Vector2(100, 100)) -> Dictionary:
	# Straight and still, so the centre the tests reason about stays put.
	return Projectile.from_wire({"id": 1, "projectileId": group, "size": 8,
		"pos": {"x": at.x, "y": at.y}, "angle": 0.0, "magnitude": 0.0, "range": 1000.0,
		"flags": [], "invert": false, "timeStep": 0, "amplitude": 0, "frequency": 0,
		"orbitCenterX": 0.0, "orbitCenterY": 0.0, "orbitRadius": 0.0, "orbitPhase": 0.0,
		"damage": 1, "createdTime": 0}, 0)


# --- trails ------------------------------------------------------------------

func test_a_trail_is_emitted_at_the_group_s_rate():
	var bullets := {1: _bullet(TRAIL_GROUP)}
	field.advance(FRAME, bullets)
	assert_eq(field.count, 1, "60 a second is one a frame")
	field.advance(FRAME, bullets)
	assert_eq(field.count, 2)


func test_a_slow_rate_accumulates_across_frames():
	art._library.projectile_groups[TRAIL_GROUP]["fx"][0]["rate"] = 24
	var bullets := {1: _bullet(TRAIL_GROUP)}
	for i in 2:
		field.advance(0.01, bullets)
	assert_eq(field.count, 0, "0.48 accumulated, nothing yet")
	for i in 3:
		field.advance(0.01, bullets)
	assert_eq(field.count, 1, "1.2 accumulated: one, with 0.2 carried")
	assert_almost_eq(float(bullets[1]["fx_acc"]), 0.2, 0.001, "the remainder rides on the bullet")


func test_no_frame_emits_more_than_four():
	art._library.projectile_groups[TRAIL_GROUP]["fx"][0]["rate"] = 1000
	field.advance(0.04, {1: _bullet(TRAIL_GROUP)})
	assert_eq(field.count, ParticleEmitter.MAX_TRAIL_PER_FRAME)


func test_a_stalled_frame_is_clamped():
	# A whole second at 60 a second would be sixty; the step is clamped to
	# 48ms, which is 2.88 -- two -- so a hitch neither floods nor teleports.
	field.advance(1.0, {1: _bullet(TRAIL_GROUP)})
	assert_eq(field.count, 2)


func test_a_trail_particle_starts_near_the_bullet_small_and_grows():
	field.advance(FRAME, {1: _bullet(TRAIL_GROUP, Vector2(96, 96))})
	assert_eq(field.count, 1)
	# The bullet's centre is (100, 100); the particle starts within half
	# the fx size of it, then moved one frame.
	assert_lt(absf(field.x[0] - 100.0), 5.0 + 1.0)
	assert_lt(absf(field.y[0] - 100.0), 5.0 + 1.0)
	assert_almost_eq(field.size_start[0], 5.5, 0.001, "0.55 of the size")
	assert_almost_eq(field.size_end[0], 15.0, 0.001, "to 1.5 of it")
	assert_between(field.max_life[0], 0.75, 1.25, "0.75 to 1.25 of lifeMs")
	assert_eq(field.tint[0], Color(1, 0, 0), "0xff0000")
	var speed := Vector2(field.vx[0], field.vy[0]).length()
	# spread 0.5 x 20 = 10 a second, 40% to 120% of it, less one frame of drag.
	assert_between(speed, 4.0 * 0.9, 12.0)


func test_missing_and_zero_fields_take_the_references_defaults():
	art._library.projectile_groups[TRAIL_GROUP]["fx"][0] = {"type": "trail", "rate": 0}
	field.advance(0.05, {1: _bullet(TRAIL_GROUP)})
	assert_eq(field.count, 1, "rate 0 is read as 24, and 0.05s of 24 is one")
	assert_almost_eq(field.size_start[0], 6.0 * 0.55, 0.001)
	assert_between(field.max_life[0], 0.375, 0.625, "500ms")
	assert_eq(field.tint[0], ParticleEmitter.TRAIL_TINT)


func test_a_group_without_a_trail_emits_nothing():
	field.advance(FRAME, {1: _bullet(PLAIN_GROUP), 2: _bullet(999)})
	assert_eq(field.count, 0)


func test_without_content_nothing_is_emitted_but_the_step_still_runs():
	var bare := ParticleField.new()
	bare.spawn(Vector2.ZERO, Vector2(60, 0), 1.0, 1.0, 1.0, Color.WHITE)
	bare.advance(FRAME, {1: _bullet(TRAIL_GROUP)})
	assert_eq(bare.count, 1)
	assert_almost_eq(bare.x[0], 1.0, 0.001, "moved one frame")


# --- bursts ------------------------------------------------------------------

func test_an_impact_bursts_where_the_bullet_was_when_it_vanished():
	var bullets := {1: _bullet(IMPACT_GROUP, Vector2(200, 300))}
	field.advance(FRAME, bullets)
	assert_eq(field.count, 0, "alive: nothing yet")
	bullets.clear()
	field.advance(FRAME, bullets)
	assert_eq(field.count, 5, "the count, at its last centre")
	for i in 5:
		var speed := Vector2(field.vx[i], field.vy[i]).length()
		assert_between(speed, 40.0 * 0.9, 110.0, "40% to 110% of 100")
		assert_between(field.max_life[i], 0.28, 0.64, "70% to 130% of 400ms")
		assert_almost_eq(field.size_start[i], 8.0 * 1.3, 0.001)
		assert_almost_eq(field.size_end[i], 8.0 * 0.25, 0.001)
		assert_eq(field.tint[i], Color(0, 1, 0))
		# One frame out from (204, 304), the bullet's centre.
		assert_lt(Vector2(field.x[i], field.y[i]).distance_to(Vector2(204, 304)), 2.0)
	field.advance(FRAME, bullets)
	assert_eq(field.count, 5, "and only once")


func test_a_muzzle_bursts_once_when_the_bullet_first_appears():
	var bullets := {1: _bullet(MUZZLE_GROUP)}
	field.advance(FRAME, bullets)
	assert_eq(field.count, 3)
	field.advance(FRAME, bullets)
	assert_eq(field.count, 3, "seen already")
	bullets.clear()
	field.advance(FRAME, bullets)
	assert_eq(field.count, 3, "no impact on this group")


func test_a_burst_takes_the_references_defaults():
	ParticleEmitter.burst(field, Vector2.ZERO, {})
	assert_eq(field.count, 8)
	assert_almost_eq(field.size_start[0], 5.0 * 1.3, 0.001)
	assert_eq(field.tint[0], Color.WHITE)


# --- the step ----------------------------------------------------------------

func test_a_particle_moves_slows_ages_and_dies():
	field.spawn(Vector2(10, 20), Vector2(60, 0), 0.5, 4.0, 8.0, Color.RED)
	field.advance(FRAME, {})
	assert_almost_eq(field.x[0], 11.0, 0.001, "60 a second is one a frame")
	assert_almost_eq(field.vx[0], 60.0 * exp(-3.0 * FRAME), 0.001, "e^-3 a second, not 0.9 a frame")
	assert_almost_eq(field.life[0], 0.5 - FRAME, 0.0001)
	for i in 30:
		field.advance(FRAME, {})
	assert_eq(field.count, 0, "gone after half a second")


func test_the_dead_are_dropped_and_the_living_packed_forward():
	field.spawn(Vector2(1, 1), Vector2.ZERO, 0.01, 1.0, 1.0, Color.RED)
	field.spawn(Vector2(2, 2), Vector2.ZERO, 1.0, 2.0, 3.0, Color.GREEN)
	field.spawn(Vector2(3, 3), Vector2.ZERO, 0.01, 1.0, 1.0, Color.RED)
	field.spawn(Vector2(4, 4), Vector2.ZERO, 1.0, 4.0, 5.0, Color.BLUE)
	field.advance(FRAME, {})
	assert_eq(field.count, 2)
	assert_eq(field.x[0], 2.0)
	assert_eq(field.tint[0], Color.GREEN)
	assert_eq(field.size_end[0], 3.0)
	assert_eq(field.x[1], 4.0)
	assert_eq(field.tint[1], Color.BLUE)


func test_the_pool_has_a_ceiling():
	for i in ParticleField.CAP:
		assert_true(field.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, 1.0, Color.WHITE))
	assert_false(field.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, 1.0, Color.WHITE), "the 4097th is dropped")
	assert_eq(field.count, ParticleField.CAP)


func test_size_and_alpha_follow_the_remaining_life():
	field.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, 10.0, 20.0, Color.WHITE)
	assert_eq(field.size_at(0), 10.0)
	assert_eq(field.alpha_at(0), 1.0)
	field.life[0] = 0.5
	assert_eq(field.size_at(0), 15.0, "halfway in size")
	assert_eq(field.alpha_at(0), 0.25, "the square of the remaining half")


func test_clear_forgets_the_particles_and_the_bullets_seen():
	var bullets := {1: _bullet(IMPACT_GROUP)}
	field.advance(FRAME, bullets)
	field.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, 1.0, Color.WHITE)
	field.clear()
	assert_eq(field.count, 0)
	field.advance(FRAME, {})
	assert_eq(field.count, 0, "the bullet that was seen does not burst after a clear")


# --- through the state -------------------------------------------------------

func test_the_state_steps_the_field_with_its_bullets_and_clears_it_with_them():
	var content := GameData.new()
	content.library.projectile_groups = art._library.projectile_groups
	var state := RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	state.local.position = Vector2(50, 50)
	state.projectiles.bullets[5] = _bullet(TRAIL_GROUP)
	state.advance(FRAME, Vector2.ZERO, 0.0)
	assert_eq(state.particles.count, 1)
	state.begin_transition()
	assert_eq(state.particles.count, 0, "gone with the realm")
	state.projectiles.bullets[6] = _bullet(TRAIL_GROUP)
	state.advance(FRAME, Vector2.ZERO, 0.0)
	assert_eq(state.particles.count, 1)
	state.reset_world()
	assert_eq(state.particles.count, 0)


# --- blind -------------------------------------------------------------------

func test_a_bullet_out_of_sight_leaves_no_trail():
	var bullets := {1: _bullet(TRAIL_GROUP)}
	var hidden := func(_b: Dictionary) -> bool: return true
	for i in 30:
		field.advance(FRAME, bullets, hidden)
	assert_eq(field.count, 0, "nothing to see, nothing emitted")
	field.advance(FRAME, bullets)
	assert_gt(field.count, 0, "and it trails again once in sight")


func test_a_bullet_out_of_sight_bursts_nowhere_when_it_goes():
	var bullets := {1: _bullet(IMPACT_GROUP)}
	field.advance(FRAME, bullets)
	var hidden := func(_b: Dictionary) -> bool: return true
	field.advance(FRAME, bullets, hidden)
	field.advance(FRAME, {}, hidden)
	assert_eq(field.count, 0, "it left sight, then landed: no burst either time")
