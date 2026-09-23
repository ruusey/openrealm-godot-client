extends GutTest

## RealmState's handling of the server's world stream.

var state: RealmState
var now := 1000


func before_each():
	state = RealmState.new(null, func() -> int: return now)


func test_tile_indices_are_not_transposed():
	# NetTile's xIndex is the ROW and yIndex the COLUMN -- the server builds
	# `new NetTile(id, layer, y, x)`. Reading them at face value transposes
	# the whole map, which is invisible near a spawn on the diagonal and
	# worsens the further you walk from it.
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [
		{"tileId": 7, "layer": 0, "xIndex": 1, "yIndex": 3},   # row 1, column 3
	]})
	assert_eq(state.tiles.tile_at(0, 3, 1), 7, "column 3, row 1")
	assert_eq(state.tiles.tile_at(0, 1, 3), -1, "the transposed cell stays empty")


func test_a_tile_lands_where_its_world_position_says():
	# Walking away from the spawn diagonal is where a transpose shows up, so
	# anchor the check off-diagonal.
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [
		WireHelper.tile(9, GameConstants.COLLISION_LAYER, 10, 2),
	]})
	assert_eq(state.tiles.tile_at(GameConstants.COLLISION_LAYER, 10, 2), 9,
		"column 10, row 2")
	assert_eq(state.tiles.tile_at(GameConstants.COLLISION_LAYER, 2, 10), -1)


func test_load_map_records_dimensions_and_tiles():
	state.apply_packet("LoadMapPacket", {
		"realmId": 7, "mapId": 2, "mapWidth": 64, "mapHeight": 32,
		"tiles": [WireHelper.tile(3, 0, 1, 1), WireHelper.tile(9, 1, 1, 1)],
	})
	assert_eq(state.tiles.realm_id, 7)
	assert_eq(state.tiles.map_id, 2)
	assert_eq(state.tiles.width, 64)
	assert_eq(state.tiles.height, 32)
	assert_eq(state.tiles.layers[0][Vector2i(1, 1)], 3, "layer 0 keeps the ground tile")
	assert_eq(state.tiles.layers[1][Vector2i(1, 1)], 9, "layer 1 keeps the collision tile")


func test_load_map_accumulates_deltas():
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(2, 0, 5, 5)]})
	assert_eq(state.tiles.layers[0].size(), 2, "LoadMapPacket is a delta, not a replacement")


func test_realm_change_clears_the_stale_world():
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(5, "a", Vector2.ZERO)]})
	state.apply_packet("LoadMapPacket", {"realmId": 2, "tiles": [WireHelper.tile(4, 0, 9, 9)]})
	assert_eq(state.tiles.realm_id, 2)
	assert_eq(state.tiles.layers[0].size(), 1, "old realm tiles are dropped")
	assert_eq(state.entities.players.size(), 0, "old realm entities are dropped")


func test_load_adds_players_enemies_bullets_containers_portals():
	state.apply_packet("LoadPacket", {
		"players": [WireHelper.player(1, "Ruu", Vector2(10, 20), 11, 3)],
		"enemies": [WireHelper.enemy(2, 42, Vector2(30, 40), 12, 80)],
		"bullets": [{"id": 3, "projectileId": 7, "size": 8, "pos": {"x": 1, "y": 2},
			"dX": 0.5, "dY": 0.0, "angle": 1.5, "magnitude": 2.0, "range": 300.0, "createdTime": 99}],
		"containers": [{"lootContainerId": 4, "tier": 2, "isChest": true,
			"items": [{}, {}], "pos": {"x": 5, "y": 6}}],
		"portals": [{"id": 5, "portalId": 1, "toRealmId": 9, "pos": {"x": 7, "y": 8}}],
		"difficulty": 2,
	})
	assert_eq(state.entities.players[1]["name"], "Ruu")
	assert_eq(state.entities.players[1]["class_id"], 3)
	assert_eq(state.entities.enemies[2]["enemy_id"], 42)
	assert_eq(state.entities.enemies[2]["health"], 80)
	assert_eq(state.projectiles.bullets[3]["range"], 300.0)
	assert_eq(state.entities.containers[4]["item_count"], 2)
	assert_true(state.entities.containers[4]["is_chest"])
	assert_eq(state.entities.portals[5]["to_realm_id"], 9)


func test_load_updates_an_existing_entity_in_place():
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(2, 42, Vector2(0, 0), 12, 100)]})
	now += 50
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(2, 42, Vector2(64, 0), 12, 30)]})
	assert_eq(state.entities.enemies.size(), 1, "the same id is not duplicated")
	assert_eq(state.entities.enemies[2]["health"], 30, "stats are refreshed")
	assert_eq(state.entities.enemies[2]["snaps"].size(), 2, "both positions are kept for interpolation")


func test_load_sets_local_class_from_own_player():
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO, 11, 6)]})
	assert_eq(state.local.class_id, 6)


func test_unload_removes_entities():
	state.apply_packet("LoadPacket", {
		"players": [WireHelper.player(1, "a", Vector2.ZERO)],
		"enemies": [WireHelper.enemy(2, 1, Vector2.ZERO)],
		"bullets": [{"id": 3, "pos": {"x": 0, "y": 0}}],
		"containers": [{"lootContainerId": 4, "pos": {"x": 0, "y": 0}}],
		"portals": [{"id": 5, "pos": {"x": 0, "y": 0}}],
	})
	state.apply_packet("UnloadPacket", {"players": [1], "enemies": [2], "bullets": [3], "containers": [4], "portals": [5]})
	assert_eq(state.entities.players.size(), 0)
	assert_eq(state.entities.enemies.size(), 0)
	assert_eq(state.projectiles.bullets.size(), 0)
	assert_eq(state.entities.containers.size(), 0)
	assert_eq(state.entities.portals.size(), 0)


func test_unload_of_an_unknown_id_is_harmless():
	state.apply_packet("UnloadPacket", {"players": [999]})
	assert_eq(state.entities.players.size(), 0)


func test_object_move_updates_position_and_attack_flag():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "a", Vector2.ZERO)]})
	state.apply_packet("ObjectMovePacket", {"movements": [
		{"entityId": 1, "entityType": GameConstants.ENTITY_PLAYER, "posX": 50.0, "posY": 60.0,
		 "velX": 1.0, "velY": 0.0, "flags": 1},
	]})
	var snaps: Array = state.entities.players[1]["snaps"]
	assert_eq(snaps[-1]["pos"], Vector2(50, 60))
	assert_eq(snaps[-1]["vel"], Vector2(1, 0))
	assert_true(state.entities.players[1]["attacking"], "flag bit 0 is the attacking flag")


func test_object_move_for_an_unknown_entity_is_ignored():
	state.apply_packet("ObjectMovePacket", {"movements": [
		{"entityId": 404, "entityType": GameConstants.ENTITY_ENEMY, "posX": 1.0, "posY": 1.0,
		 "velX": 0.0, "velY": 0.0, "flags": 0},
	]})
	assert_eq(state.entities.enemies.size(), 0)


func test_an_update_for_a_remote_player_keeps_the_maxima_its_bars_need():
	# The server sends every player in view its stats with the backpack
	# stripped; ours is the only one whose inventory it fills.
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(2, "You", Vector2.ZERO)]})
	state.apply_packet("UpdatePacket", {"playerId": 2, "playerName": "You",
		"stats": {"hp": 200, "mp": 80}, "health": 150, "mana": 40, "inventory": []})
	var you: Dictionary = state.entities.players[2]
	assert_eq(you["max_health"], 200)
	assert_eq(you["max_mana"], 80)
	assert_eq(you["health"], 150)
	assert_eq(you["mana"], 40)
	assert_eq(state.local.health, 0, "not ours")
	state.apply_packet("UpdatePacket", {"playerId": 7, "stats": {"hp": 1}, "inventory": []})
	assert_false(state.entities.players.has(7), "an update for nobody in view is dropped")


func test_player_state_keeps_the_stacks_beside_the_effects():
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(2, "You", Vector2.ZERO)]})
	state.apply_packet("PlayerStatePacket", {"playerId": 2, "health": 1, "mana": 1,
		"effectIds": [17, 36], "effectTimes": [0, 0], "effectStacks": [4, 2]})
	assert_eq(state.entities.players[2]["effects"], [17, 36])
	assert_eq(state.entities.players[2]["effect_stacks"], [4, 2])


func test_object_move_routes_by_entity_type():
	state.apply_packet("LoadPacket", {
		"players": [WireHelper.player(1, "a", Vector2.ZERO)],
		"enemies": [WireHelper.enemy(1, 5, Vector2.ZERO)],
		"bullets": [{"id": 1, "pos": {"x": 0, "y": 0}}],
	})
	# The same numeric id in all three tables: only the addressed one moves.
	state.apply_packet("ObjectMovePacket", {"movements": [
		{"entityId": 1, "entityType": GameConstants.ENTITY_ENEMY, "posX": 99.0, "posY": 0.0,
		 "velX": 0.0, "velY": 0.0, "flags": 0},
	]})
	assert_eq(state.entities.enemies[1]["snaps"][-1]["pos"], Vector2(99, 0))
	assert_eq(state.entities.players[1]["snaps"][-1]["pos"], Vector2.ZERO)
	assert_eq(state.projectiles.bullets[1]["pos"], Vector2.ZERO, "a bullet is simulated, not snapshotted, and is not addressed by ObjectMove")


func test_compact_move_resolves_short_ids_and_dequantises_velocity():
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(500, 1, Vector2.ZERO, 77)]})
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 77, "posX": 12.0, "posY": 34.0,
		 "velXFixed": 64, "velYFixed": -128, "flags": 0},
	]})
	var snaps: Array = state.entities.enemies[500]["snaps"]
	assert_eq(snaps[-1]["pos"], Vector2(12, 34))
	assert_almost_eq(snaps[-1]["vel"].x, 0.5, 0.0001, "velXFixed is value * 128")
	assert_almost_eq(snaps[-1]["vel"].y, -1.0, 0.0001)


func test_compact_move_with_an_unmapped_short_id_is_ignored():
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 999, "posX": 1.0, "posY": 1.0, "velXFixed": 0, "velYFixed": 0, "flags": 0},
	]})
	assert_eq(state.entities.enemies.size(), 0)


func test_short_id_is_released_on_unload():
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(500, 1, Vector2.ZERO, 77)]})
	state.apply_packet("UnloadPacket", {"enemies": [500]})
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(600, 1, Vector2(5, 5), 77)]})
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 77, "posX": 20.0, "posY": 0.0, "velXFixed": 0, "velYFixed": 0, "flags": 0},
	]})
	assert_eq(state.entities.enemies[600]["snaps"][-1]["pos"], Vector2(20, 0), "the short id now points at the new entity")


func test_zero_short_id_is_not_registered():
	# shortId 0 means "no short id assigned"; mapping it would alias entities.
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(1, 1, Vector2.ZERO, 0)]})
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 0, "posX": 50.0, "posY": 0.0, "velXFixed": 0, "velYFixed": 0, "flags": 0},
	]})
	assert_eq(state.entities.enemies[1]["snaps"][-1]["pos"], Vector2.ZERO)


func test_snapshot_buffer_is_bounded():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "a", Vector2.ZERO)]})
	for i in 20:
		now += 62
		state.apply_packet("ObjectMovePacket", {"movements": [
			{"entityId": 1, "entityType": 0, "posX": float(i), "posY": 0.0,
			 "velX": 0.0, "velY": 0.0, "flags": 0},
		]})
	var snaps: Array = state.entities.players[1]["snaps"]
	assert_true(snaps.size() < 10, "older snapshots are discarded: %d kept" % snaps.size())
	assert_true(snaps[0]["t"] >= now - EntitySnapshots.RETAIN_MS, "nothing outside the window")


func test_update_packet_applies_only_to_the_local_player():
	state.local.id = 1
	state.apply_packet("UpdatePacket", {"playerId": 2, "playerName": "someone else", "health": 50,
		"mana": 10, "stats": {"spd": 99}})
	assert_eq(state.local.name, "")
	state.apply_packet("UpdatePacket", {"playerId": 1, "playerName": "me", "health": 500,
		"mana": 200, "stats": {"spd": 30}})
	assert_eq(state.local.name, "me")
	assert_eq(state.local.health, 500)
	assert_eq(state.local.mana, 200)
	assert_eq(state.local.stats["spd"], 30)


func test_player_state_updates_remote_and_local():
	state.local.id = 1
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO), WireHelper.player(2, "you", Vector2.ZERO)]})
	state.apply_packet("PlayerStatePacket", {"playerId": 2, "health": 120, "mana": 30, "effectIds": [4, 7]})
	assert_eq(state.entities.players[2]["health"], 120)
	assert_eq(state.entities.players[2]["effects"], [4, 7])
	assert_eq(state.local.health, 0, "another player's state does not touch local hp")

	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 900, "mana": 80, "effectIds": []})
	assert_eq(state.local.health, 900)
	assert_eq(state.local.mana, 80)


func test_player_state_for_an_unloaded_player_is_harmless():
	state.apply_packet("PlayerStatePacket", {"playerId": 77, "health": 1, "mana": 1, "effectIds": []})
	assert_eq(state.entities.players.size(), 0)


func test_apply_packet_dispatches_by_name():
	state.local.id = 1
	state.apply_packet("LoadMapPacket", {"realmId": 3, "mapId": 1, "mapWidth": 8, "mapHeight": 8, "tiles": []})
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2.ZERO)]})
	state.apply_packet("UpdatePacket", {"playerId": 1, "playerName": "me", "health": 10, "mana": 1, "stats": {}})
	state.apply_packet("PlayerStatePacket", {"playerId": 1, "health": 11, "mana": 2, "effectIds": []})
	state.apply_packet("ObjectMovePacket", {"movements": []})
	state.apply_packet("CompactMovePacket", {"movements": []})
	state.apply_packet("UnloadPacket", {"players": []})
	state.apply_packet("PlayerPosAckPacket", {"seq": 1, "posX": 0.0, "posY": 0.0})
	assert_eq(state.tiles.realm_id, 3)
	assert_eq(state.local.health, 11)


func test_apply_packet_ignores_packets_the_slice_does_not_model():
	state.apply_packet("TextEffectPacket", {"text": "123"})
	state.apply_packet("PartyUpdatePacket", {})
	pass_test("unmodelled packets are dropped without error")


func test_reset_world_clears_everything_but_identity():
	state.local.id = 9
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "a", Vector2.ZERO, 5)]})
	state.reset_world()
	assert_eq(state.entities.players.size(), 0)
	assert_eq(state.tiles.layers.size(), 0)
	assert_eq(state.local.id, 9, "identity survives a world reset")


func test_compact_move_resolves_a_player_short_id():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(300, "you", Vector2.ZERO, 42)]})
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 42, "posX": 8.0, "posY": 9.0, "velXFixed": 0, "velYFixed": 0, "flags": 1},
	]})
	assert_eq(state.entities.players[300]["snaps"][-1]["pos"], Vector2(8, 9))
	assert_true(state.entities.players[300]["attacking"])


func test_compact_move_for_a_vanished_entity_is_ignored():
	# The short id can outlive its entity if a despawn is processed between the
	# server building the move batch and us applying it.
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(500, 1, Vector2.ZERO, 77)]})
	state.entities.enemies.erase(500)
	state.apply_packet("CompactMovePacket", {"movements": [
		{"shortEntityId": 77, "posX": 1.0, "posY": 1.0, "velXFixed": 0, "velYFixed": 0, "flags": 0},
	]})
	assert_eq(state.entities.enemies.size(), 0, "the stale short id resolves to nothing and is skipped")


func test_object_move_with_an_unrecognised_entity_type_is_ignored():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "a", Vector2.ZERO)]})
	state.apply_packet("ObjectMovePacket", {"movements": [
		{"entityId": 1, "entityType": 99, "posX": 77.0, "posY": 0.0, "velX": 0.0, "velY": 0.0, "flags": 0},
	]})
	assert_eq(state.entities.players[1]["snaps"][-1]["pos"], Vector2.ZERO, "an unknown entity type moves nothing")


func test_tile_at_reads_a_single_cell():
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(7, 0, 3, 4)]})
	assert_eq(state.tiles.tile_at(0, 3, 4), 7)
	assert_eq(state.tiles.tile_at(0, 9, 9), -1, "an unrevealed cell reads as -1")
	assert_eq(state.tiles.tile_at(5, 3, 4), -1, "so does an unknown layer")


func test_facing_ignores_a_negligible_direction():
	state.local.facing = "back"
	state.local.face_toward(Vector2.ZERO)
	assert_eq(state.local.facing, "back", "a zero aim does not spin the sprite")


# --- portals and realm transitions -----------------------------------------

func test_portal_load_keeps_what_gets_drawn():
	state.apply_packet("LoadPacket", {
		"portals": [WireHelper.portal(5, 3, Vector2(7, 8), "Deep Beach", 2)]})
	var portal: Dictionary = state.entities.portals[5]
	assert_eq(portal["portal_id"], 3, "which resolves the art")
	assert_eq(portal["label"], "Deep Beach")
	assert_eq(portal["tier"], 2)


func test_a_map_change_within_one_realm_still_clears():
	# A dungeon assembled inside the realm you are standing in reuses its
	# realm id; watching only that leaves the old map's tiles underneath.
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 2,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(3, 1, Vector2.ZERO)]})
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 4, "dungeonId": 6,
		"tiles": [WireHelper.tile(2, 0, 9, 9)]})
	assert_eq(state.tiles.layers[0].size(), 1, "the old map's tiles are gone")
	assert_eq(state.entities.enemies.size(), 0, "so are its enemies")
	assert_eq(state.tiles.dungeon_id, 6)


func test_the_first_load_map_keeps_entities_that_already_arrived():
	# The initial connect is a realm change too, and wiping there races the
	# server's first LoadPacket -- the native client records that as one to
	# two seconds of empty map.
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(5, "me", Vector2.ZERO)]})
	state.apply_packet("LoadMapPacket", {"realmId": 3, "mapId": 2,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	assert_eq(state.entities.players.size(), 1)


func test_begin_transition_empties_the_realm_but_keeps_the_player():
	state.local.id = 5
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 2,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadPacket", {
		"players": [WireHelper.player(5, "me", Vector2.ZERO),
			WireHelper.player(6, "you", Vector2(32, 32))],
		"enemies": [WireHelper.enemy(3, 1, Vector2.ZERO)],
	})
	state.local.position = Vector2(64, 64)
	# Set first, so the zero afterwards is this clearing it rather than a
	# value that was never anything else.
	state.local.set_smoothing(Vector2(4.0, 4.0))
	state.begin_transition()
	assert_true(state.transition_pending)
	assert_eq(state.tiles.tile_count(), 0)
	assert_eq(state.local.position, Vector2(64, 64), "the player is the one thing that crosses")
	assert_eq(state.local.smooth_offset, Vector2.ZERO,
		"a correction from the realm we left has nothing to unwind into this one")
	# And it stays in the roster, because that is what draws it: clear it too
	# and the transition is a black screen with no character on it.
	assert_true(state.entities.players.has(5), "we are still on screen")
	assert_false(state.entities.players.has(6), "everyone else is left behind")
	assert_eq(state.entities.enemies.size(), 0)


func test_the_confirming_load_map_also_leaves_us_standing():
	state.local.id = 5
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 2, "tiles": []})
	state.apply_packet("LoadPacket", {"players": [
		WireHelper.player(5, "me", Vector2.ZERO), WireHelper.player(6, "you", Vector2.ZERO)]})
	state.apply_packet("LoadMapPacket", {"realmId": 2, "mapId": 4,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	assert_true(state.entities.players.has(5))
	assert_false(state.entities.players.has(6))


func _object_move(entity_type: int, id: int, position: Vector2) -> Dictionary:
	return {"movements": [{"entityType": entity_type, "entityId": id,
		"posX": position.x, "posY": position.y, "velX": 0.0, "velY": 0.0, "flags": 0}]}


func test_the_first_position_after_a_transition_is_adopted():
	state.local.id = 5
	state.local.position = Vector2(100, 100)
	state.begin_transition()
	state.advance(RealmState.TICK_DELTA * 2.0, Vector2.RIGHT, 0.0)
	# A correction mid-flight, so the offset being zero afterwards is the snap
	# clearing it rather than it never having been set.
	state.local.set_smoothing(Vector2(5.0, 5.0))
	assert_ne(state.local.smooth_offset, Vector2.ZERO)
	state.apply_packet("ObjectMovePacket", _object_move(GameConstants.ENTITY_PLAYER, 5, Vector2(900, 40)))
	assert_eq(state.local.position, Vector2(900, 40), "a teleport, not a mispredict")
	assert_eq(state.local.smooth_offset, Vector2.ZERO, "and nothing to unwind")
	assert_eq(state.movement.pending_input_count(), 0, "the old realm's inputs go with it")
	assert_false(state.transition.awaiting_snap, "consumed once")


func test_an_ordinary_object_move_never_moves_us():
	# Outside a transition the local player reconciles through
	# PlayerPosAckPacket and nothing else; adopting a broadcast position would
	# undo prediction every tick.
	state.local.id = 5
	state.local.position = Vector2(100, 100)
	state.apply_packet("ObjectMovePacket", _object_move(GameConstants.ENTITY_PLAYER, 5, Vector2(900, 40)))
	assert_eq(state.local.position, Vector2(100, 100))


func test_the_snap_waits_for_our_own_id():
	state.local.id = 5
	state.local.position = Vector2(100, 100)
	state.begin_transition()
	state.apply_packet("ObjectMovePacket", _object_move(GameConstants.ENTITY_PLAYER, 6, Vector2(900, 40)))
	assert_eq(state.local.position, Vector2(100, 100), "another player's position is not ours")
	assert_true(state.transition.awaiting_snap, "still waiting")

	state.apply_packet("ObjectMovePacket", _object_move(GameConstants.ENTITY_ENEMY, 5, Vector2(700, 70)))
	assert_eq(state.local.position, Vector2(100, 100), "nor is an enemy that shares the id")
	assert_true(state.transition.awaiting_snap)


func test_a_dungeon_id_change_counts_as_a_move():
	# A dungeon assembled inside the realm you are standing in can arrive on
	# the same realm and map ids; only the dungeon id says you moved.
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 2, "dungeonId": -1,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(3, 1, Vector2.ZERO)]})
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 2, "dungeonId": 7,
		"tiles": [WireHelper.tile(2, 0, 9, 9)]})
	assert_eq(state.tiles.dungeon_id, 7)
	assert_eq(state.tiles.layers[0].size(), 1, "the parent map's tiles are gone")
	assert_eq(state.entities.enemies.size(), 0)


func test_the_answer_clears_the_flag_even_when_the_ids_repeat():
	# Clearing it only on a change would pin the HUD at "entering ..." for the
	# rest of the session on any answer that lands where we already were.
	state.apply_packet("LoadMapPacket", {"realmId": 77, "mapId": 2, "dungeonId": -1, "tiles": []})
	state.begin_transition()
	assert_true(state.transition_pending)
	state.apply_packet("LoadMapPacket", {"realmId": 77, "mapId": 2, "dungeonId": -1,
		"tiles": [WireHelper.tile(1, 0, 0, 0)]})
	assert_false(state.transition_pending)


func test_the_wait_is_bounded_where_the_web_client_bounds_it():
	# Spelled out, not derived: the test below advances by the constant, so it
	# passes at any value. 6000 is the web client's TRANSITION_MAX_MS.
	assert_eq(RealmTransition.MAX_WAIT_MS, 6000)


func test_an_unanswered_transition_gives_up():
	# The server can drop the answer. Neither flag is a state to be stuck in:
	# one leaves the HUD claiming an arrival that never came, the other snaps
	# us to a stale position the next time anything moves.
	state.local.id = 5
	state.begin_transition()
	state.advance(0.1, Vector2.ZERO, 0.0)
	assert_true(state.transition_pending, "still waiting a moment later")

	now += RealmTransition.MAX_WAIT_MS + 1
	state.advance(0.1, Vector2.ZERO, 0.0)
	assert_false(state.transition_pending)
	assert_false(state.transition.awaiting_snap)
