extends GutTest

## The realm from above: the picture, the roster and the pins, and how the
## router feeds them.

var state: RealmState
var content: GameData
var now := 10_000


func before_each():
	now = 10_000
	content = GameData.new()
	content.library.tiles = {
		1: {"name": "Grass", "data": {}},
		2: {"name": "Wall", "data": {"hasCollision": 1, "isWall": 1}},
		3: {"name": "Water", "data": {"slows": 1}},
	}
	state = RealmState.new(content, func() -> int: return now)


func _map(realm_id: int, tiles: Array, width := 8, height := 6, map_id := 1) -> void:
	state.apply_packet("LoadMapPacket", {"realmId": realm_id, "mapId": map_id,
		"mapWidth": width, "mapHeight": height, "tiles": tiles})


func _marker(message: String) -> void:
	state.apply_packet("TextPacket", {"from": "EVENT_MARKER", "to": "Ruu", "message": message})


# --- the picture -------------------------------------------------------------

func test_the_picture_is_the_map_s_size_and_void_until_painted():
	assert_null(state.minimap.image, "nothing before a map")
	_map(1, [])
	assert_not_null(state.minimap.image)
	assert_eq(state.minimap.image.get_size(), Vector2i(8, 6))
	assert_eq(state.minimap.image.get_pixel(3, 3), MinimapPalette.VOID)


func test_tiles_paint_where_the_world_puts_them():
	_map(1, [WireHelper.tile(1, 0, 5, 2), WireHelper.tile(3, 0, 6, 2),
		WireHelper.tile(1, 0, 7, 2), WireHelper.tile(2, 1, 7, 2)])
	var image := state.minimap.image
	assert_eq(image.get_pixel(5, 2), MinimapPalette.GRASS, "column 5, row 2")
	assert_eq(image.get_pixel(2, 5), MinimapPalette.VOID, "not transposed")
	assert_eq(image.get_pixel(6, 2), MinimapPalette.WATER)
	assert_eq(image.get_pixel(7, 2), MinimapPalette.WALL, "the collision layer over the grass wins")


func test_a_wall_sent_before_its_floor_still_wins():
	# Two chunks: the wall lands first, the floor under it later.
	_map(1, [WireHelper.tile(2, 1, 4, 4)])
	_map(1, [WireHelper.tile(1, 0, 4, 4)])
	assert_eq(state.minimap.image.get_pixel(4, 4), MinimapPalette.WALL)


func test_more_of_the_same_map_adds_to_the_picture():
	_map(1, [WireHelper.tile(1, 0, 1, 1)])
	var first := state.minimap.version
	_map(1, [WireHelper.tile(1, 0, 2, 2)])
	assert_eq(state.minimap.image.get_pixel(1, 1), MinimapPalette.GRASS, "still there")
	assert_eq(state.minimap.image.get_pixel(2, 2), MinimapPalette.GRASS)
	assert_gt(state.minimap.version, first, "and the panel is told")


func test_a_different_place_starts_a_new_picture_even_at_the_same_size():
	# A dungeon can be the size of the realm it was assembled in; the web
	# client's minimap kept the previous realm's tiles under it.
	_map(1, [WireHelper.tile(1, 0, 1, 1)])
	_map(1, [WireHelper.tile(1, 0, 2, 2)], 8, 6, 2)
	assert_eq(state.minimap.image.get_pixel(1, 1), MinimapPalette.VOID, "the old realm's tile is gone")
	assert_eq(state.minimap.image.get_pixel(2, 2), MinimapPalette.GRASS)


func test_a_tile_outside_the_map_is_ignored():
	_map(1, [WireHelper.tile(1, 0, 8, 0), WireHelper.tile(1, 0, -1, 0), WireHelper.tile(1, 0, 0, 6)])
	assert_eq(state.minimap.width, 8)
	assert_eq(state.minimap.image.get_pixel(0, 0), MinimapPalette.VOID)


func test_a_map_without_a_size_paints_nothing():
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(1, 0, 0, 0)]})
	assert_null(state.minimap.image)


func test_leaving_a_realm_clears_the_picture_and_arriving_paints_the_next():
	_map(1, [WireHelper.tile(1, 0, 1, 1)])
	state.apply_packet("GlobalPlayerPositionPacket", {"players": [
		{"playerId": 2, "name": "Mingau", "x": 1.0, "y": 2.0, "teleportable": true}]})
	_marker("ADD|7|99|64|64|Wyrm")
	state.begin_transition()
	assert_null(state.minimap.image)
	assert_eq(state.minimap.players, [])
	assert_eq(state.minimap.markers, {})
	_map(2, [WireHelper.tile(3, 0, 0, 0)], 4, 4)
	assert_eq(state.minimap.image.get_size(), Vector2i(4, 4))
	assert_eq(state.minimap.image.get_pixel(0, 0), MinimapPalette.WATER)


func test_reset_world_clears_it():
	_map(1, [WireHelper.tile(1, 0, 1, 1)])
	state.reset_world()
	assert_null(state.minimap.image)
	assert_eq(state.minimap.width, 0)


# --- the roster --------------------------------------------------------------

func test_the_roster_is_replaced_whole():
	state.apply_packet("GlobalPlayerPositionPacket", {"players": [
		{"playerId": 2, "name": "Mingau", "x": 96.0, "y": 32.0, "teleportable": true},
		{"playerId": 3, "name": "Ghost", "x": 1.0, "y": 2.0, "teleportable": false}]})
	assert_eq(state.minimap.players.size(), 2)
	assert_eq(state.minimap.players[0], {"id": 2, "name": "Mingau", "position": Vector2(96, 32),
		"teleportable": true})
	assert_false(state.minimap.players[1]["teleportable"])
	state.apply_packet("GlobalPlayerPositionPacket", {"players": [
		{"playerId": 3, "name": "Ghost", "x": 5.0, "y": 5.0, "teleportable": true}]})
	assert_eq(state.minimap.players.size(), 1, "whoever left is gone")


# --- the pins ----------------------------------------------------------------

func test_a_marker_line_pins_the_boss_and_never_reaches_the_chat():
	_marker("ADD|7|99|400|600|Sand Wyrm")
	assert_eq(state.minimap.markers, {"99": {"event_id": 7, "position": Vector2(400, 600),
		"name": "Sand Wyrm", "seen_ms": 10_000}})
	assert_eq(state.chat.lines.size(), 0)


func test_a_name_may_carry_the_separator():
	_marker("ADD|7|99|400|600|Wyrm|of|Auru")
	assert_eq(state.minimap.markers["99"]["name"], "Wyrm|of|Auru")


func test_a_refresh_keeps_the_pin_alive_and_a_remove_drops_it():
	_marker("ADD|7|99|400|600|Wyrm")
	now += 5000
	_marker("ADD|7|99|410|600|Wyrm")
	now += 5000
	state.advance(0.016, Vector2.ZERO, 0.0)
	assert_true(state.minimap.markers.has("99"), "refreshed 5s ago, within the 8s")
	assert_eq(state.minimap.markers["99"]["position"], Vector2(410, 600))
	_marker("REMOVE|99")
	assert_eq(state.minimap.markers, {})


func test_a_pin_the_server_stopped_refreshing_expires():
	_marker("ADD|7|99|400|600|Wyrm")
	now += MinimapState.MARKER_STALE_MS
	state.advance(0.016, Vector2.ZERO, 0.0)
	assert_true(state.minimap.markers.has("99"), "exactly the limit is still fresh")
	now += 1
	state.advance(0.016, Vector2.ZERO, 0.0)
	assert_eq(state.minimap.markers, {}, "a lost REMOVE does not pin a dead boss forever")


func test_malformed_and_foreign_lines_do_nothing():
	_marker("ADD|7|99")
	_marker("REMOVE")
	_marker("HELLO|1|2|3|4|5")
	state.apply_packet("TextPacket", {"from": "SYSTEM", "to": "Ruu", "message": "ADD|7|99|1|2|x"})
	assert_eq(state.minimap.markers, {})
	assert_eq(state.chat.lines.size(), 1, "a SYSTEM line is chat, whatever it says")


# --- hop mode ----------------------------------------------------------------

func _system(message: String) -> void:
	state.apply_packet("TextPacket", {"from": "SYSTEM", "to": "Ruu", "message": message})


func test_the_servers_answer_to_hop_turns_it_on_and_off():
	assert_false(state.minimap.hop, "off until the server says otherwise")
	_system("Hop mode: ON")
	assert_true(state.minimap.hop)
	_system("Welcome to Nexus Auru V1")
	assert_true(state.minimap.hop, "any other SYSTEM line leaves it")
	_system("Hop mode: OFF")
	assert_false(state.minimap.hop)
	assert_eq(state.chat.lines.size(), 3, "and every one of them is still chat")


func test_a_player_saying_it_is_not_the_server():
	state.apply_packet("TextPacket", {"from": "Mingau", "to": "", "message": "Hop mode: ON"})
	assert_false(state.minimap.hop)


func test_hop_mode_survives_a_realm_change_but_not_the_session():
	_map(1, [])
	_system("Hop mode: ON")
	state.begin_transition()
	assert_null(state.minimap.image, "the realm's picture went")
	assert_true(state.minimap.hop, "the server keeps it on the player, not the realm")
	state.reset_world()
	assert_false(state.minimap.hop, "a new login starts it off")
