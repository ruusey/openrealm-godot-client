extends GutTest

## Remote entities render INTERP_DELAY_MS in the past, between whichever
## two snapshots bracket that moment -- not the two newest -- and past the
## newest they ride their last velocity until the server is heard from, as
## both reference clients do. A correction that moves the drawn point is
## absorbed as an offset that closes over a few frames.
##
## The cadences here are the server's own: a moving peer is re-sent every
## four ticks (62.5ms), an enemy only when it drifts 4px off its sent
## velocity or after 48 ticks (750ms) of silence.

const DELAY := int(EntitySnapshots.INTERP_DELAY_MS)

var state: RealmState
var now := 0


func before_each():
	# GUT reuses the script instance across tests, so the clock must be reset
	# here or a test that advances it leaks into the next one.
	now = 10_000
	state = RealmState.new(null, func() -> int: return now)


func _entity_with(snapshots: Array, kind := GameConstants.ENTITY_ENEMY) -> Dictionary:
	var entity := state.entities.upsert({}, 1, kind)
	for snapshot in snapshots:
		entity["snaps"].append({"t": snapshot[0], "pos": snapshot[1], "vel": snapshot[2]})
	return entity


func _at(entity: Dictionary) -> Vector2:
	return EntitySnapshots.render_position(entity, now)


func test_no_snapshots_renders_at_origin():
	assert_eq(_at(_entity_with([])), Vector2.ZERO)


func test_single_snapshot_renders_where_it_is_when_still():
	assert_eq(_at(_entity_with([[float(now), Vector2(5, 6), Vector2.ZERO]])), Vector2(5, 6))


func test_single_snapshot_walks_on_its_velocity():
	# A freshly loaded enemy walking straight sends nothing for up to 750ms;
	# held at its load position it stands still and then jumps.
	var entity := _entity_with([[float(now), Vector2(0, 0), Vector2(1, 0)]])
	now += DELAY + 500
	# 1 px/tick for 500ms of render time at 64Hz.
	assert_almost_eq(_at(entity).x, 32.0, 0.001)


func test_interpolates_between_bracketing_snapshots():
	# Render time is now - 100ms = 9900, exactly between 9800 and 10000.
	var entity := _entity_with([
		[9800.0, Vector2(0, 0), Vector2.ZERO],
		[10000.0, Vector2(100, 0), Vector2.ZERO],
	])
	assert_almost_eq(_at(entity).x, 50.0, 0.001, "halfway between the two")


func test_brackets_with_an_older_pair_when_the_newest_are_ahead_of_render_time():
	# A peer heartbeat every 62.5ms: at a 100ms delay the render time falls
	# between the SECOND and THIRD newest samples. Reading only the newest
	# two clamps to the second and holds it -- a 16Hz staircase.
	var entity := _entity_with([
		[9812.5, Vector2(0, 0), Vector2(1, 0)],
		[9875.0, Vector2(4, 0), Vector2(1, 0)],
		[9937.5, Vector2(8, 0), Vector2(1, 0)],
		[10000.0, Vector2(12, 0), Vector2(1, 0)],
	])
	# target 9900: 40% of the way from 9875 to 9937.5.
	assert_almost_eq(_at(entity).x, 5.6, 0.001, "between the second and third newest")
	now = 10_020
	assert_almost_eq(_at(entity).x, 6.88, 0.001, "and moving on, not held")


func test_clamps_to_the_oldest_snapshot_when_behind_all_of_them():
	var entity := _entity_with([
		[9950.0, Vector2(10, 10), Vector2(1, 0)],
		[10000.0, Vector2(99, 99), Vector2(1, 0)],
	])
	# target is 9900, before both snapshots.
	assert_eq(_at(entity), Vector2(10, 10))


func test_extrapolates_on_velocity_past_the_newest_snapshot():
	var entity := _entity_with([
		[9000.0, Vector2(0, 0), Vector2.ZERO],
		[9800.0, Vector2(0, 0), Vector2(1, 0)],
	])
	# target 9900 is 100ms past the newest: velocity is px/tick at 64Hz,
	# so 1 px/tick * 0.1s * 64 = 6.4px.
	assert_almost_eq(_at(entity).x, 6.4, 0.001)


func test_an_enemy_keeps_walking_through_the_servers_750ms_silence():
	# The server re-sends a straight-walking enemy only every 48 ticks. The
	# old 250ms cap froze it for the other 500 and then jumped it forward.
	var entity := _entity_with([[float(now), Vector2(0, 0), Vector2(2, 0)]])
	var last := 0.0
	for frame in range(1, 46):
		now = 10_000 + frame * 16
		var x := _at(entity).x
		if frame > 7:   # once render time has passed the sample
			assert_almost_eq(x - last, 2.0 * 64.0 * 0.016, 0.01, "frame %d moved one frame's worth" % frame)
		last = x


func test_extrapolation_freezes_once_the_server_has_gone_quiet():
	# 1200ms without a word, as both references cap it: past that the
	# velocity is fiction and the sprite parks where it got to.
	var entity := _entity_with([[1000.0, Vector2(0, 0), Vector2(1, 0)]])
	now = 1000 + int(EntitySnapshots.STALE_MS) + 5000
	var parked := _at(entity)
	assert_almost_eq(parked.x, (EntitySnapshots.STALE_MS - DELAY) / 1000.0 * 64.0, 0.001)
	now += 1000
	assert_eq(_at(entity), parked, "and stays parked")


func test_a_quiet_peer_freezes_sooner_than_an_enemy():
	# A moving peer is heard from every 62.5ms, so 300ms of silence means it
	# stopped or left -- the web client's rule -- while an enemy legitimately
	# goes 750ms between corrections.
	var peer := _entity_with([[1000.0, Vector2(0, 0), Vector2(1, 0)]], GameConstants.ENTITY_PLAYER)
	now = 1000 + int(EntitySnapshots.PEER_STALE_MS) + 5000
	assert_almost_eq(_at(peer).x, (EntitySnapshots.PEER_STALE_MS - DELAY) / 1000.0 * 64.0, 0.001)


func test_stationary_entity_does_not_drift():
	var entity := _entity_with([
		[1000.0, Vector2(50, 50), Vector2.ZERO],
		[2000.0, Vector2(50, 50), Vector2.ZERO],
	])
	assert_eq(_at(entity), Vector2(50, 50))


func test_zero_length_snapshot_span_does_not_divide_by_zero():
	var entity := _entity_with([
		[9900.0, Vector2(0, 0), Vector2.ZERO],
		[9900.0, Vector2(10, 0), Vector2.ZERO],
	])
	var position := _at(entity)
	assert_false(is_nan(position.x), "no NaN from a zero-length span")


func test_outside_the_viewport_an_entity_parks_at_its_last_sent_position():
	# The server sends no movement for anything past ten tiles of the
	# player, so extrapolating it walks a ghost: both references freeze it.
	var entity := _entity_with([[9000.0, Vector2(0, 0), Vector2(1, 0)]])
	var far := Vector2(EntitySnapshots.VIEWPORT_FREEZE_PX + 20.0, 0)
	assert_eq(EntitySnapshots.render_position(entity, now, far), Vector2(0, 0), "parked")
	var near := Vector2(EntitySnapshots.VIEWPORT_FREEZE_PX - 20.0, 0)
	assert_almost_eq(EntitySnapshots.render_position(entity, now, near).x, 57.6, 0.001, "walking")


# -- the buffer ---------------------------------------------------------------

func test_snapshots_are_kept_for_the_retention_window():
	var entity := _entity_with([])
	for i in 20:
		EntitySnapshots.push(entity, Vector2(i, 0), Vector2.ZERO, now + i * 50)
	now += 19 * 50
	var oldest: float = entity["snaps"][0]["t"]
	assert_true(oldest >= now - EntitySnapshots.RETAIN_MS, "nothing older than the window")
	assert_true(entity["snaps"].size() >= 8, "and everything inside it: %d" % entity["snaps"].size())


func test_at_least_two_snapshots_survive_however_old():
	var entity := _entity_with([])
	EntitySnapshots.push(entity, Vector2(0, 0), Vector2.ZERO, 1000)
	EntitySnapshots.push(entity, Vector2(1, 0), Vector2.ZERO, 1010)
	EntitySnapshots.push(entity, Vector2(2, 0), Vector2.ZERO, 99_000)
	assert_eq(entity["snaps"].size(), 2)


func test_two_samples_for_the_same_tick_collapse_into_one():
	# A LoadPacket and a move for the same tick land in the same frame; the
	# web client folds anything within 8ms into the last sample.
	var entity := _entity_with([])
	EntitySnapshots.push(entity, Vector2(0, 0), Vector2.ZERO, now)
	EntitySnapshots.push(entity, Vector2(3, 0), Vector2(1, 0), now + 3)
	assert_eq(entity["snaps"].size(), 1)
	assert_eq(entity["snaps"][0]["pos"], Vector2(3, 0), "the newer one wins")
	assert_eq(entity["snaps"][0]["vel"], Vector2(1, 0))


# -- corrections ------------------------------------------------------------------

func test_a_correction_leaves_the_sprite_where_it_was_drawn_that_frame():
	# Extrapolated 6.4px along; the server says it only got to 2. The
	# drawn point must not jump back on the frame the packet lands.
	var entity := _entity_with([[9800.0, Vector2(0, 0), Vector2(1, 0)]])
	var drawn_before := _at(entity)
	assert_almost_eq(drawn_before.x, 6.4, 0.001)
	EntitySnapshots.push(entity, Vector2(2, 0), Vector2(1, 0), now)
	assert_almost_eq(_at(entity).x, drawn_before.x, 0.001, "same place on the same frame")


func test_a_correction_closes_at_a_fiftieth_of_a_second():
	# Drawn 6.4px along; the server says it never moved. The offset closes
	# at the native client's rate -- the whole gap in 50ms, so a third of
	# it each 60Hz frame -- and is dropped once it is under a third of a
	# pixel, so a residual never lingers.
	var entity := _entity_with([[9800.0, Vector2(0, 0), Vector2(1, 0)]])
	_at(entity)
	EntitySnapshots.push(entity, Vector2(0, 0), Vector2.ZERO, now)
	now += 16
	assert_almost_eq(_at(entity).x, 6.4 - 6.4 / 0.05 * 0.016, 0.001, "a 16ms step of the gap-in-50ms speed")
	var last := _at(entity).x
	for frame in 11:
		now += 16
		var x := _at(entity).x
		assert_true(x < last or x == 0.0, "still shrinking on frame %d" % frame)
		last = x
	assert_eq(last, 0.0, "gone within a fifth of a second")


func test_a_large_correction_glides_rather_than_teleports():
	# The native client caps the catch-up at 256 px/s: a two-tile gap takes
	# a quarter of a second, not one frame.
	var entity := _entity_with([[float(now), Vector2(0, 0), Vector2.ZERO]])
	_at(entity)
	EntitySnapshots.push(entity, Vector2(64, 0), Vector2.ZERO, now)
	now += 100
	var x := _at(entity).x
	assert_almost_eq(x, 64.0 - (64.0 - 25.6), 0.5, "a tenth of a second at 256 px/s")


func test_a_teleport_is_drawn_outright():
	var entity := _entity_with([[float(now), Vector2(0, 0), Vector2.ZERO]])
	_at(entity)
	EntitySnapshots.push(entity, Vector2(0, 400), Vector2.ZERO, now)
	assert_eq(_at(entity), Vector2(0, 400), "past five tiles there is nothing to ease")


func test_a_correction_is_not_applied_twice_in_one_frame():
	# The renderer, the overlay and the trackers all ask for the position in
	# the same frame; the close must step once per clock reading.
	var entity := _entity_with([[9800.0, Vector2(0, 0), Vector2(1, 0)]])
	_at(entity)
	EntitySnapshots.push(entity, Vector2(2, 0), Vector2.ZERO, now)
	now += 16
	var first := _at(entity)
	assert_eq(_at(entity), first)
	assert_eq(_at(entity), first)


func test_the_registry_gates_on_the_local_player():
	state.local.id = 1
	state.local.position = Vector2.ZERO
	state.apply_packet("LoadPacket", {"enemies": [WireHelper.enemy(2, 42,
		Vector2(EntitySnapshots.VIEWPORT_FREEZE_PX + 100.0, 0))]})
	state.entities.enemies[2]["snaps"][0]["vel"] = Vector2(1, 0)
	now += 1000
	assert_eq(state.entities.render_position(state.entities.enemies[2]).x,
		EntitySnapshots.VIEWPORT_FREEZE_PX + 100.0, "far from us: parked")
