extends GutTest

## The quest-complete fountain: seeded sparks that rise and fall, drawn
## round the player who finished the quest wherever they walk.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	state.local.position = Vector2(100, 100)


func _effect(owner: int, at: Vector2) -> Dictionary:
	state.apply_packet("CreateEffectPacket", {"effectType": EffectType.QUEST_COMPLETE, "posX": at.x, "posY": at.y,
		"radius": 48.0, "duration": 1800, "targetPosX": 0.0, "targetPosY": 0.0, "tier": 0, "ownerId": owner})
	return state.abilities.effects[-1]


func test_it_has_its_own_drawer():
	assert_eq(Fx.for_type(EffectType.QUEST_COMPLETE), Callable(FxQuestComplete.draw))


func test_sparks_are_the_same_every_time_and_thrown_upwards():
	assert_eq(FxQuestComplete.fountain_spark(7), FxQuestComplete.fountain_spark(7))
	for i in FxQuestComplete.FOUNTAIN_SPARKS:
		var spark := FxQuestComplete.fountain_spark(i)
		assert_lt(sin(float(spark[1])), 0.0, "spark %d heads up" % i)
		assert_lt(float(spark[0]), FxQuestComplete.LAUNCH_WINDOW + 0.05)


func test_a_spark_rises_then_falls_back():
	var spark := FxQuestComplete.fountain_spark(0)
	var start := FxQuestComplete.arc_point(Vector2.ZERO, spark[1], spark[2], 0.0)
	var peak_age: float = -float(spark[2]) * sin(float(spark[1])) / FxQuestComplete.GRAVITY
	var peak := FxQuestComplete.arc_point(Vector2.ZERO, spark[1], spark[2], peak_age)
	var later := FxQuestComplete.arc_point(Vector2.ZERO, spark[1], spark[2], peak_age * 2.0)
	assert_lt(peak.y, start.y, "up")
	assert_almost_eq(later.y, start.y, 0.5, "and back down as far again")


func test_it_follows_the_local_player():
	var fx := _effect(1, Vector2(100, 100))
	state.local.position = Vector2(300, 140)
	EffectRenderer.follow_owner(state, fx)
	assert_eq(fx["pos"], state.local.centre())


func test_it_follows_another_player_and_stays_put_without_one():
	state.apply_packet("LoadPacket", {"players": [{"id": 2, "name": "Mingau", "accountUuid": "", "characterUuid": "",
		"classId": 0, "size": 28, "pos": {"x": 40.0, "y": 60.0}, "dX": 0.0, "dY": 0.0, "shortId": 2,
		"chatRole": "", "dyeId": 0}]})
	var theirs := _effect(2, Vector2(0, 0))
	EffectRenderer.follow_owner(state, theirs)
	assert_eq(theirs["pos"], state.entities.render_position(state.entities.players[2]) + Vector2(14, 14))
	var nobodys := _effect(0, Vector2(5, 5))
	EffectRenderer.follow_owner(state, nobodys)
	assert_eq(nobodys["pos"], Vector2(5, 5))


func test_it_draws_through_its_life_in_the_renderer():
	# The clock reads 0: started in the past is that far into its life. An
	# error in the drawer would abort the draw and the count would fall short.
	var renderer := WorldRenderer.new()
	renderer.setup(state, content)
	add_child_autofree(renderer)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	camera.position = state.local.centre()
	for age in [0, 100, 400, 900, 1400, 1790]:
		_effect(1, state.local.centre())
		state.abilities.effects[-1]["started"] = -age
	renderer.queue_redraw()
	await wait_process_frames(2)
	assert_eq(renderer.draw_stats["effects"], 6)
