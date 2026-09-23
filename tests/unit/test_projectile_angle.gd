extends GutTest

## Angle parsing and the unusual firing convention.

func test_parses_numeric_values():
	assert_almost_eq(ProjectileAngle.parse(1.5), 1.5, 0.0001)
	assert_almost_eq(ProjectileAngle.parse(2), 2.0, 0.0001)


func test_parses_numeric_strings():
	# Content stores the same field as a number in some entries and a string
	# in others, sometimes within one projectile group.
	assert_almost_eq(ProjectileAngle.parse("0"), 0.0, 0.0001)
	assert_almost_eq(ProjectileAngle.parse("-0.15"), -0.15, 0.0001)
	assert_almost_eq(ProjectileAngle.parse("  0.25  "), 0.25, 0.0001)


func test_parses_the_pi_placeholder():
	assert_almost_eq(ProjectileAngle.parse("{{PI}}"), PI, 0.0001)


func test_parses_pi_fractions():
	assert_almost_eq(ProjectileAngle.parse("{{PI/2}}"), PI / 2.0, 0.0001)
	assert_almost_eq(ProjectileAngle.parse("{{PI/16}}"), PI / 16.0, 0.0001)


func test_parses_pi_multiples():
	assert_almost_eq(ProjectileAngle.parse("{{3PI/4}}"), 3.0 * PI / 4.0, 0.0001)
	assert_almost_eq(ProjectileAngle.parse("{{23PI/12}}"), 23.0 * PI / 12.0, 0.0001)
	assert_almost_eq(ProjectileAngle.parse("{{11PI/6}}"), 11.0 * PI / 6.0, 0.0001)


func test_parses_every_placeholder_form_used_by_content():
	# The exact set that appears across the data repo's content files.
	for text in ["{{PI}}", "{{PI/2}}", "{{PI/3}}", "{{PI/4}}", "{{PI/5}}", "{{PI/6}}",
			"{{PI/8}}", "{{PI/10}}", "{{PI/12}}", "{{PI/16}}", "{{2PI/3}}", "{{3PI/2}}",
			"{{3PI/4}}", "{{3PI/8}}", "{{4PI/3}}", "{{5PI/3}}", "{{5PI/4}}", "{{5PI/6}}",
			"{{5PI/8}}", "{{7PI/4}}", "{{7PI/6}}", "{{7PI/8}}", "{{9PI/8}}", "{{11PI/6}}",
			"{{11PI/8}}", "{{13PI/8}}", "{{15PI/8}}", "{{23PI/12}}"]:
		assert_ne(ProjectileAngle.parse(text), 0.0, "%s should resolve" % text)


func test_parses_a_negative_placeholder():
	assert_almost_eq(ProjectileAngle.parse("{{-PI/2}}"), -PI / 2.0, 0.0001)


func test_whitespace_inside_the_placeholder_is_tolerated():
	assert_almost_eq(ProjectileAngle.parse("{{ 3PI / 4 }}"), 3.0 * PI / 4.0, 0.0001)


func test_unparseable_values_degrade_to_zero():
	assert_eq(ProjectileAngle.parse(""), 0.0)
	assert_eq(ProjectileAngle.parse("{{TAU}}"), 0.0)
	assert_eq(ProjectileAngle.parse(null), 0.0)
	assert_eq(ProjectileAngle.parse([1, 2]), 0.0)


func test_direction_is_clockwise_from_positive_y():
	# The convention that is easy to get wrong: velocity is (sin a, cos a).
	assert_almost_eq(ProjectileAngle.direction(0.0).y, 1.0, 0.0001)
	assert_almost_eq(ProjectileAngle.direction(0.0).x, 0.0, 0.0001)
	assert_almost_eq(ProjectileAngle.direction(PI / 2.0).x, 1.0, 0.0001)


func test_perpendicular_is_ninety_degrees_from_travel():
	for angle in [0.0, 0.7, -1.2, PI]:
		var dot := ProjectileAngle.direction(angle).dot(ProjectileAngle.perpendicular(angle))
		assert_almost_eq(dot, 0.0, 0.0001, "perpendicular at angle %f" % angle)


func test_aim_points_at_the_target():
	var origin := Vector2(100, 100)
	# Each cardinal aim must produce a direction pointing that way -- the Java
	# Bullet.getAngle helper is mirrored in x, so this is the behaviour that
	# matters rather than a literal port of it.
	var cases := {
		Vector2(200, 100): Vector2.RIGHT,
		Vector2(0, 100): Vector2.LEFT,
		Vector2(100, 200): Vector2.DOWN,
		Vector2(100, 0): Vector2.UP,
	}
	for target in cases:
		var direction := ProjectileAngle.direction(ProjectileAngle.aim(origin, target))
		assert_almost_eq(direction.x, cases[target].x, 0.0001, "x toward %s" % target)
		assert_almost_eq(direction.y, cases[target].y, 0.0001, "y toward %s" % target)


func test_aim_is_continuous_for_diagonals():
	var direction := ProjectileAngle.direction(ProjectileAngle.aim(Vector2.ZERO, Vector2(10, 10)))
	assert_almost_eq(direction.x, 0.7071, 0.001)
	assert_almost_eq(direction.y, 0.7071, 0.001)
