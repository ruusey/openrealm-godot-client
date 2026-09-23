extends GutTest

## Flag lookups and the motion-type predicates derived from them.

func test_has_flag():
	var bullet := {"flags": [ProjectileKind.ORBITAL, ProjectileKind.ARMOR_PIERCING]}
	assert_true(ProjectileKind.has_flag(bullet, ProjectileKind.ORBITAL))
	assert_false(ProjectileKind.has_flag(bullet, ProjectileKind.PARAMETRIC))


func test_missing_flags_key_is_not_a_crash():
	assert_false(ProjectileKind.has_flag({}, ProjectileKind.ORBITAL))


func test_orbital_is_flag_driven():
	assert_true(ProjectileKind.is_orbital({"flags": [ProjectileKind.ORBITAL]}))
	assert_false(ProjectileKind.is_orbital({"flags": []}))


func test_parametric_is_parameter_driven():
	# Content sets amplitude/frequency on projectiles that omit the flag, so
	# the parameters decide, matching the working web client.
	assert_true(ProjectileKind.is_parametric({"flags": [], "amplitude": 20, "frequency": 30}))
	assert_false(ProjectileKind.is_parametric({"flags": [], "amplitude": 0, "frequency": 30}))
	assert_false(ProjectileKind.is_parametric({"flags": [], "amplitude": 20, "frequency": 0}))
	assert_false(ProjectileKind.is_parametric({"flags": []}))


func test_orbital_wins_over_parametric():
	# An orbital bullet uses amplitude as its radius, so it must not be
	# mistaken for a wave.
	var bullet := {"flags": [ProjectileKind.ORBITAL], "amplitude": 48, "frequency": 90}
	assert_true(ProjectileKind.is_orbital(bullet))
	assert_false(ProjectileKind.is_parametric(bullet))


func test_player_shot_flag():
	assert_true(ProjectileKind.is_player_shot({"flags": [ProjectileKind.PLAYER_PROJECTILE]}))
	assert_false(ProjectileKind.is_player_shot({"flags": [ProjectileKind.ORBITAL]}))
