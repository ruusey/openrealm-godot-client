extends GutTest

## A loot container's art and where it is drawn: loot-containers.json by
## tier, the web client's fallbacks, a chest filling its tile and a bag in
## the middle of it at half a tile.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)


func _drop(id: int, tier: int, chest: bool, at: Vector2) -> void:
	state.apply_packet("LoadPacket", {"containers": [{"lootContainerId": id, "tier": tier, "isChest": chest,
		"items": [], "pos": {"x": at.x, "y": at.y}}]})


func test_the_table_is_loaded_by_tier_and_its_sheets_preloaded():
	assert_eq(content.library.loot_containers[0]["name"], "Brown Bag")
	assert_eq(content.library.loot_containers[-1]["name"], "Chest")
	var alone := ContentLibrary.new()
	alone.loot_containers = {0: {"spriteKey": "loot-only.png"}}
	assert_eq(alone.sheet_keys(), ["loot-only.png"], "a sheet only a bag uses is still preloaded")
	assert_not_null(LootArt.texture(content, 0, false), "a bag the table names")
	assert_not_null(LootArt.texture(content, -1, true), "the chest")


func test_a_tier_the_table_lacks_falls_back_as_the_web_does():
	var bag := LootArt.definition(content.library, 3, false)
	assert_eq([bag["spriteKey"], bag["row"], bag["col"]], ["rotmg-misc.png", 9, 3], "row 9, a column a tier")
	var odd := LootArt.definition(content.library, 7, false)
	assert_eq(odd["col"], 0, "past the fifth column, the first")
	var chest := LootArt.definition(content.library, 9, true)
	assert_eq([chest["spriteKey"], chest["col"], chest["row"]], ["rotmg-projectiles.png", 2, 0])
	var empty := ContentLibrary.new()
	assert_eq(LootArt.definition(empty, -1, false)["spriteKey"], "rotmg-projectiles.png", "tier -1 is a chest")


func test_a_chest_fills_its_tile_and_a_bag_sits_in_the_middle():
	assert_eq(LootArt.rect(content, Vector2(64, 96), -1, true), Rect2(64, 96, 32, 32))
	assert_eq(LootArt.rect(content, Vector2(64, 96), 0, false), Rect2(72, 104, 16, 16), "a quarter in from each side")
	assert_eq(LootArt.rect(content, Vector2(64, 96), 3, false), Rect2(72, 104, 16, 16), "the fallback bag too")


func test_the_ground_pass_draws_a_bag_with_its_art_in_its_rect():
	state.local.id = 1
	_drop(5, 0, false, Vector2(64, 96))
	_drop(6, -1, true, Vector2(128, 96))
	var queue := EntityQueue.new().build(state, content, Rect2(-1000, -1000, 2000, 2000))
	var bags := queue.filter(func(e: Dictionary) -> bool: return e["kind"] == "containers")
	assert_eq(bags.size(), 2)
	var bag: Dictionary = bags.filter(func(e: Dictionary) -> bool: return e["pos"].x < 100)[0]
	assert_not_null(bag["texture"], "art, not the placeholder square")
	assert_eq(bag["pos"], Vector2(72, 104))
	assert_eq(bag["size"], 16.0)
	assert_eq(bag["draw"], Vector2(16, 16))
	assert_eq(EntityRenderer.frame_rect(bag["pos"], bag["size"], bag["draw"], false), Rect2(72, 104, 16, 16),
		"drawn exactly in its rect")
	var chest: Dictionary = bags.filter(func(e: Dictionary) -> bool: return e["pos"].x > 100)[0]
	assert_eq(chest["draw"], Vector2(32, 32))
