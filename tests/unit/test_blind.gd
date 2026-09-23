extends GutTest

## BLIND (28): enemies, their bars and other bullets past three tiles are
## hidden, ours never are, and the screen darkens past the same edge.
##
## The player stands at (100, 100), so the tunnel is round (114, 114) -- the
## middle of a 28-unit body -- with a radius of 96.

var content: GameData
var state: RealmState


func before_each():
	content = GameData.new()
	await content.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content, func() -> int: return 0)
	state.local.id = 1
	state.local.position = Vector2(100, 100)
	state.local.previous_position = Vector2(100, 100)


func _blind() -> void:
	state.local.effects = [Blind.EFFECT]


func _bullet(at: Vector2, src := 77, predicted := false) -> Dictionary:
	return {"pos": at, "size": 8, "src_entity_id": src, "predicted": predicted}


func test_only_the_status_blinds():
	assert_false(Blind.active(state))
	assert_false(Blind.hides(state, Vector2(900, 900), 16), "sighted, nothing is hidden")
	state.local.effects = [27]
	assert_false(Blind.active(state), "Weakened is not Blind")
	_blind()
	assert_true(Blind.active(state))
	assert_eq(Blind.centre(state), Vector2(114, 114))


func test_a_body_is_seen_until_all_of_it_is_past_the_edge():
	_blind()
	# 16 across: seen while its centre is within 96 + 8 = 104.
	assert_false(Blind.hides(state, Vector2(209, 106), 16), "centre 103 away")
	assert_true(Blind.hides(state, Vector2(211, 106), 16), "centre 105 away")
	# 64 across, centre 120 away: still overlapping the tunnel (96 + 32).
	assert_false(Blind.hides(state, Vector2(202, 82), 64), "a big enemy the tunnel still touches")
	assert_true(Blind.hides(state, Vector2(226, 106), 16), "a small one at the same centre is gone")


func test_bullets_other_than_ours():
	_blind()
	var far := Vector2(260, 110)   # centre 150 away
	assert_true(Blind.hides_bullet(state, _bullet(far)), "an enemy's shot, out of sight")
	assert_false(Blind.hides_bullet(state, _bullet(far, 1)), "ours, confirmed by the server")
	assert_false(Blind.hides_bullet(state, _bullet(far, 0, true)), "ours, predicted")
	assert_false(Blind.hides_bullet(state, _bullet(Vector2(150, 110))), "close enough to see")
	assert_true(BulletRenderer._hidden(state, _bullet(far)), "the bullet layer skips it")


func test_the_ground_pass_drops_enemies_out_of_sight():
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2(100, 100))],
		"enemies": [WireHelper.enemy(10, 1, Vector2(140, 110)), WireHelper.enemy(11, 1, Vector2(400, 110))]})
	var view := Rect2(-1000, -1000, 2000, 2000)
	var enemies := func() -> int:
		return EntityQueue.new().build(state, content, view).filter(
			func(e: Dictionary) -> bool: return e["kind"] == "enemies").size()
	assert_eq(enemies.call(), 2)
	_blind()
	assert_eq(enemies.call(), 1, "the far one is gone, the near one stays")


func test_the_overlay_drops_far_bars_and_darkens_the_screen():
	var overlay := EntityOverlay.new()
	overlay.setup(state)
	add_child_autofree(overlay)
	await wait_process_frames(1)
	state.apply_packet("LoadPacket", {"players": [WireHelper.player(1, "me", Vector2(100, 100))],
		"enemies": [WireHelper.enemy(10, 1, Vector2(140, 110)), WireHelper.enemy(11, 1, Vector2(400, 110))]})
	overlay.refresh()
	assert_eq(overlay.tag_count(), 3, "me and two enemies")
	assert_false(overlay._vignette.visible, "no dark while sighted")
	_blind()
	overlay.refresh()
	assert_eq(overlay.tag_count(), 2, "the far enemy's bar would give it away")
	assert_true(overlay._vignette.visible)
	var middle: Vector2 = overlay._vignette.position + overlay._vignette.size * 0.5
	var to_screen := overlay.get_viewport().get_canvas_transform()
	assert_eq(middle, (to_screen * Vector2(114, 114)).round(), "round the player")
	state.local.effects = []
	overlay.refresh()
	assert_false(overlay._vignette.visible, "gone with the status")


func test_the_fade_is_the_webs_stops_past_the_clear_tunnel():
	var fade := BlindVignette.gradient(0.2).gradient
	assert_eq(fade.offsets, PackedFloat32Array([0.0, 0.2, 0.296, 0.52, 1.0]))
	assert_eq(fade.colors[1].a, 0.0, "clear to the tunnel's edge")
	assert_almost_eq(fade.colors[2].a, 0.55, 0.001)
	assert_almost_eq(fade.colors[3].a, 0.9, 0.001)
	assert_almost_eq(fade.colors[4].a, 0.98, 0.001)


func test_the_realm_step_keeps_a_hidden_bullets_trail_off_the_screen():
	# An enemy's shot from a trail group, far outside the tunnel, standing still.
	var shot := Projectile.from_wire({"id": 5, "projectileId": 22, "size": 8,
		"pos": {"x": 400.0, "y": 110.0}, "angle": 0.0, "magnitude": 0.0, "range": 1000.0,
		"flags": [], "invert": false, "timeStep": 0, "amplitude": 0, "frequency": 0,
		"orbitCenterX": 0.0, "orbitCenterY": 0.0, "orbitRadius": 0.0, "orbitPhase": 0.0,
		"damage": 1, "createdTime": 0, "srcEntityId": 77}, 0)
	state.projectiles.bullets[5] = shot
	_blind()
	for i in 20:
		state.advance(1.0 / 60.0, Vector2.ZERO, 0.0)
	assert_true(state.projectiles.bullets.has(5), "the shot is still in flight")
	assert_eq(state.particles.count, 0, "blind: its trail is not drawn either")
	state.local.effects = []
	for i in 20:
		state.advance(1.0 / 60.0, Vector2.ZERO, 0.0)
	assert_gt(state.particles.count, 0, "sighted, the same shot trails")
