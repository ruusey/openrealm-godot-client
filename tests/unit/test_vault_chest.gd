extends GutTest

## A vault chest reads as somewhere to put things: its preview shows every
## slot even empty, and standing on it opens its slots, which a backpack
## item drags onto.

var content: GameData
var state: RealmState
var overlay: EntityOverlay
var window: LootWindow


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	overlay = EntityOverlay.new()
	overlay.setup(state, content)
	add_child_autofree(overlay)
	window = LootWindow.new()
	window.setup(state, content, InventoryActions.new(state, null, content))
	add_child_autofree(window)


func _container(id: int, chest: bool, at: Vector2, items: Array) -> void:
	state.apply_packet("LoadPacket", {"containers": [{"lootContainerId": id, "tier": -1 if chest else 0,
		"isChest": chest, "items": items, "pos": {"x": at.x, "y": at.y}}]})


func _empty_slots() -> Array:
	var slots := []
	for i in Inventory.LOOT_SIZE:
		slots.append({"itemId": -1})
	return slots


func _scan() -> void:
	window._scan_elapsed = LootWindow.SCAN_INTERVAL
	window._process(0.0)


func test_an_empty_chest_previews_all_its_slots_empty():
	_container(1, true, Vector2(64, 64), _empty_slots())
	overlay.refresh()
	var grid := overlay._loot.preview(1)
	assert_not_null(grid, "an empty chest still gets its grid")
	assert_eq(grid.slot_count(), Inventory.LOOT_SIZE)
	assert_eq(grid.icon_count(), 0)
	assert_eq(grid.size, LootPreview.grid_size(Inventory.LOOT_SIZE), "two full rows")


func test_a_chests_items_sit_in_their_own_slots():
	var items := _empty_slots()
	items[3] = {"itemId": 100, "stackCount": 1}
	_container(1, true, Vector2(64, 64), items)
	overlay.refresh()
	var grid := overlay._loot.preview(1)
	assert_eq(grid.icon_count(), 1)
	assert_true(grid._icons[3].visible, "the fourth slot, where the item is")
	assert_false(grid._icons[0].visible)


func test_an_empty_bag_still_has_no_preview():
	_container(1, false, Vector2(64, 64), _empty_slots())
	overlay.refresh()
	assert_null(overlay._loot.preview(1))


func test_standing_on_an_empty_chest_opens_its_slots():
	_container(1, true, Vector2(64, 64), _empty_slots())
	state.local.position = Vector2(64, 64)
	_scan()
	assert_true(window.visible, "an empty chest still opens")
	assert_true(window.is_chest())
	assert_eq(window._title.text, "Vault Chest")
	assert_true(window._chest_slots.visible)
	assert_true(window._hint.visible)
	assert_eq(window.row_count(), 0)
	assert_eq(window.chest_slot(0).index, Inventory.GROUND_LOOT_START)
	assert_true(window.chest_slot(0)._can_drop_data(Vector2.ZERO, {"slot": Inventory.BACKPACK_START}),
		"a backpack item drags onto a slot")
	assert_true(window._loot_all.disabled, "nothing to take")


func test_the_hint_goes_once_the_vault_quest_is_done():
	_container(1, true, Vector2(64, 64), _empty_slots())
	state.local.position = Vector2(64, 64)
	_scan()
	assert_true(window._hint.visible, "no quest log yet: the hint shows")
	_quests("ACTIVE")
	_scan()
	assert_true(window._hint.visible, "the quest still to do")
	_quests("COMPLETE")
	_scan()
	assert_false(window._hint.visible, "done once, the hint is gone")
	assert_true(window._chest_slots.visible, "the slots stay")


func _quests(status: String) -> void:
	var log := {"quests": [{"id": 201, "status": status,
		"objectives": [{"label": "Store an item", "type": "STORE_IN_VAULT", "progress": 0, "target": 1}]}]}
	state.apply_packet("QuestStatePacket", {"playerId": 1, "stars": 0, "json": JSON.stringify(log)})


func test_a_chest_out_of_drop_reach_does_not_open():
	_container(1, true, Vector2(64, 64), _empty_slots())
	state.local.position = Vector2(64 + LootWindow.CHEST_REACH + 4.0, 64)
	_scan()
	assert_false(window.visible, "a drop from here would land in a new bag")


func test_an_empty_bag_does_not_open_and_a_full_one_lists_rows():
	_container(1, false, Vector2(64, 64), _empty_slots())
	state.local.position = Vector2(64, 64)
	_scan()
	assert_false(window.visible)
	_container(1, false, Vector2(64, 64), [{"itemId": 100, "stackCount": 1}])
	_scan()
	assert_true(window.visible)
	assert_false(window.is_chest())
	assert_eq(window._title.text, "Loot")
	assert_eq(window.row_count(), 1)
	assert_false(window._chest_slots.visible)
