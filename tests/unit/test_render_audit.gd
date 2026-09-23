extends GutTest

## Nothing the player cannot see does work: the whole client, at the
## sign-in screen and then in a realm, audited by RenderAudit.
##
## The sign-in hall once simulated its torches for the whole session behind
## the game (999f80a). A hidden layer draws nothing, so no draw-call count
## could have caught that; what catches it is the rule it broke -- nothing
## under a hidden layer processes -- checked over every screen at once, so
## the next screen to leave something running fails here too.

const MainScript := preload("res://scripts/app/main.gd")

var main: Node
var transport: FakeTransport


func before_each():
	transport = FakeTransport.new()
	var config := ClientConfig.new()
	config.data_root = ProjectSettings.globalize_path("res://tests/fixtures/datadir")
	config.autoconnect = false
	main = Node.new()
	main.set_script(MainScript)
	main.config = config
	add_child_autofree(main)


func _enter_realm() -> void:
	main.client.connection.transport = transport
	main.session.begin("a@b.c", "pw", "char-1")
	transport.become_connected()
	main.client._process(0.0)
	transport.deliver(WireHelper.login_response(99, 2, Vector2(320, 640)))
	main.client._process(0.0)


func test_at_the_sign_in_screen_no_hidden_panel_is_busy():
	await wait_process_frames(3)
	assert_eq(RenderAudit.hidden_work(main), PackedStringArray(),
		"every game panel is hidden here; its parts must be idle")
	assert_true(RenderAudit.visible_by_layer(main).has("LoginScreen"))


func test_in_a_realm_nothing_of_the_sign_in_screen_runs_or_draws():
	_enter_realm()
	assert_true(main.client.is_in_game(), "the fake session got in")
	await wait_process_frames(3)
	assert_eq(RenderAudit.hidden_work(main), PackedStringArray(),
		"the sign-in hall, the loading cover and the shut panels do nothing behind the game")
	var drawn := RenderAudit.visible_by_layer(main)
	assert_false(drawn.has("LoginScreen"), "the sign-in screen draws nothing in a realm")
	assert_false(drawn.has("LoadingScreen"), "nor does the loading cover")
	assert_true(drawn.has("WorldRenderer"), "the world does")


func test_the_cover_between_realms_draws_while_up_and_leaves_nothing_behind():
	_enter_realm()
	var now := [100000]
	main.screens.transition.clock = func() -> int: return now[0]
	main.state.begin_transition(0.5)
	await wait_process_frames(3)
	assert_true(RenderAudit.visible_by_layer(main).has("TransitionScreen"), "up while we travel")
	assert_eq(RenderAudit.hidden_work(main), PackedStringArray(), "the walker is the layer's own work")
	main.state.apply_packet("LoadMapPacket", {"realmId": 3, "mapId": 31, "tiles": []})
	await wait_process_frames(2)
	now[0] += 3000   # past the two-second hold and the fade
	await wait_process_frames(3)
	assert_false(RenderAudit.visible_by_layer(main).has("TransitionScreen"), "gone once we have landed")
	assert_eq(RenderAudit.hidden_work(main), PackedStringArray(), "and nothing of it left running")


func test_a_busy_node_under_a_hidden_layer_is_named():
	var layer := CanvasLayer.new()
	layer.name = "Shut"
	var ticker := Node2D.new()
	ticker.name = "Ticker"
	ticker.set_script(load("res://tests/support/busy_node.gd"))
	layer.add_child(ticker)
	var host := Node.new()
	host.add_child(layer)
	add_child_autofree(host)
	await wait_process_frames(1)
	assert_eq(RenderAudit.hidden_work(host), PackedStringArray(), "shown, it may work")
	layer.visible = false
	var found := RenderAudit.hidden_work(host)
	assert_eq(found.size(), 1)
	assert_eq(found[0], "Shut/Ticker (Node2D)")
	ticker.set_process(false)
	assert_eq(RenderAudit.hidden_work(host), PackedStringArray(), "stopped, it is fine")


func test_a_built_in_node_running_under_a_hidden_layer_is_named():
	# A Timer has no script to process; the engine steps it internally, and
	# is_processing() never says so.
	var layer := CanvasLayer.new()
	layer.name = "Shut"
	var clock := Timer.new()
	clock.name = "Clock"
	clock.autostart = true
	layer.add_child(clock)
	var host := Node.new()
	host.add_child(layer)
	add_child_autofree(host)
	await wait_process_frames(1)
	assert_false(clock.is_processing(), "nothing a script-only check would see")
	layer.visible = false
	assert_eq(RenderAudit.hidden_work(host), PackedStringArray(["Shut/Clock (Timer)"]))
	clock.stop()
	assert_eq(RenderAudit.hidden_work(host), PackedStringArray(), "stopped, it is fine")


func test_a_hidden_layer_may_poll_itself():
	var layer := CanvasLayer.new()
	layer.set_script(load("res://tests/support/busy_layer.gd"))
	layer.visible = false
	var host := Node.new()
	host.add_child(layer)
	add_child_autofree(host)
	await wait_process_frames(1)
	assert_true(layer.is_processing())
	assert_eq(RenderAudit.hidden_work(host), PackedStringArray(),
		"a panel's own layer polls to decide whether to show")
	assert_eq(RenderAudit.visible_by_layer(host), {}, "and a hidden layer draws nothing")


func test_the_frame_counts_read_zero_headless_where_nothing_draws():
	# The unit suite runs headless; a live, windowed run is where they count.
	assert_eq(FrameCounts.draw_calls(), 0)
	assert_eq(FrameCounts.objects(), 0)
	assert_eq(FrameCounts.primitives(), 0)
	assert_eq(FrameCounts.draw_calls(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "the monitor's counter")
