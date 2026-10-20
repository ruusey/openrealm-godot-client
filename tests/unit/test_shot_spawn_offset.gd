extends GutTest

## A weapon's paired shots spawn side by side, square to the aim, exactly
## where the server puts them, so a prediction lines up with the real bolt.



func test_a_side_offset_splits_a_pair_square_to_the_aim_at_any_angle():
	var pair := [{"angle": 0.0, "spawnOffsetX": -3, "size": 8}, {"angle": 0.0, "spawnOffsetX": 3, "size": 8}]
	for degrees in range(0, 360, 45):
		var aim := ProjectileAngle.aim(Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(degrees)) * 100.0)
		var shot := ShotPredictor.build(1, 7, pair, aim, Vector2.ZERO, {}, 0).values()
		var apart: Vector2 = shot[1].pos - shot[0].pos
		assert_almost_eq(apart.length(), 6.0, 0.001, "6px apart at %d" % degrees)
		assert_almost_eq(apart.dot(ProjectileAngle.direction(aim)), 0.0, 0.001, "side by side at %d" % degrees)
		assert_almost_eq(shot[0].angle, shot[1].angle, 0.0001, "the same heading")


func test_the_offset_matches_the_server_to_the_right_of_a_rightward_shot():
	var aim := ProjectileAngle.aim(Vector2.ZERO, Vector2(100, 0))
	assert_almost_eq(ProjectileAngle.spawn_offset({"spawnOffsetX": 3}, aim), Vector2(0, 3), Vector2(0.001, 0.001),
		"screen y runs down, so a rightward shot's right hand is below it")
