extends GutTest

## What a cast leaves on the ground, and who is still casting.

var state: RealmState
var content: GameData
var renderer: WorldRenderer
var now := 1000


func before_each():
	now = 1000
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return now)
	state.local.id = 1
	renderer = WorldRenderer.new()
	renderer.setup(state, content)
	add_child_autofree(renderer)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()


func _effect(at: Vector2, duration := 1000) -> void:
	state.apply_packet("CreateEffectPacket", {"effectType": 0, "posX": at.x, "posY": at.y,
		"radius": 40.0, "duration": duration, "targetPosX": 0.0, "targetPosY": 0.0,
		"tier": 2, "ownerId": 1})


func _drawn() -> int:
	return renderer.draw_stats.get("effects", -1)


func test_the_layer_sits_between_the_bullets_and_the_labels():
	assert_gt(renderer.effects.get_index(), renderer.bullets.get_index())
	assert_lt(renderer.effects.get_index(), renderer.debug.get_index())


func test_nothing_is_drawn_with_nothing_landed():
	await wait_process_frames(2)
	assert_eq(_drawn(), 0)


func test_an_effect_in_view_is_drawn_and_one_far_away_is_not():
	_effect(Vector2(20, 20))
	_effect(Vector2(9000, 9000))
	await wait_process_frames(2)
	assert_eq(_drawn(), 1)


func test_the_cast_ring_and_a_cast_bar_count_too():
	state.abilities.show_ring(Vector2.ZERO, 96.0)
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(2, "them", Vector2(30, 30))]})
	state.apply_packet("AbilityCastStartPacket", {"playerId": 2, "abilityId": 13006, "slot": 0,
		"durationMs": 1000, "worldTargetX": 80.0, "worldTargetY": 30.0})
	state.apply_packet("AbilityCastStartPacket", {"playerId": 77, "abilityId": 13006, "slot": 0,
		"durationMs": 1000, "worldTargetX": 0.0, "worldTargetY": 0.0})
	await wait_process_frames(2)
	assert_eq(_drawn(), 2, "the ring and the bar; a caster not in the roster has no bar")


func test_an_expired_effect_is_gone_from_the_count():
	_effect(Vector2.ZERO, 500)
	now += 500
	state.advance(0.0, Vector2.ZERO, 0.0)
	await wait_process_frames(2)
	assert_eq(_drawn(), 0)


func test_the_tier_palette_is_the_web_clients():
	assert_eq(EffectRenderer.TIER_COLOURS.size(), 7)
	assert_eq(EffectRenderer.TIER_COLOURS[0], Color("c0c0c0"))
	assert_eq(EffectRenderer.TIER_COLOURS[6], Color("c060ff"))
