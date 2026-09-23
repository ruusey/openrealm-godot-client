extends GutTest

## Which way the local player is drawn as it walks. The sprite sheet has one
## side clip and mirrors it, so "left" is side + flip, not a clip of its own.

var state: RealmState
var data: GameData
var now := 1000


func before_each():
	now = 1000
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(data, func() -> int: return now)
	state.local.id = 1
	state.local.class_id = 0
	state.local.position = Vector2(100, 100)
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2(100, 100))]})


func _walk(direction: Vector2) -> void:
	# Enough delta to cross at least one fixed tick.
	state.advance(GameConstants.TICK_DELTA * 2.0, direction, 0.0)


func test_walking_left_faces_side():
	_walk(Vector2(-1, 0))
	assert_eq(state.local.facing, "side")


func test_walking_right_faces_side():
	_walk(Vector2(1, 0))
	assert_eq(state.local.facing, "side")


func test_walking_down_faces_front():
	_walk(Vector2(0, 1))
	assert_eq(state.local.facing, "front")


func test_walking_up_faces_back():
	_walk(Vector2(0, -1))
	assert_eq(state.local.facing, "back")


func test_a_diagonal_prefers_the_dominant_axis():
	_walk(Vector2(-1, 0.4).normalized())
	assert_eq(state.local.facing, "side", "mostly horizontal reads as side")
	_walk(Vector2(0.4, 1).normalized())
	assert_eq(state.local.facing, "front", "mostly vertical reads as front")


func test_standing_still_keeps_the_last_facing():
	_walk(Vector2(-1, 0))
	_walk(Vector2.ZERO)
	assert_eq(state.local.facing, "side", "facing is not reset by stopping")
	assert_false(state.local.moving)
