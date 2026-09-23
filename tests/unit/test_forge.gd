extends GutTest

## The forge's rules, its bench, and the pixel a crystal paints.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 9


func _def(item_id: int, extra := {}) -> Dictionary:
	var item := content.item_definition(item_id).duplicate(true)
	item.merge(extra, true)
	return item


func _problem(target: Dictionary, crystal: Dictionary, essence: Dictionary) -> String:
	return ForgeRules.problem(target, crystal, essence, content)


# --- what may go where ------------------------------------------------------

func test_the_kinds_of_thing():
	assert_true(ForgeRules.is_equipment(_def(102)), "a wand")
	assert_false(ForgeRules.is_equipment(_def(200)), "a potion")
	assert_false(ForgeRules.is_equipment(_def(105)), "a stack")
	assert_true(ForgeRules.is_crystal(_def(300)))
	assert_true(ForgeRules.is_gem(_def(320)))
	assert_true(ForgeRules.is_essence(_def(310)))
	assert_false(ForgeRules.is_crystal(_def(320)))


func test_crystal_slots_follow_rarity_and_only_epics_have_a_socket():
	# The server's Rarity enum: Mundane 0 through Legendary 5.
	assert_eq(ForgeRules.crystal_cap(_def(106)), 0, "mundane")
	assert_eq(ForgeRules.crystal_cap(_def(102)), 1, "common")
	assert_eq(ForgeRules.crystal_cap(_def(103)), 4, "epic")
	assert_eq(ForgeRules.crystal_cap({"rarity": 99}), 5, "clamped to legendary")
	assert_false(ForgeRules.has_gem_socket(_def(102)))
	assert_true(ForgeRules.has_gem_socket(_def(103)))


func test_the_problems_in_the_web_clients_order():
	var wand := _def(102)
	var crystal := _def(300)
	var essence := _def(310, {"stackCount": 50})
	assert_eq(_problem({}, crystal, essence), "Pick an item.")
	assert_eq(_problem(wand, {}, essence), "Pick a Crystal or Gem.")
	assert_eq(_problem(wand, crystal, {}), "Pick Essence.")
	assert_eq(_problem(wand, crystal, _def(311, {"stackCount": 50})), "Essence type must be Weapon.")
	assert_eq(_problem(wand, crystal, _def(310, {"stackCount": 12})), "Need 50 essence (have 12).")
	assert_eq(_problem(wand, crystal, essence), "", "and then nothing is wrong")


func test_a_full_crystal_bar_refuses_a_crystal_but_not_a_gem():
	var hammer := _def(106)   # mundane: no crystal slots at all
	assert_eq(_problem(hammer, _def(300), _def(310, {"stackCount": 50})),
		"Max crystal slots (0) reached for this rarity.")
	var robe := _def(103, {"enchantments": [{"statId": 0, "deltaValue": 1, "pixelX": 0, "pixelY": 0}] })
	assert_eq(_problem(robe, _def(300), _def(311, {"stackCount": 50})), "", "one of four used")
	var full := _def(103, {"enchantments": [{}, {}, {}, {}]})
	assert_eq(_problem(full, _def(300), _def(311, {"stackCount": 50})),
		"Max crystal slots (4) reached for this rarity.")
	assert_eq(_problem(full, _def(321), _def(311, {"stackCount": 50})), "",
		"the gem socket is separate from the crystal bar")


func test_gems_need_a_socket_an_empty_one_and_a_fitting_slot():
	assert_eq(_problem(_def(102), _def(320), _def(310, {"stackCount": 50})),
		"This rarity has no gem socket (Epic+ only).")
	assert_eq(_problem(_def(103, {"gemstoneType": 6}), _def(321), _def(311, {"stackCount": 50})),
		"Item already has a gem socketed.")
	assert_eq(_problem(_def(103), _def(320), _def(311, {"stackCount": 50})),
		"Crit Gem can only socket into: Weapon.")
	assert_eq(_problem(_def(103), _def(321), _def(311, {"stackCount": 50})), "", "thorns fit armour")
	# A gem the catalog knows nothing about defers to the server.
	assert_eq(_problem(_def(103), {"itemId": 999, "category": "gem", "name": "Odd Gem"},
		_def(311, {"stackCount": 50})), "")


func test_what_disenchant_needs():
	assert_false(ForgeRules.can_disenchant(_def(102)))
	assert_true(ForgeRules.can_disenchant(_def(102, {"enchantments": [{}]})))
	assert_true(ForgeRules.can_disenchant(_def(103, {"gemstoneType": 6})))
	assert_false(ForgeRules.can_disenchant({}))


func test_the_words_on_the_line():
	assert_eq(ForgeRules.summary(_def(102)), "Broken Wand - Common   Crystal slots: 0/1")
	assert_eq(ForgeRules.summary(_def(103, {"gemstoneType": 6})),
		"Wool Robe - Epic   Crystal slots: 0/4   Gem: Thorns Gem")
	assert_eq(ForgeRules.summary(_def(103)), "Wool Robe - Epic   Crystal slots: 0/4   Gem: empty")
	assert_eq(ForgeRules.effect_preview(_def(300)), "+1 VIT")
	assert_eq(ForgeRules.effect_preview(_def(301)), "+5 HP", "HP and MP crystals add five")
	assert_eq(ForgeRules.effect_preview(_def(320)), "Crit Gem")
	assert_eq(ForgeRules.effect_preview({"category": "crystal", "forgeStatId": 9}), "?")
	assert_eq(ForgeRules.enchantment_label({"statId": 5, "deltaValue": 1}), "+1 DEF")
	assert_eq(ForgeRules.enchantment_label({"statId": 42, "deltaValue": 3}), "+3 ?")


func test_the_card_shows_the_forges_work():
	var lines := ItemTooltip.describe(_def(103, {"enchantments": [{"statId": 5, "deltaValue": 1},
		{"statId": 2, "deltaValue": 5}], "gemstoneType": 6}))
	var texts: Array = lines.map(func(line: Array) -> String: return line[0])
	var at := texts.find("Crystals (2/4)")
	assert_gt(at, -1, str(texts))
	assert_eq(texts.slice(at + 1, at + 3), ["  +1 DEF", "  +5 HP"], "a crystal a line, as the web lists them")
	assert_true("Gem: Thorns Gem - Reflects 20% of damage taken back to enemy attackers." in texts, str(texts))
	texts = ItemTooltip.describe(_def(102)).map(func(line: Array) -> String: return line[0])
	assert_true("Crystal slots: 0/1" in texts, "an unforged piece still says what it could take")
	assert_false("Gem socket: empty" in texts, "no socket on a common")
	texts = ItemTooltip.describe(_def(103)).map(func(line: Array) -> String: return line[0])
	assert_true("Gem socket: empty" in texts, "an epic's socket, empty")
	texts = ItemTooltip.describe(_def(200)).map(func(line: Array) -> String: return line[0])
	assert_false(texts.any(func(t: String) -> bool: return t.begins_with("Crystal")), "a potion has no slots")


# --- the bench ---------------------------------------------------------------

func test_the_bench_opens_for_us_and_remembers_bag_slots():
	state.apply_packet("OpenForgePacket", {"playerId": 10})
	assert_false(state.forge.is_open, "another player's forge")
	state.apply_packet("OpenForgePacket", {"playerId": 9})
	assert_true(state.forge.is_open)
	state.local.inventory.put(7, _def(102))
	state.forge.assign("target", 7)
	assert_eq(state.forge.index_of("target"), 7)
	assert_eq(int(state.forge.item_on("target", state.local.inventory)["itemId"]), 102)
	assert_true(state.forge.item_on("crystal", state.local.inventory).is_empty())
	state.forge.unassign("target")
	assert_eq(state.forge.index_of("target"), ForgeBench.NONE)


func test_a_zone_whose_slot_emptied_is_let_go():
	# The crystal the last forge consumed leaves its zone pointing at nothing.
	state.local.inventory.put(7, _def(300))
	state.forge.assign("crystal", 7)
	state.forge.prune(state.local.inventory)
	assert_eq(state.forge.index_of("crystal"), 7)
	state.local.inventory.put(7, {})
	state.forge.prune(state.local.inventory)
	assert_eq(state.forge.index_of("crystal"), ForgeBench.NONE)


func test_closing_and_leaving_the_realm_clear_the_bench():
	state.apply_packet("OpenForgePacket", {"playerId": 9})
	state.forge.assign("target", 3)
	state.forge.close()
	assert_false(state.forge.is_open)
	assert_eq(state.forge.index_of("target"), 3, "closing keeps the bench for reopening")
	state.reset_world()
	assert_eq(state.forge.index_of("target"), ForgeBench.NONE)


# --- the pixel ---------------------------------------------------------------

func _sprite(pixels: Array) -> AtlasTexture:
	# A 4x4 sheet whose cell (1,0) is the sprite; `pixels` lists its opaque ones.
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for p in pixels:
		image.set_pixel(4 + p.x, p.y, Color.WHITE)
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(4, 0, 4, 4)
	return atlas


func test_the_first_opaque_unpainted_pixel_is_chosen():
	var sprite := _sprite([Vector2i(2, 1), Vector2i(3, 1), Vector2i(0, 3)])
	assert_eq(ForgePixel.pick(sprite, {}), Vector2i(2, 1), "row-major, skipping the transparent")
	var painted := {"enchantments": [{"pixelX": 2, "pixelY": 1}]}
	assert_eq(ForgePixel.pick(sprite, painted), Vector2i(3, 1))
	var socketed := {"enchantments": [{"pixelX": 2, "pixelY": 1}, {"pixelX": 3, "pixelY": 1}],
		"gemstoneType": 6, "gemPixelX": 0, "gemPixelY": 3}
	assert_eq(ForgePixel.pick(sprite, socketed), Vector2i(0, 0),
		"every opaque pixel taken: the first free one, which the server accepts")


func test_a_sprite_that_cannot_be_read_still_yields_a_free_pixel():
	assert_eq(ForgePixel.pick(null, {}), Vector2i(0, 0))
	assert_eq(ForgePixel.pick(null, {"enchantments": [{"pixelX": 0, "pixelY": 0}]}), Vector2i(1, 0))
	var blank := _sprite([])
	assert_eq(ForgePixel.pick(blank, {}), Vector2i(0, 0), "nothing opaque at all")
	# A plain texture is its own region.
	var whole := ImageTexture.create_from_image(blank.atlas.get_image())
	assert_eq(ForgePixel.pick(whole, {}), Vector2i(0, 0))
	# Every pixel of the unreadable 8x8 already painted: the corner, and the
	# server's refusal is the answer.
	var all: Array = []
	for y in 8:
		for x in 8:
			all.append({"pixelX": x, "pixelY": y})
	assert_eq(ForgePixel.pick(null, {"enchantments": all}), ForgePixel.FALLBACK)


func test_the_real_sheet_is_readable():
	var wand := _def(102)
	var at := ForgePixel.pick(content.item_texture(102), wand)
	var texture: AtlasTexture = content.item_texture(102)
	var image := texture.atlas.get_image()
	assert_gt(image.get_pixel(int(texture.region.position.x) + at.x, int(texture.region.position.y) + at.y).a, 0.0,
		"the pixel picked off the fixture sheet is opaque")
