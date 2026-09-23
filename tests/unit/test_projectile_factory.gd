extends GutTest

## Building bullet simulation state from the wire and from predictions.

func _wire(overrides := {}) -> Dictionary:
	var wire := {
		"id": 77, "projectileId": 12, "size": 8, "pos": {"x": 10.0, "y": 20.0},
		"dX": 0.0, "dY": 0.0, "angle": 1.5, "magnitude": 6.0, "range": 300.0,
		"damage": 25, "flags": [], "invert": false, "timeStep": 40,
		"amplitude": 0, "frequency": 0, "createdTime": 123,
		"orbitCenterX": 0.0, "orbitCenterY": 0.0, "orbitRadius": 0.0, "orbitPhase": 0.0,
	}
	wire.merge(overrides, true)
	return wire


func test_from_wire_copies_the_spawn_parameters():
	var bullet := Projectile.from_wire(_wire(), 5_000)
	assert_eq(bullet["id"], 77)
	assert_eq(bullet["group_id"], 12, "projectileId on the wire is the group id")
	assert_eq(bullet["pos"], Vector2(10, 20))
	assert_almost_eq(bullet["angle"], 1.5, 0.0001)
	assert_almost_eq(bullet["range"], 300.0, 0.0001)
	assert_eq(bullet["damage"], 25)
	assert_eq(bullet["time_step"], 40.0)
	assert_eq(bullet["traveled"], 0.0)
	assert_false(bullet["predicted"])
	assert_eq(bullet["server_id"], 0)


func test_from_wire_stamps_local_arrival_time():
	# Expiry is measured against when we saw it, not the server's clock.
	assert_eq(Projectile.from_wire(_wire(), 5_000)["created_ms"], 5_000)


func test_from_wire_uses_the_served_orbit_when_present():
	var bullet := Projectile.from_wire(_wire({
		"flags": [ProjectileKind.ORBITAL], "orbitCenterX": 100.0, "orbitCenterY": 50.0,
		"orbitRadius": 30.0, "orbitPhase": 0.5}), 0)
	assert_eq(bullet["orbit_centre"], Vector2(100, 50))
	assert_almost_eq(bullet["orbit_radius"], 30.0, 0.0001)


func test_orbit_radius_falls_back_to_amplitude():
	var bullet := Projectile.from_wire(_wire({
		"flags": [ProjectileKind.ORBITAL], "amplitude": 64, "orbitRadius": 0.0}), 0)
	assert_almost_eq(bullet["orbit_radius"], 64.0, 0.0001)


func test_orbit_radius_has_a_last_resort_default():
	var bullet := Projectile.from_wire(_wire({"flags": [ProjectileKind.ORBITAL]}), 0)
	assert_almost_eq(bullet["orbit_radius"], Projectile.DEFAULT_ORBIT_RADIUS, 0.0001)


func test_missing_orbit_centre_is_derived_from_the_spawn_point():
	# Without a centre the bullet would orbit the origin instead of its source.
	var bullet := Projectile.from_wire(_wire({
		"flags": [ProjectileKind.ORBITAL], "orbitRadius": 40.0, "orbitPhase": 0.0,
		"pos": {"x": 140.0, "y": 0.0}}), 0)
	assert_almost_eq(bullet["orbit_centre"].x, 100.0, 0.001)
	assert_almost_eq(bullet["pos"].distance_to(bullet["orbit_centre"]), 40.0, 0.001)


func test_non_orbital_bullets_keep_a_zero_orbit():
	var bullet := Projectile.from_wire(_wire(), 0)
	assert_eq(bullet["orbit_centre"], Vector2.ZERO)
	assert_eq(bullet["orbit_radius"], 0.0)


func test_predicted_bullets_read_the_group_definition():
	var definition := {"size": 6, "magnitude": 7.0, "range": 200.0, "damage": 9, "flags": [10]}
	var bullet := Projectile.predicted(-101, 5, Vector2(4, 4), 0.8, definition, 900)
	assert_eq(bullet["id"], -101)
	assert_eq(bullet["group_id"], 5)
	assert_eq(bullet["pos"], Vector2(4, 4))
	assert_almost_eq(bullet["magnitude"], 7.0, 0.0001)
	assert_almost_eq(bullet["range"], 200.0, 0.0001)
	assert_true(bullet["predicted"])
	assert_eq(bullet["created_ms"], 900)


func test_predicted_range_can_be_scaled_by_the_archetype():
	var definition := {"range": 200.0, "magnitude": 1.0}
	var bullet := Projectile.predicted(-1, 0, Vector2.ZERO, 0.0, definition, 0, 1.6)
	assert_almost_eq(bullet["range"], 320.0, 0.0001)


func test_predicted_bullets_take_extra_flags():
	var bullet := Projectile.predicted(-1, 0, Vector2.ZERO, 0.0, {"flags": [10]}, 0, 1.0,
		[ProjectileKind.PASS_THROUGH_ENEMIES])
	assert_true(ProjectileKind.has_flag(bullet, ProjectileKind.PASS_THROUGH_ENEMIES))
	assert_true(ProjectileKind.has_flag(bullet, ProjectileKind.PLAYER_PROJECTILE))


func test_extra_flags_are_not_duplicated():
	var bullet := Projectile.predicted(-1, 0, Vector2.ZERO, 0.0,
		{"flags": [ProjectileKind.PASS_THROUGH_ENEMIES]}, 0, 1.0,
		[ProjectileKind.PASS_THROUGH_ENEMIES])
	assert_eq(bullet["flags"].count(ProjectileKind.PASS_THROUGH_ENEMIES), 1)


func test_predicted_flags_do_not_mutate_the_definition():
	var definition := {"flags": [10]}
	Projectile.predicted(-1, 0, Vector2.ZERO, 0.0, definition, 0, 1.0, [25])
	assert_eq(definition["flags"], [10], "the shared content definition is left alone")


func test_predicted_inverted_parametric_sets_invert():
	var bullet := Projectile.predicted(-1, 0, Vector2.ZERO, 0.0,
		{"flags": [ProjectileKind.INVERTED_PARAMETRIC]}, 0)
	assert_true(bullet["invert"])


func test_centre_accounts_for_sprite_size():
	assert_eq(Projectile.centre({"pos": Vector2(10, 10), "size": 8}), Vector2(14, 14))
