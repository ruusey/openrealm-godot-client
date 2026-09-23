extends GutTest

## The deterministic integrator. These numbers are the server's: if this drifts
## the client and server disagree about where every bullet is.

func _bullet(overrides := {}) -> Dictionary:
	var bullet := {
		"pos": Vector2.ZERO, "angle": 0.0, "magnitude": 5.0, "range": 100.0,
		"traveled": 0.0, "flags": [], "invert": false, "time_step": 0.0,
		"amplitude": 0.0, "frequency": 0.0, "orbit_centre": Vector2.ZERO,
		"orbit_radius": 0.0, "orbit_phase": 0.0, "created_ms": 0, "size": 8,
	}
	bullet.merge(overrides, true)
	return bullet


func test_straight_travel_follows_the_angle():
	var bullet := _bullet({"angle": PI / 2.0, "magnitude": 4.0})
	ProjectileMotion.step(bullet, 1.0)
	assert_almost_eq(bullet["pos"].x, 4.0, 0.0001, "angle PI/2 travels along +x")
	assert_almost_eq(bullet["pos"].y, 0.0, 0.0001)
	assert_almost_eq(bullet["traveled"], 4.0, 0.0001)


func test_bullet_scale_normalises_to_the_tick_rate():
	# bullet_scale = dt * 64, so a half-tick frame moves half as far.
	var full := _bullet()
	var half := _bullet()
	ProjectileMotion.step(full, 1.0)
	ProjectileMotion.step(half, 0.5)
	assert_almost_eq(half["pos"].y, full["pos"].y * 0.5, 0.0001)


func test_two_half_steps_equal_one_whole_step():
	var once := _bullet()
	var twice := _bullet()
	ProjectileMotion.step(once, 1.0)
	ProjectileMotion.step(twice, 0.5)
	ProjectileMotion.step(twice, 0.5)
	assert_almost_eq(twice["pos"].y, once["pos"].y, 0.0001, "straight motion is frame-rate independent")
	assert_almost_eq(twice["traveled"], once["traveled"], 0.0001)


func test_parametric_adds_a_perpendicular_wave():
	# angle 0 travels +y, so the wave displaces along +x.
	var bullet := _bullet({"amplitude": 20.0, "frequency": 30.0, "magnitude": 5.0,
		"flags": [ProjectileKind.PARAMETRIC]})
	ProjectileMotion.step(bullet, 1.0)
	assert_almost_eq(bullet["time_step"], 30.0, 0.0001)
	# offset goes 20*sin(0)=0 -> 20*sin(30deg)=10, so x advances by the delta.
	assert_almost_eq(bullet["pos"].x, 10.0, 0.001)
	assert_almost_eq(bullet["pos"].y, 5.0, 0.001)
	assert_almost_eq(bullet["traveled"], 5.0, 0.001, "range is spent on forward motion only")


func test_inverted_parametric_mirrors_the_wave():
	var normal := _bullet({"amplitude": 20.0, "frequency": 30.0, "flags": [ProjectileKind.PARAMETRIC]})
	var inverted := _bullet({"amplitude": 20.0, "frequency": 30.0, "invert": true,
		"flags": [ProjectileKind.PARAMETRIC]})
	ProjectileMotion.step(normal, 1.0)
	ProjectileMotion.step(inverted, 1.0)
	assert_almost_eq(inverted["pos"].x, -normal["pos"].x, 0.0001)
	assert_almost_eq(inverted["pos"].y, normal["pos"].y, 0.0001, "forward motion is unchanged")


func test_parametric_time_step_wraps_at_360():
	var bullet := _bullet({"amplitude": 5.0, "frequency": 100.0, "flags": [ProjectileKind.PARAMETRIC]})
	for i in 5:
		ProjectileMotion.step(bullet, 1.0)
	assert_lt(bullet["time_step"], 360.0)
	assert_gte(bullet["time_step"], 0.0)


func test_orbital_moves_around_its_centre():
	var bullet := _bullet({"flags": [ProjectileKind.ORBITAL], "frequency": 90.0,
		"orbit_radius": 48.0, "orbit_centre": Vector2(100, 100), "orbit_phase": 0.0})
	ProjectileMotion.step(bullet, 1.0)
	assert_almost_eq(bullet["orbit_phase"], PI / 2.0, 0.0001)
	assert_almost_eq(bullet["pos"].x, 100.0, 0.001)
	assert_almost_eq(bullet["pos"].y, 148.0, 0.001)


func test_orbital_stays_on_its_circle():
	var centre := Vector2(50, -20)
	var bullet := _bullet({"flags": [ProjectileKind.ORBITAL], "frequency": 37.0,
		"orbit_radius": 30.0, "orbit_centre": centre, "orbit_phase": 0.3})
	for i in 12:
		ProjectileMotion.step(bullet, 1.0)
		assert_almost_eq(bullet["pos"].distance_to(centre), 30.0, 0.001)


func test_orbital_spends_range_as_arc_length():
	var bullet := _bullet({"flags": [ProjectileKind.ORBITAL], "frequency": 90.0,
		"orbit_radius": 48.0, "orbit_centre": Vector2.ZERO})
	ProjectileMotion.step(bullet, 1.0)
	assert_almost_eq(bullet["traveled"], 48.0 * PI / 2.0, 0.001)


func test_expires_when_range_is_spent():
	var bullet := _bullet({"range": 10.0, "magnitude": 4.0})
	ProjectileMotion.step(bullet, 1.0)
	assert_false(ProjectileMotion.is_expired(bullet, 0))
	ProjectileMotion.step(bullet, 1.0)
	ProjectileMotion.step(bullet, 1.0)
	assert_true(ProjectileMotion.is_expired(bullet, 0), "12 > 10 range")


func test_expires_on_the_ten_second_ceiling():
	var bullet := _bullet({"range": 100000.0, "created_ms": 1000})
	assert_false(ProjectileMotion.is_expired(bullet, 1000 + ProjectileMotion.MAX_LIFETIME_MS))
	assert_true(ProjectileMotion.is_expired(bullet, 1001 + ProjectileMotion.MAX_LIFETIME_MS))


func test_catch_up_advances_a_straight_bullet():
	var bullet := _bullet({"angle": PI / 2.0, "magnitude": 4.0, "created_ms": 10_000})
	ProjectileMotion.catch_up(bullet, 100.0)
	# 100ms one-way at 64 ticks/sec is 6.4 ticks of travel.
	assert_almost_eq(bullet["pos"].x, 4.0 * 6.4, 0.001)
	assert_eq(bullet["created_ms"], 9_900, "its age is backdated to match")


func test_catch_up_is_capped():
	var bullet := _bullet({"angle": PI / 2.0, "magnitude": 4.0})
	ProjectileMotion.catch_up(bullet, 5_000.0)
	var capped := ProjectileMotion.MAX_CATCHUP_SECONDS * ProjectileMotion.TICK_RATE
	assert_almost_eq(bullet["pos"].x, 4.0 * capped, 0.001)


func test_catch_up_ignores_negligible_latency():
	var bullet := _bullet({"angle": PI / 2.0, "magnitude": 4.0})
	ProjectileMotion.catch_up(bullet, 1.0)
	assert_eq(bullet["pos"], Vector2.ZERO)


func test_catch_up_skips_phase_dependent_motion():
	# Orbital and parametric paths depend on accumulated phase, so guessing
	# ahead would put them permanently out of step with the server.
	var orbital := _bullet({"flags": [ProjectileKind.ORBITAL], "frequency": 90.0,
		"orbit_radius": 20.0, "magnitude": 3.0})
	var parametric := _bullet({"amplitude": 10.0, "frequency": 20.0, "magnitude": 3.0})
	ProjectileMotion.catch_up(orbital, 200.0)
	ProjectileMotion.catch_up(parametric, 200.0)
	assert_eq(orbital["pos"], Vector2.ZERO)
	assert_eq(parametric["pos"], Vector2.ZERO)


func test_catch_up_skips_stationary_bullets():
	var bullet := _bullet({"magnitude": 0.0})
	ProjectileMotion.catch_up(bullet, 200.0)
	assert_eq(bullet["pos"], Vector2.ZERO)
