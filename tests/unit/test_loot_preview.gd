extends GutTest

## The grid of what a loot bag holds, under every bag on screen: the web
## client's renderLootPreviews, its sizes, its culling and its switch.

var content: GameData
var state: RealmState
var overlay: EntityOverlay


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	overlay = EntityOverlay.new()
	overlay.setup(state, content)
	add_child_autofree(overlay)


func _drop(id: int, at: Vector2, items: Array) -> void:
	state.apply_packet("LoadPacket", {"containers": [{"lootContainerId": id, "tier": 0, "isChest": false,
		"items": items, "pos": {"x": at.x, "y": at.y}}]})


func _items(ids: Array) -> Array:
	return ids.map(func(id: int) -> Dictionary: return {"itemId": id, "stackCount": 1})


func test_the_grid_is_the_web_clients_five_columns_of_fifteen_pixel_cells():
	assert_eq(LootPreview.grid_size(1), Vector2(17, 17), "one cell and the padding")
	assert_eq(LootPreview.grid_size(5), Vector2(77, 17), "a full row")
	assert_eq(LootPreview.grid_size(7), Vector2(77, 32), "a second row, as wide as the first")
	assert_eq(LootPreview.cell_origin(0), Vector2(3, 3), "an 11px icon centred in its cell")
	assert_eq(LootPreview.cell_origin(4), Vector2(63, 3))
	assert_eq(LootPreview.cell_origin(6), Vector2(18, 18), "the second row")


func test_only_real_items_are_shown_and_at_most_two_rows_of_them():
	var items := _items([100, 101]) + [{"itemId": -1}, {}] + _items([102])
	assert_eq(LootPreview.shown_items(items).map(func(i: Dictionary) -> int: return i["itemId"]), [100, 101, 102],
		"the -1 placeholders of an empty slot are not items")
	assert_eq(LootPreview.shown_items(_items([100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100])).size(), 10)


func test_a_bag_gets_its_grid_centred_under_it_with_each_items_icon():
	_drop(7, Vector2(64, 64), _items([100, 101, 102]))
	overlay.refresh()
	var grid := overlay._loot.preview(7)
	assert_not_null(grid)
	assert_eq(overlay.previews, 1)
	assert_eq(grid.size, Vector2(47, 17))
	# The tile's bottom middle is (80, 96) at 1x; 80 - 47/2 rounds to 57.
	assert_eq(grid.position, Vector2(57, 100), "centred, four pixels under the bag")
	assert_eq(grid.icon_count(), 3)
	assert_not_null(grid._icons[0].texture)
	assert_eq(grid._icons[0].texture, content.item_texture(100), "the item's own sprite off the sheet")
	assert_eq(grid._icons[0].size, Vector2(11, 11))
	assert_eq(grid.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a click goes through it to the world")
	assert_eq(grid._icons[0].mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_every_bag_on_screen_gets_one_not_only_the_one_underfoot():
	state.local.position = Vector2.ZERO
	_drop(1, Vector2.ZERO, _items([100]))
	_drop(2, Vector2(96, 0), _items([101, 102]))
	_drop(3, Vector2(9000, 9000), _items([100]))
	overlay.refresh()
	assert_not_null(overlay._loot.preview(1), "the bag at our feet")
	assert_not_null(overlay._loot.preview(2), "a bag three tiles off, as the web shows it")
	assert_null(overlay._loot.preview(3), "one well off the screen is culled")
	assert_eq(overlay.previews, 2)


func test_an_empty_bag_has_none_and_a_bag_that_goes_takes_its_grid():
	_drop(1, Vector2.ZERO, [{"itemId": -1}])
	_drop(2, Vector2(32, 0), _items([100]))
	overlay.refresh()
	assert_null(overlay._loot.preview(1), "nothing in it, nothing to show")
	assert_eq(overlay._loot.size(), 1)
	state.apply_packet("UnloadPacket", {"containers": [2]})
	overlay.refresh()
	assert_eq(overlay._loot.size(), 0)


func test_an_item_with_no_art_keeps_its_cell_empty():
	_drop(1, Vector2.ZERO, _items([100, 99999, 101]))
	overlay.refresh()
	var grid := overlay._loot.preview(1)
	assert_not_null(grid)
	assert_eq(grid.item_count(), 3, "three cells wide")
	assert_eq(grid.icon_count(), 2)
	assert_false(grid._icons[1].visible, "the web skips the sprite and leaves its cell")


func test_the_switch_is_on_by_default_as_the_webs_and_turns_every_grid_off():
	assert_eq(GameSettings.GRAPHICS["loot_preview"], ["Loot bag preview", true])
	_drop(1, Vector2.ZERO, _items([100]))
	overlay.refresh()
	assert_eq(overlay.previews, 1)
	state.settings.set_on("loot_preview", false)
	overlay.refresh()
	assert_eq(overlay.previews, 0)
	assert_eq(overlay._loot.size(), 0)
	state.settings.set_on("loot_preview", true)
	overlay.refresh()
	assert_eq(overlay.previews, 1)


func test_the_grids_sit_over_the_names_and_under_the_blind_dark():
	var loot_root: Control = overlay._loot.preview_parent()
	assert_not_null(loot_root)
	assert_gt(loot_root.get_index(), overlay._root.get_index(), "over the tags and numbers")
	assert_lt(loot_root.get_index(), overlay._vignette.get_index(), "under the vignette")
