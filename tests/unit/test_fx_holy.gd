extends GutTest

## The holy effects -- heal, cleanse, smite, bloom, dome, beam, aura: their
## shapes' numbers, spelled out from the web client's cases, and that each
## draws without error through the real renderer.

var state: RealmState
var renderer: WorldRenderer

const HOLY := [EffectType.HEAL_RADIUS, EffectType.WATER_FOUNTAIN, EffectType.SMITE_FLASH,
	EffectType.INSPIRE_BLOOM, EffectType.SANCTUARY_DOME, EffectType.DIVINE_BEAM, EffectType.FORTIFY_AURA]


func before_each():
	state = RealmState.new(null, func() -> int: return 500)
	renderer = WorldRenderer.new()
	renderer.setup(state, GameData.new())
	add_child_autofree(renderer)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()


func _cast(kind: int, at := Vector2.ZERO, radius := 40.0, target := Vector2(30, 10), tier := 2) -> void:
	state.apply_packet("CreateEffectPacket", {"effectType": kind, "posX": at.x, "posY": at.y,
		"radius": radius, "duration": 1000, "targetPosX": target.x, "targetPosY": target.y,
		"tier": tier, "ownerId": 1})


func test_each_holy_type_has_a_drawer():
	for kind in HOLY:
		assert_true(Fx.for_type(kind).is_valid(), "type %d" % kind)


func test_every_holy_drawer_draws_through_the_renderer():
	# Seven types at five points of their lives (the clock reads 500, the
	# duration is 1000), and each once more with no radius at all. A runtime
	# error inside a drawer does NOT shorten the count -- the call returns and
	# the renderer carries on -- it shows as a SCRIPT ERROR, which
	# run-tests.sh fails the run on (checked by breaking each drawer).
	for kind in HOLY:
		for progress in [0.0, 0.1, 0.2, 0.5, 0.95]:
			_cast(kind, Vector2(5, 5), 48.0)
			state.abilities.effects[-1]["started"] = 500 - int(progress * 1000.0)
		_cast(kind, Vector2.ZERO, 0.0)
		state.abilities.effects[-1]["started"] = 450
	renderer.queue_redraw()
	await wait_process_frames(2)
	assert_eq(renderer.draw_stats["effects"], 42)


func test_the_heal_bursts_out_by_a_quarter_and_its_motes_rise():
	assert_eq(FxHealRadius.burst_radius(80.0, 0.0), 0.0)
	assert_eq(FxHealRadius.burst_radius(80.0, 0.0625), 40.0, "sqrt of a quarter of the way to full")
	assert_eq(FxHealRadius.burst_radius(80.0, 0.5), 80.0, "full by 25% and held")
	var m := FxHealRadius.mote(Vector2.ZERO, 100.0, 0, 500)
	assert_almost_eq(m.z, 0.45, 0.0001, "0.0009 a ms")
	assert_almost_eq(Vector2(m.x, m.y), Vector2(20.0, -22.5), Vector2(0.001, 0.001),
		"the first mote on the +x spoke at 0.2 radius, lifted 0.45 of half the radius")
	var second := FxHealRadius.mote(Vector2.ZERO, 100.0, 1, 500)
	assert_almost_eq(Vector3(second.x, second.y, second.z), Vector3(17.8401, -38.7, 0.98), Vector3(0.001, 0.001, 0.001),
		"seed 0.53: 0.206 radius out on the 30 degree spoke, 0.98 of the way up")


func test_the_cleanse_grows_to_its_range_and_its_streams_arc():
	assert_eq(FxWaterFountain.base_radius(100.0, 0.0), 70.0)
	assert_almost_eq(FxWaterFountain.base_radius(100.0, 0.2), 88.0, 0.001)
	assert_eq(FxWaterFountain.base_radius(100.0, 0.5), 100.0)
	assert_eq(FxWaterFountain.stream_point(100.0, 0.0, 0.0), Vector2(0.0, 0.0), "leaves from the centre")
	assert_almost_eq(FxWaterFountain.stream_point(100.0, 0.0, 0.5), Vector2(47.5, -55.0), Vector2(0.001, 0.001),
		"halfway out, at the top of its arc")
	assert_almost_eq(FxWaterFountain.stream_point(100.0, 0.0, 1.0), Vector2(95.0, 0.0), Vector2(0.001, 0.001),
		"lands at 0.95 of the boundary")


func test_the_smite_is_a_cross_over_diagonal_cracks():
	assert_eq(FxSmiteFlash.arms(40.0), Vector3(18.0, 24.0, 4.0))
	var ends := FxSmiteFlash.crack(Vector2.ZERO, 40.0, 0)
	assert_eq(ends.size(), 2)
	assert_almost_eq(ends[0], Vector2(16.9706, 16.9706), Vector2(0.001, 0.001), "0.6 of the radius, down-right")
	assert_almost_eq(ends[1], Vector2(31.1127, 31.1127), Vector2(0.001, 0.001), "out to 1.1")


func test_the_bloom_opens_and_turns_an_eighth():
	assert_almost_eq(FxInspireBloom.reach(100.0, 0.0), 55.0, 0.001)
	assert_almost_eq(FxInspireBloom.reach(100.0, 1.0), 110.0, 0.001)
	assert_almost_eq(FxInspireBloom.petal(Vector2.ZERO, 110.0, 0, 0.0), Vector2(55.0, 0.0), Vector2(0.001, 0.001))
	assert_almost_eq(FxInspireBloom.petal(Vector2.ZERO, 110.0, 0, 1.0), Vector2(38.8909, 38.8909), Vector2(0.001, 0.001))


func test_the_dome_pillars_stand_inside_the_rim_and_breathe():
	assert_almost_eq(FxSanctuaryDome.pillar_height(100.0, 0, 0), 29.4, 0.001, "0.7 of 0.42 radius")
	assert_almost_eq(FxSanctuaryDome.pillar_height(100.0, 0, 314), 42.0, 0.001, "and all of it at the crest")
	assert_almost_eq(FxSanctuaryDome.pillar_base(Vector2.ZERO, 100.0, 2, 0), Vector2(0.0, 92.0), Vector2(0.001, 0.001))


func test_the_beam_is_taller_than_wide_and_never_thin():
	assert_almost_eq(FxDivineBeam.beam_height(40.0), 88.0, 0.001)
	assert_almost_eq(FxDivineBeam.beam_width(40.0), 14.0, 0.001)
	assert_eq(FxDivineBeam.beam_width(10.0), 6.0, "the web's 12px floor, halved")
	var s := FxDivineBeam.sparkle(Vector2.ZERO, 100.0, 0, 0.5)
	assert_almost_eq(Vector3(s.x, s.y, s.z), Vector3(25.0, -35.0, 0.5), Vector3(0.001, 0.001, 0.001))


func test_the_aura_shades_green_to_blue():
	assert_eq(FxFortifyAura.band_colour(0.0), Color8(0x22, 0xff, 0x66), "green at the core")
	assert_eq(FxFortifyAura.band_colour(1.0), Color8(0x26, 0x73, 0xff), "blue at the rim")
	assert_eq(FxFortifyAura.band_colour(0.5), Color8(36, 185, 179), "rounded halfway")
	assert_eq(FxFortifyAura.ring_colour(0.0), Color8(0x38, 0xff, 0x66))
	assert_almost_eq(FxFortifyAura.ring_phase(1, 0), 0.3333, 0.001, "the rings a third apart")
	assert_almost_eq(FxFortifyAura.ring_phase(0, 1000), 0.9, 0.001)
