extends GutTest

## What the character carries, and what may go where.

var content: GameData
var bag: Inventory


func before_each():
	bag = Inventory.new()
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))


func _update(items: Array, extra := {}) -> Dictionary:
	var data := {"playerId": 9, "inventory": items}
	data.merge(extra, true)
	return data


func _catalog(item_id: int) -> Dictionary:
	return content.item_definition(item_id).duplicate()


static func _bag(id: int, at: Vector2, items: Array) -> Dictionary:
	return {"lootContainerId": id, "uid": "", "isChest": false, "tier": 0, "items": items,
		"pos": {"x": at.x, "y": at.y}, "spawnedTime": 0, "contentsChanged": false,
		"soulboundPlayerId": 0}


# --- the slots ---------------------------------------------------------------

func test_the_slot_map_is_the_servers():
	# Derived from Player.EQUIPMENT_SLOT_COUNT (5), Player.BACKPACK_SIZE (40)
	# and LootContainer.SIZE (10). Spelled out, because the comment over
	# MoveItemPacket's fields still says 5..24 / 25..34 / 35 / 36, and a
	# client that believed it would drink a potion by moving slot 35.
	assert_eq(Inventory.SIZE, 45)
	assert_eq(Inventory.GROUND_LOOT_START, 45)
	assert_eq(Inventory.HP_POTION_SLOT, 55)
	assert_eq(Inventory.MP_POTION_SLOT, 56)


func test_starts_empty_and_full_width():
	assert_eq(bag.slots.size(), 45)
	for i in 45:
		assert_true(bag.item_at(i).is_empty())


func test_an_update_fills_the_slots_in_wire_order():
	bag.apply_update(_update([{"itemId": 100}, {"itemId": -1}, null, {"itemId": 105, "stackCount": 3}]))
	assert_eq(int(bag.item_at(0)["itemId"]), 100)
	assert_true(bag.item_at(1).is_empty(), "the -1 placeholder is an empty slot")
	assert_true(bag.item_at(2).is_empty(), "so is a null")
	assert_eq(int(bag.item_at(3)["stackCount"]), 3)
	assert_true(bag.item_at(44).is_empty(), "a short array leaves the rest empty")


func test_a_shorter_update_clears_what_it_does_not_mention():
	bag.put(10, {"itemId": 100})
	bag.apply_update(_update([]))
	assert_true(bag.item_at(10).is_empty())


func test_potions_and_experience_ride_along():
	bag.apply_update(_update([], {"hpPotions": 3, "mpPotions": 1, "experience": 12345678901}))
	assert_eq(bag.hp_potions, 3)
	assert_eq(bag.mp_potions, 1)
	assert_eq(bag.experience, 12345678901)


func test_every_change_bumps_the_version():
	var before := bag.version
	bag.apply_update(_update([]))
	assert_gt(bag.version, before, "an update")
	before = bag.version
	bag.put(5, {"itemId": 1})
	assert_gt(bag.version, before, "a put")
	before = bag.version
	bag.clear()
	assert_gt(bag.version, before, "a clear")


func test_clear_empties_everything():
	bag.apply_update(_update([{"itemId": 100}], {"hpPotions": 2, "mpPotions": 2, "experience": 5}))
	bag.clear()
	assert_true(bag.item_at(0).is_empty())
	assert_eq(bag.hp_potions, 0)
	assert_eq(bag.mp_potions, 0)
	assert_eq(bag.experience, 0)


func test_holds_is_about_the_placeholder_not_the_shape():
	assert_false(Inventory.holds(null))
	assert_false(Inventory.holds({}))
	assert_false(Inventory.holds({"itemId": -1}))
	assert_false(Inventory.holds("junk"))
	assert_true(Inventory.holds({"itemId": 0}), "item 0 is a real item")


func test_the_regions():
	assert_true(Inventory.is_equipment(0))
	assert_true(Inventory.is_equipment(4))
	assert_false(Inventory.is_equipment(5))
	assert_false(Inventory.is_equipment(-1))
	assert_true(Inventory.is_backpack(5))
	assert_true(Inventory.is_backpack(44))
	assert_false(Inventory.is_backpack(45))
	assert_true(Inventory.is_ground_loot(45))
	assert_true(Inventory.is_ground_loot(54))
	assert_false(Inventory.is_ground_loot(55))
	assert_true(bag.item_at(-1).is_empty(), "out of range is empty, not an error")
	assert_true(bag.item_at(45).is_empty())


func test_first_empty_backpack_slot_skips_equipment():
	assert_eq(bag.first_empty_backpack(), 5)
	for i in range(5, 45):
		bag.put(i, {"itemId": 1})
	assert_eq(bag.first_empty_backpack(), -1)
	bag.put(30, {})
	assert_eq(bag.first_empty_backpack(), 30)


# --- the bag at our feet ---------------------------------------------------

func test_the_nearest_bag_within_reach():
	var entities := EntityRegistry.new(func() -> int: return 0)
	entities.apply_load({"containers": [
		_bag(1, Vector2(100, 0), [{"itemId": 100}]),
		_bag(2, Vector2(40, 0), [{"itemId": 101}]),
	]})
	var found := Inventory.nearest_loot(entities, Vector2.ZERO, 28)
	assert_eq(int(found["id"]), 2)
	assert_eq(int(found["items"][0]["itemId"]), 101, "the loader keeps the bag's items")


func test_the_pickup_radius_is_the_servers():
	# Player size + 24, so 52 for a 28px character. The web client's old
	# guess, three quarters of the sprite, sat under it and F never found
	# anything.
	var near := EntityRegistry.new(func() -> int: return 0)
	near.apply_load({"containers": [_bag(1, Vector2(51.9, 0), [{"itemId": 100}])]})
	assert_false(Inventory.nearest_loot(near, Vector2.ZERO, 28).is_empty())
	var far := EntityRegistry.new(func() -> int: return 0)
	far.apply_load({"containers": [_bag(1, Vector2(52.0, 0), [{"itemId": 100}])]})
	assert_true(Inventory.nearest_loot(far, Vector2.ZERO, 28).is_empty())


# --- what may be equipped --------------------------------------------------

func test_equipment_must_match_the_slot_exactly():
	var wand := _catalog(102)
	assert_true(ItemRules.can_equip(wand, 0, 2, content), "a wizard wields a wand")
	assert_false(ItemRules.can_equip(wand, 1, 2, content), "but not as armor")
	assert_false(ItemRules.can_equip(_catalog(200), 0, 2, content),
		"a potion is never equipment, and -1 means no slot, not any slot")
	assert_false(ItemRules.can_equip(_catalog(105), 0, 2, content), "nor is a stack")


func test_the_class_decides():
	var wand := _catalog(102)
	assert_false(ItemRules.can_equip(wand, 0, 0, content), "a barbarian cannot")
	var bow := _catalog(100)
	assert_false(ItemRules.can_equip(bow, 0, 0, content), "a light weapon no fixture class allows")
	assert_false(ItemRules.can_equip(bow, 0, 2, content))
	var robe := _catalog(103)
	assert_true(ItemRules.can_equip(robe, 1, 2, content))
	assert_false(ItemRules.can_equip(robe, 1, 0, content))


func test_universal_gear_fits_anyone():
	var ring := _catalog(104)
	assert_true(ItemRules.can_equip(ring, 4, 0, content))
	assert_true(ItemRules.can_equip(ring, 4, 2, content))
	assert_false(ItemRules.can_equip(ring, 3, 0, content), "in its own slot only")


func test_the_archetype_list_narrows_weapons():
	# The barbarian allows heavy weapons of archetypes 1-3; the hammer is a 7.
	assert_true(ItemRules.can_equip(_catalog(101), 0, 0, content))
	assert_false(ItemRules.can_equip(_catalog(106), 0, 0, content))
	# The wizard lists no archetypes at all, which is "any", not "none".
	assert_true(ItemRules.can_equip(_catalog(102), 0, 2, content))


func test_what_the_catalog_does_not_know_is_refused():
	assert_false(ItemRules.can_equip({"itemId": 9999, "targetSlot": 0}, 0, 2, content), "an unknown item")
	assert_false(ItemRules.can_equip(_catalog(102), 0, 7, content), "an unknown class")
	assert_false(ItemRules.can_equip(_catalog(102), 0, 2, null), "no content at all")
	assert_false(ItemRules.can_equip({}, 0, 2, content), "nothing")
	# An itemClass id that is neither weapon, armor nor universal -- the
	# server's allowsItemClass falls through to false, and so do we.
	content.library.items[999] = {"itemId": 999, "targetSlot": 0, "itemClass": 7}
	assert_false(ItemRules.can_equip({"itemId": 999, "targetSlot": 0}, 0, 2, content), "an unplaceable class")


func test_the_catalog_answers_for_a_weapons_projectile_group():
	assert_eq(content.item_projectile_group(100), 10)
	assert_eq(content.item_projectile_group(200), 0, "a potion fires nothing")
