extends SceneTree

## What the particles cost: the same hundred bullets with no trail, a tar
## trail, a spark trail, and the pool at its cap, each sampled for a few
## seconds with vsync off. No server: the state is stepped here.
##
##   godot --path . --resolution 1280x720 --script tests/visual/bench_particles.gd

const SECONDS := 4.0
const BULLETS := 100
const PLAIN := 87
const TAR := 1019      # rate 22, 1150ms: ~2500 live particles from a hundred
const SPARK := 1020    # rate 40, 320ms: ~1300
const FRAME := 1.0 / 60.0

var state: RealmState
var renderer: WorldRenderer
var group := PLAIN
var next_id := 1000


func _init() -> void:
	var config := ClientConfig.new()
	var content := GameData.new()
	if not await content.load_from(FileContentSource.new(config.resolved_data_root())):
		push_error("content load failed"); quit(1); return
	state = RealmState.new(content)
	VisualScenarios.apply("entities", state)
	renderer = WorldRenderer.new()
	renderer.setup(state, content)
	root.add_child(renderer)
	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position = state.local.centre()
	root.add_child(camera)
	await process_frame
	camera.make_current()
	# Uncapped too, or the project's 240 fps limit is all this would measure.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_frame.connect(_tick)

	for phase in [["no trail", PLAIN], ["tar trail", TAR], ["spark trail", SPARK]]:
		group = phase[1]
		state.projectiles.clear()
		state.particles.clear()
		await _settle(1.5)
		var s: Dictionary = await FrameSampler.sample(self, SECONDS, renderer)
		print("%s   particles live %d drawn %d" % [FrameSampler.describe(phase[0], s), state.particles.count, renderer.particles.drawn])

	group = PLAIN
	state.projectiles.clear()
	state.particles.clear()
	for i in ParticleField.CAP:
		state.particles.spawn(state.local.centre() + Vector2(randf() - 0.5, randf() - 0.5) * 300.0,
			Vector2.ZERO, 3600.0, 8.0, 8.0, Color.WHITE)
	await _settle(0.5)
	var full: Dictionary = await FrameSampler.sample(self, SECONDS, renderer)
	print("%s   particles live %d drawn %d" % [FrameSampler.describe("pool at cap", full), state.particles.count, renderer.particles.drawn])
	quit(0)


## Keeps a hundred bullets flying in a ring around the player, replacing
## each as it expires, and steps the state as the client would.
func _tick() -> void:
	while state.projectiles.bullets.size() < BULLETS:
		var angle := randf() * TAU
		state.projectiles.bullets[next_id] = Projectile.from_wire({"id": next_id, "projectileId": group,
			"size": 16, "pos": {"x": state.local.centre().x, "y": state.local.centre().y}, "angle": angle,
			"magnitude": 3.0, "range": 240.0, "flags": [], "invert": false, "timeStep": 0, "amplitude": 0,
			"frequency": 0, "orbitCenterX": 0.0, "orbitCenterY": 0.0, "orbitRadius": 0.0, "orbitPhase": 0.0,
			"damage": 1, "createdTime": Time.get_ticks_msec()}, Time.get_ticks_msec())
		next_id += 1
	state.advance(FRAME, Vector2.ZERO, 0.0)


func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
