extends GutTest

## The dark silhouette behind sprites. Offset copies rather than a shader,
## because a material belongs to a canvas item and cannot vary per draw.


func test_the_ring_covers_every_direction():
	assert_eq(SpriteOutline.OFFSETS.size(), 8,
		"four cardinals plus four diagonals; the diagonals fill concave corners")


func test_the_ring_is_symmetric():
	# A mirrored or rotated frame reuses the same offsets, which only works if
	# negating one lands on another.
	for offset in SpriteOutline.OFFSETS:
		assert_true(-offset in SpriteOutline.OFFSETS, "%s has no opposite" % offset)


func test_every_offset_is_a_whole_world_unit():
	# Not a screen pixel: at a fractional device pixel the stroke antialiases
	# into near-invisibility on some edges and flickers as the camera moves.
	for offset in SpriteOutline.OFFSETS:
		for axis in [offset.x, offset.y]:
			assert_true(is_equal_approx(absf(axis), SpriteOutline.OFFSET) or is_zero_approx(axis),
				"%s is not a whole unit" % offset)


func test_the_silhouette_is_dark_but_not_opaque():
	assert_eq(SpriteOutline.TINT.r, 0.0)
	assert_eq(SpriteOutline.TINT.g, 0.0)
	assert_eq(SpriteOutline.TINT.b, 0.0)
	assert_between(SpriteOutline.TINT.a, 0.5, 1.0, "solid enough to read, not a hard black box")


## The ellipse a sprite stands on. Both references draw one, and agree on its
## shape to the decimal.

func test_the_shadow_is_wider_than_it_is_tall():
	# 0.4 of the sprite wide by 0.12 tall, which the flattening ratio has to
	# reproduce -- the circle is drawn at the half-width.
	assert_almost_eq(GroundShadow.HALF_WIDTH * GroundShadow.FLATTEN, 0.12, 0.0001)


func test_a_shadow_falls_below_the_sprite():
	assert_gt(GroundShadow.ENTITY_CENTRE, 1.0,
		"a character's shadow sits just past its feet")
	assert_lt(GroundShadow.OBJECT_CENTRE, GroundShadow.ENTITY_CENTRE,
		"a prop's sits a little higher")


func test_a_shadow_is_translucent():
	for alpha in [GroundShadow.ENTITY_ALPHA, GroundShadow.OBJECT_ALPHA]:
		assert_between(alpha, 0.1, 0.5, "a hint of darkness, not a black blob")
