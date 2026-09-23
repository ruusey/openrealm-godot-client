extends GutTest

## angleOffset templates from projectile-groups.json. All three clients resolve
## these the same way, including degrading anything unparsable to 0 -- group
## 111 ships a missing brace, and both reference clients land on 0 for it.


func test_a_plain_quarter_turn():
	assert_almost_eq(AngleTemplate.parse("{{PI/4}}"), PI / 4.0, 0.0001)


func test_a_coefficient_scales_pi():
	assert_almost_eq(AngleTemplate.parse("{{3PI/4}}"), 3.0 * PI / 4.0, 0.0001)
	assert_almost_eq(AngleTemplate.parse("{{PI}}"), PI, 0.0001)
	assert_almost_eq(AngleTemplate.parse("{{PI/2}}"), PI / 2.0, 0.0001)


func test_the_less_common_divisors_shipped_in_content():
	assert_almost_eq(AngleTemplate.parse("{{PI/10}}"), PI / 10.0, 0.0001)
	assert_almost_eq(AngleTemplate.parse("{{PI/12}}"), PI / 12.0, 0.0001)


func test_a_multiplied_form_parses():
	# The native client's parser accepts these, so ours should not choke.
	assert_almost_eq(AngleTemplate.parse("{{2*PI}}"), 2.0 * PI, 0.0001)
	assert_almost_eq(AngleTemplate.parse("{{1.5*PI}}"), 1.5 * PI, 0.0001)


func test_a_bare_number_is_taken_as_radians():
	assert_almost_eq(AngleTemplate.parse("0"), 0.0, 0.0001)
	assert_almost_eq(AngleTemplate.parse("1.25"), 1.25, 0.0001)
	assert_almost_eq(AngleTemplate.parse(0.5), 0.5, 0.0001)


func test_nothing_at_all_is_no_rotation():
	assert_eq(AngleTemplate.parse(null), 0.0)
	assert_eq(AngleTemplate.parse(""), 0.0)
	assert_eq(AngleTemplate.parse("   "), 0.0)


func test_a_malformed_template_degrades_to_zero():
	# Group 111 in the shipped content: "{{PI/2}" -- one closing brace short.
	# The web client's regex misses it and parseFloat yields NaN -> 0; the
	# native client throws and catches to 0. Drawing it unrotated beats
	# guessing.
	assert_eq(AngleTemplate.parse("{{PI/2}"), 0.0)
	assert_eq(AngleTemplate.parse("not an angle"), 0.0)
	assert_eq(AngleTemplate.parse("{{nonsense}}"), 0.0)


func test_an_expression_that_will_not_parse_degrades_too():
	# Unbalanced, so it fails at parse rather than at execute -- a different
	# branch from "{{nonsense}}", which parses and then fails to resolve.
	assert_eq(AngleTemplate.parse("{{2+}}"), 0.0)
	assert_eq(AngleTemplate.parse("{{(PI/4}}"), 0.0)
