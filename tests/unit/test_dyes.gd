extends GutTest

## Dyes: a character's cloth, recoloured through its class's mask as the
## web client's getDyedRegion does, on everyone who is drawn.
##
## The fixture's class 0 masks the lower half of its idle_front cell (7, 7)
## and the 8-wide body of its double-width attack frame (6, 12). Dye 1 is
## the shipped Green Dye (0x4AC24A); dye 9 is a `sprite` cloth, which no
## shipped dye uses and which draws undyed.

var content: GameData


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))


func _pixels(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		return texture.atlas.get_image().get_region(Rect2i(texture.region))
	return texture.get_image()


func test_the_dyes_and_masks_load_with_the_content():
	assert_eq(content.library.errors, [] as Array[String])
	assert_eq(content.library.dyes[1]["name"], "Green Dye")
	assert_eq(content.library.class_masks[0]["frames"].size(), 2)


func test_a_solid_dye_keeps_the_pixels_shading_and_alpha():
	var image := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color8(100, 150, 200, 255))
	image.set_pixel(1, 0, Color8(100, 150, 200, 255))
	image.set_pixel(2, 0, Color8(100, 150, 200, 0))
	DyedSprites.recolour(image, [[1, 0, 2]], 0x4AC24A)
	# Luminance 140.75 over 128 scales (74, 194, 74).
	var dyed := image.get_pixel(0, 0)
	assert_eq([dyed.r8, dyed.g8, dyed.b8, dyed.a8], [81, 213, 81, 255])
	var kept := image.get_pixel(1, 0)
	assert_eq([kept.r8, kept.g8, kept.b8], [100, 150, 200], "unmasked: untouched")
	var clear := image.get_pixel(2, 0)
	assert_eq([clear.r8, clear.g8, clear.b8, clear.a8], [100, 150, 200, 0], "transparent: untouched")


func test_the_mask_decides_which_half_of_the_frame_is_cloth():
	var plain := content.classes_art.frame(0, "idle", "front", 0)
	var dyed := content.classes_art.frame(0, "idle", "front", 0, 1)
	assert_true(plain is AtlasTexture)
	assert_false(dyed is AtlasTexture, "a dyed frame is its own image")
	assert_eq(dyed.get_size(), Vector2(8, 8))
	var before := _pixels(plain)
	var after := _pixels(dyed)
	var upper_changed := 0
	var lower_changed := 0
	for y in 8:
		for x in 8:
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				if y < 4:
					upper_changed += 1
				else:
					lower_changed += 1
	assert_eq(upper_changed, 0, "the unmasked half keeps its colours")
	assert_gt(lower_changed, 0, "the masked half takes the dye")
	assert_same(content.classes_art.frame(0, "idle", "front", 0, 1), dyed, "made once, then kept")


func test_no_dye_an_unknown_one_a_patterned_one_or_no_mask_draws_plain():
	var plain := content.classes_art.frame(0, "idle", "front", 0)
	assert_same(content.classes_art.frame(0, "idle", "front", 0, 0), plain)
	assert_same(content.classes_art.frame(0, "idle", "front", 0, 5), plain, "no such dye")
	assert_same(content.classes_art.frame(0, "idle", "front", 0, 9), plain, "a sprite cloth: not supported")
	var unmasked := content.classes_art.frame(0, "attack", "side", 0)
	assert_same(content.classes_art.frame(0, "attack", "side", 0, 1), unmasked, "(6, 11) has no mask")


func test_a_wide_attack_frame_keeps_its_overhanging_weapon():
	var plain := content.classes_art.frame(0, "attack", "side", 1)
	var dyed := content.classes_art.frame(0, "attack", "side", 1, 1)
	assert_eq(dyed.get_size(), Vector2(16, 8))
	var before := _pixels(plain)
	var after := _pixels(dyed)
	for y in 8:
		for x in range(8, 16):
			assert_eq(after.get_pixel(x, y), before.get_pixel(x, y), "column %d is past the body" % x)
	assert_eq(EntityQueue.frame_size(dyed, 8, 32.0), Vector2(64, 32), "still drawn twice as wide")


func test_everyone_drawn_wears_their_dye_and_a_new_one_follows_the_packet():
	var state := RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	var dressed := WireHelper.player(2, "Mingau", Vector2(40, 0))
	dressed["dyeId"] = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO), dressed]})
	var drawn := func(id: int) -> Texture2D:
		for entry in EntityQueue.new().build(state, content, Rect2(-500, -500, 1000, 1000)):
			if entry["kind"] == "players" and entry["pos"].distance_to(
					state.entities.render_position(state.entities.players[id])) < 0.01 and id != 1:
				return entry["texture"]
		return null
	var theirs: Texture2D = drawn.call(2)
	assert_not_null(theirs)
	assert_false(theirs is AtlasTexture, "Mingau is dyed")
	state.apply_packet("UpdatePacket", {"playerId": 2, "dyeId": 0, "stats": {}})
	assert_eq(state.entities.players[2]["dye_id"], 0)
	assert_true(drawn.call(2) is AtlasTexture, "and undyed again when the packet says so")


func test_the_creators_icon_takes_a_dyed_frame_too():
	var icon := CharacterCreator.icon_for(content.classes_art.frame(0, "idle", "front", 0, 1))
	assert_not_null(icon)
	assert_eq(icon.get_size(), Vector2(CharacterCreator.ICON_PX, CharacterCreator.ICON_PX))


func test_a_dyed_body_wading_is_sliced_from_its_own_size():
	var dyed := content.classes_art.frame(0, "idle", "front", 0, 1)
	var item := {"pos": Vector2.ZERO, "size": 32, "draw": Vector2(32, 32), "flip": false,
		"texture": dyed, "wading": true}
	var body := EntityRenderer.body_draw(item)
	assert_gt(body["slice"].size.y, 0.0, "the legs go under; the rest is drawn")
	assert_lt(body["slice"].size.y, 8.0, "cut from the frame's own 8 rows")


func test_the_world_draws_a_dyed_player():
	var state := RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	var dressed := WireHelper.player(2, "Mingau", Vector2(40, 0))
	dressed["dyeId"] = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "Ruu", Vector2.ZERO), dressed]})
	var world := WorldRenderer.new()
	world.setup(state, content)
	add_child_autofree(world)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	world.queue_redraw()
	await wait_process_frames(2)
	# A frame the renderer cannot take errors out of the draw rather than
	# failing here; run-tests.sh fails on that error.
	assert_eq(world.draw_stats["players"], 2)
