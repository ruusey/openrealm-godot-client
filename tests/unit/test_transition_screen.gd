extends GutTest

## The cover over the stretch where the client has nothing to draw.

var screen: TransitionScreen
var state: RealmState
var content: GameData


var now := 1000


func before_each():
	now = 1000
	content = GameData.new()
	await content.load_from(FileContentSource.new(
		ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(content)
	screen = TransitionScreen.new()
	screen.setup(state, content)
	screen.clock = func() -> int: return now
	add_child_autofree(screen)


func _land_in(map_id: int) -> void:
	state.apply_packet("LoadMapPacket", {"realmId": 3, "mapId": map_id, "tiles": []})


func test_nothing_is_covered_while_we_are_standing_still():
	screen._process(0.1)
	assert_false(screen.visible)


func test_the_wait_is_covered():
	state.begin_transition()
	screen._process(0.1)
	assert_true(screen.visible)
	assert_string_contains(screen._label.text, "Entering")


func test_a_slow_transition_does_not_flash():
	# The fade is driven by arrival, not by elapsed time: however long the
	# server takes, the cover stays up until the realm actually lands.
	state.begin_transition()
	for i in 10:
		now += int(TransitionScreen.FADE_SECONDS * 1000.0)
		screen._process(0.0)
	assert_true(screen.visible)
	assert_eq(screen._dim.modulate.a, 1.0)


func test_the_realm_we_are_leaving_is_never_named():
	# tiles.map_id still holds the map we came from for the whole wait, so
	# reading it there puts "Entering <the realm you just left>" on screen --
	# which the transition golden is what caught.
	_land_in(1)
	state.begin_transition()
	screen._process(0.1)
	assert_eq(screen._label.text, "Entering ...")
	assert_false(screen._label.text.contains("Nexus 0"))


func test_the_realm_is_named_once_it_lands():
	state.begin_transition()
	screen._process(0.1)
	_land_in(31)
	screen._process(0.01)
	assert_string_contains(screen._label.text, "Nexus Auru V1")


func test_the_cover_clears_after_the_realm_lands():
	# Driven by the clock rather than by frame deltas, so a scripted render
	# lands on the same alpha every time -- the bullet layer is pinned the
	# same way and for the same reason.
	state.begin_transition()
	screen._process(0.0)
	_land_in(31)
	screen._process(0.0)
	assert_eq(screen._dim.modulate.a, 1.0, "the fade starts where the cover was")

	now += int(TransitionScreen.HOLD_SECONDS * 1000.0)
	screen._process(0.0)
	assert_eq(screen._dim.modulate.a, 1.0, "held at full while the name is readable")

	now += int(TransitionScreen.FADE_SECONDS * 500.0)
	screen._process(0.0)
	assert_true(screen.visible, "still fading")
	assert_almost_eq(screen._dim.modulate.a, 0.5, 0.01)

	now += int(TransitionScreen.FADE_SECONDS * 500.0)
	screen._process(0.0)
	assert_false(screen.visible, "and gone")


func test_the_cover_is_held_long_enough_to_read():
	# The name arrives on the heels of the tiles, so without a floor it shows
	# for one frame and fades. The web client holds its splash for two
	# seconds before starting to clear, and paints the name for all of it.
	assert_eq(TransitionScreen.HOLD_SECONDS, 2.0)
	state.begin_transition()
	screen._process(0.0)
	_land_in(31)
	screen._process(0.0)
	now += int(TransitionScreen.HOLD_SECONDS * 1000.0) - 100
	screen._process(0.0)
	assert_eq(screen._dim.modulate.a, 1.0, "still whole, just before the floor runs out")


func test_a_second_wait_covers_again():
	state.begin_transition()
	screen._process(0.0)
	_land_in(31)
	# The clock starts on the first frame after arrival, not on the arrival
	# itself, so it has to be observed before the clock moves.
	screen._process(0.0)
	now += int((TransitionScreen.HOLD_SECONDS + TransitionScreen.FADE_SECONDS) * 1000.0)
	screen._process(0.0)
	assert_false(screen.visible)

	state.begin_transition()
	screen._process(0.0)
	assert_true(screen.visible, "covered again")
	assert_eq(screen._dim.modulate.a, 1.0)

	# And the fade itself starts over. Without that, the second arrival
	# measures against the first transition's clock and the cover does not
	# fade at all -- it vanishes on the frame after the tiles land.
	_land_in(2)
	screen._process(0.0)
	now += int(TransitionScreen.HOLD_SECONDS * 1000.0 + TransitionScreen.FADE_SECONDS * 500.0)
	screen._process(0.0)
	assert_true(screen.visible, "still on screen halfway through the fade")
	assert_almost_eq(screen._dim.modulate.a, 0.5, 0.01)


func test_the_caption_names_the_map_without_its_underscores():
	assert_eq(TransitionScreen.caption(""), "Entering ...",
		"the destination is unknown until we are standing in it")
	assert_eq(TransitionScreen.caption("Nexus_Auru_V1"), "Entering Nexus Auru V1")


func test_the_fade_is_the_length_it_says_it_is():
	# The test below steps by the constant, so it holds at any value.
	assert_eq(TransitionScreen.FADE_SECONDS, 0.35)


func test_it_does_nothing_without_a_state():
	# Starts visible, so "not covering" is something the guard has to DO. An
	# assertion that it stays hidden would pass just as well on the runtime
	# error a missing guard throws -- GUT counts an errored test as passing.
	var bare := TransitionScreen.new()
	add_child_autofree(bare)
	bare.visible = true
	bare._process(0.1)
	assert_false(bare.visible)


func test_the_class_walks_at_its_own_pace_and_the_portals_difficulty_shows():
	state.local.id = 1
	state.local.class_id = 0
	state.local.stats = {"spd": 0}
	state.begin_transition(3.4)
	screen._process(0.1)
	assert_not_null(screen._sprite.texture, "the class's walk, not a blank")
	var first: AtlasTexture = screen._sprite.texture
	# spd 0: (4 tiles/s * 32 px) -> a leg swap every 24000 / 128 = 187.5 ms.
	assert_almost_eq(TransitionArt.frame_ms(0), 187.5, 0.001)
	assert_almost_eq(TransitionArt.frame_ms(75), 24000.0 / (9.6 * 32.0), 0.001, "faster at full speed")
	now += 190
	screen._process(0.1)
	assert_ne(screen._sprite.texture.region, first.region, "a frame later, the next step")
	assert_eq(TransitionArt.facing(content, 0), "side", "the fixture's class walks only side-on")
	assert_eq(TransitionArt.facing(content, 9), "front", "and one with no walk at all asks for the front")
	assert_true(screen._pips.visible)
	var lit := screen._pips.get_children().filter(func(p: ColorRect) -> bool: return p.color == TransitionArt.LIT)
	assert_eq(lit.size(), 3, "3.4 rounds to three of seven")
	assert_eq(screen._difficulty.text, "Difficulty 3.4")


func test_no_portal_no_difficulty():
	state.local.id = 1
	state.begin_transition()
	screen._process(0.1)
	assert_false(screen._pips.visible, "the nexus and the vault come with none")
	assert_eq(screen._difficulty.text, "")
	assert_eq(TransitionArt.lit_pips(9.0), 7, "never more than the row")
	assert_eq(TransitionArt.lit_pips(3.6), 4, "rounded, as the web rounds it, not cut")
