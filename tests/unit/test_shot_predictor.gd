extends GutTest

## The predicted multi-shot fan, and recognising the server's copies of it.

const DEFINITION := {"size": 8, "magnitude": 5.0, "range": 200.0, "damage": 10,
	"flags": [ProjectileKind.PLAYER_PROJECTILE], "angle": 0.0}


func _build(archetype := {}, definitions := [DEFINITION], base_angle := 0.0) -> Dictionary:
	return ShotPredictor.build(1, 7, definitions, base_angle, Vector2(50, 50), archetype, 1000)


func test_single_shot_by_default():
	var bullets := _build()
	assert_eq(bullets.size(), 1)
	var bullet: Dictionary = bullets.values()[0]
	assert_eq(bullet["group_id"], 7)
	assert_eq(bullet["pos"], Vector2(50, 50))
	assert_true(bullet["predicted"])


func test_local_ids_are_negative_and_distinct():
	var bullets := _build({"projectileCount": 3})
	for id in bullets:
		assert_lt(id, 0, "predictions must not collide with server ids")
	assert_eq(bullets.size(), 3)


func test_archetype_projectile_count_fans_the_shot():
	assert_eq(_build({"projectileCount": 3}).size(), 3)


func test_fan_is_symmetric_about_the_aim():
	var bullets := _build({"projectileCount": 3, "spreadRad": 0.2})
	var angles: Array = []
	for bullet in bullets.values():
		angles.append(bullet["angle"])
	angles.sort()
	assert_almost_eq(angles[1], 0.0, 0.0001, "the centre shot stays on the aim line")
	assert_almost_eq(angles[0], -0.2, 0.0001)
	assert_almost_eq(angles[2], 0.2, 0.0001)


func test_even_counts_straddle_the_aim():
	var bullets := _build({"projectileCount": 2, "spreadRad": 0.2})
	var angles: Array = []
	for bullet in bullets.values():
		angles.append(bullet["angle"])
	angles.sort()
	assert_almost_eq(angles[0], -0.1, 0.0001)
	assert_almost_eq(angles[1], 0.1, 0.0001)


func test_default_spread_is_used_when_the_archetype_omits_one():
	var bullets := _build({"projectileCount": 2})
	var angles: Array = []
	for bullet in bullets.values():
		angles.append(bullet["angle"])
	angles.sort()
	assert_almost_eq(angles[1] - angles[0], ShotPredictor.DEFAULT_SPREAD_RAD, 0.0001)


func test_projectile_angle_offsets_stack_on_the_aim():
	var offset := {"size": 8, "magnitude": 5.0, "range": 100.0, "flags": [], "angle": PI / 2.0}
	var bullets := ShotPredictor.build(1, 7, [DEFINITION, offset], 0.25, Vector2.ZERO, {}, 0)
	var angles: Array = []
	for bullet in bullets.values():
		angles.append(bullet["angle"])
	angles.sort()
	assert_almost_eq(angles[0], 0.25, 0.0001)
	assert_almost_eq(angles[1], 0.25 + PI / 2.0, 0.0001)


func test_range_multiplier_and_piercing_come_from_the_archetype():
	var bullets := _build({"rangeMul": 1.5, "piercing": true})
	var bullet: Dictionary = bullets.values()[0]
	assert_almost_eq(bullet["range"], 300.0, 0.0001)
	assert_true(ProjectileKind.has_flag(bullet, ProjectileKind.PASS_THROUGH_ENEMIES))


func test_non_positive_multipliers_fall_back_to_sane_values():
	var bullets := _build({"projectileCount": 0, "rangeMul": 0.0, "spreadRad": -1.0})
	assert_eq(bullets.size(), 1)
	assert_almost_eq(bullets.values()[0]["range"], 200.0, 0.0001)


func test_every_projectile_in_the_group_is_fanned():
	var bullets := ShotPredictor.build(1, 7, [DEFINITION, DEFINITION], 0.0, Vector2.ZERO,
		{"projectileCount": 3}, 0)
	assert_eq(bullets.size(), 6, "two definitions times a three-shot fan")


# --- claiming --------------------------------------------------------------

func _prediction(angle: float, position := Vector2.ZERO) -> Dictionary:
	return {-1: Projectile.predicted(-1, 7, position, angle, DEFINITION, 0)}


func test_claims_a_player_shot_by_angle_alone():
	var bullets := _prediction(0.5, Vector2(10, 10))
	var wire := {"angle": 0.52, "pos": {"x": 900.0, "y": 900.0},
		"flags": [ProjectileKind.PLAYER_PROJECTILE]}
	assert_true(ShotPredictor.claim(bullets, wire, 4242))
	assert_eq(bullets[-1]["server_id"], 4242, "the prediction adopts the server id")


func test_rejects_a_different_angle():
	var bullets := _prediction(0.5)
	var wire := {"angle": 2.0, "pos": {"x": 0.0, "y": 0.0},
		"flags": [ProjectileKind.PLAYER_PROJECTILE]}
	assert_false(ShotPredictor.claim(bullets, wire, 1))


func test_non_player_shots_must_also_be_nearby():
	var bullets := _prediction(0.5, Vector2(0, 0))
	var far := {"angle": 0.5, "pos": {"x": 900.0, "y": 0.0}, "flags": []}
	assert_false(ShotPredictor.claim(bullets, far, 1))
	var near := {"angle": 0.5, "pos": {"x": 10.0, "y": 0.0}, "flags": []}
	assert_true(ShotPredictor.claim(bullets, near, 2))


func test_a_prediction_is_claimed_only_once():
	var bullets := _prediction(0.5)
	var wire := {"angle": 0.5, "pos": {"x": 0.0, "y": 0.0},
		"flags": [ProjectileKind.PLAYER_PROJECTILE]}
	assert_true(ShotPredictor.claim(bullets, wire, 1))
	assert_false(ShotPredictor.claim(bullets, wire, 2), "the second server bullet is its own")


func test_server_bullets_are_never_claimed_as_predictions():
	var bullets := {99: Projectile.from_wire({"id": 99, "angle": 0.5, "pos": {}, "flags": []}, 0)}
	var wire := {"angle": 0.5, "pos": {"x": 0.0, "y": 0.0}, "flags": []}
	assert_false(ShotPredictor.claim(bullets, wire, 1), "only negative ids are predictions")


func test_angle_wrapping_does_not_defeat_matching():
	var bullets := _prediction(-PI + 0.01)
	var wire := {"angle": PI - 0.01, "pos": {"x": 0.0, "y": 0.0},
		"flags": [ProjectileKind.PLAYER_PROJECTILE]}
	assert_true(ShotPredictor.claim(bullets, wire, 1), "angles either side of PI are close")
