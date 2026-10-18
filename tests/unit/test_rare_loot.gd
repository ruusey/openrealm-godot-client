extends GutTest

## The untiered-drop chime: a white bag, or any new drop holding untiered gear,
## counts once per map -- not again when it drifts back into view.


func _load(registry: EntityRegistry, container: Dictionary) -> int:
	return EntityLoader.apply(registry, {"containers": [container]}, 0.0)


func test_what_counts_as_a_rare_drop():
	assert_true(EntityLoader.is_rare_drop({"tier": 4}), "a white bag")
	assert_false(EntityLoader.is_rare_drop({"tier": 4, "isChest": true}), "a vault chest holds old loot")
	assert_true(EntityLoader.is_rare_drop({"tier": 6, "items": [{"tier": -1, "targetSlot": 0}]}),
		"a boosted bag with an untiered weapon")
	assert_false(EntityLoader.is_rare_drop({"tier": 6, "items": [{"tier": -1, "targetSlot": -1}]}), "essence")
	assert_false(EntityLoader.is_rare_drop({"tier": 0, "items": [{"tier": -1, "targetSlot": 0}]}),
		"a player's dropped brown bag")
	assert_false(EntityLoader.is_rare_drop({"tier": 5, "items": [{"tier": -1, "targetSlot": 0}]}), "a grave")


func test_each_bag_chimes_once_per_map():
	var registry := EntityRegistry.new()
	assert_eq(_load(registry, {"lootContainerId": 3, "tier": 4}), 1)
	assert_eq(_load(registry, {"lootContainerId": 3, "tier": 4}), 0, "the same bag again")
	registry.apply_unload({"containers": [3]})
	assert_eq(_load(registry, {"lootContainerId": 3, "tier": 4}), 0, "back in view")
	registry.clear()
	assert_eq(_load(registry, {"lootContainerId": 3, "tier": 4}), 1, "a new map")
