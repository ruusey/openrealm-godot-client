extends SceneTree

## Renders scenarios and writes a PNG of each.
##
## Must run WITHOUT --headless: the headless display driver has no rendering
## device, so the viewport texture comes back null. A real window is required
## even though nothing interactive happens in it.
##
##   godot --path . --script tests/visual/capture.gd -- <scenario> <out.png>
##   godot --path . --script tests/visual/capture.gd -- --all <out_dir> <scenario>...
##
## The second form is what capture-visuals.sh uses: one process and one window
## for the whole run, so the desktop is interrupted once rather than once a
## scenario. Each scenario is built under a stage of its own, captured, and
## freed before the next; the content is loaded once and only read.

const CAMERA_ZOOM := 2.0
const SETTLE_FRAMES := 6
## Arbitrary, but fixed -- see the clock note below.
const CAPTURE_TIME_MS := 250


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = []
	if args.size() > 0 and args[0] == "--all":
		for scenario in args.slice(2):
			jobs.append([scenario, "%s/%s.png" % [args[1], scenario]])
	else:
		var scenario: String = args[0] if args.size() > 0 else "entities"
		jobs.append([scenario, args[1] if args.size() > 1 else "reports/visual/%s.png" % scenario])

	var config := ClientConfig.new()
	var content := GameData.new()
	if not await content.load_from(FileContentSource.new(config.resolved_data_root())):
		push_error("content load failed: %s" % "\n".join(content.errors))
		quit(1)
		return

	var failed := 0
	for job in jobs:
		if not await capture(job[0], job[1], content):
			failed += 1
	quit(1 if failed > 0 else 0)


## One scenario, built under a stage of its own so the next starts clean.
func capture(scenario: String, output: String, content: GameData) -> bool:
	var stage := Node.new()
	root.add_child(stage)
	var state := RealmState.new(content, func() -> int: return 0)
	state.party.wall_clock = func() -> int: return VisualScenarios.PARTY_WALL_MS
	VisualScenarios.apply(scenario, state)

	var renderer := WorldRenderer.new()
	renderer.setup(state, content)
	# Spin is a function of the wall clock, so a spinning group would render
	# differently on every capture. Pin it, as RealmState's clock already is.
	# Non-zero, or a spin scenario would have nothing to show.
	renderer.bullets.clock = func() -> int: return CAPTURE_TIME_MS
	renderer.show_collision = scenario == "collision"
	stage.add_child(renderer)

	# The names, bars, chips, bubbles and numbers: UI over the world.
	var tags := EntityOverlay.new()
	tags.setup(state, content)
	stage.add_child(tags)

	var chat := ChatPanel.new()
	chat.setup(state)
	stage.add_child(chat)

	# Invisible unless the scenario asked to leave a realm, so every other
	# capture is unaffected -- and the transition scenario shows what the
	# player actually sees during one.
	var splash := TransitionScreen.new()
	splash.setup(state, content)
	# Pinned like the bullet layer's, and for the same reason: a fade driven
	# by the frame delta lands on a different alpha every capture.
	splash.clock = func() -> int: return CAPTURE_TIME_MS
	stage.add_child(splash)

	# Driven by the session rather than by world state, so the scenario cannot
	# raise it and the capture has to.
	var grave := DeathScreen.new()
	stage.add_child(grave)

	# Up whenever there is a local player, as in the client -- which is most
	# scenarios -- so it is asked for by name instead, the way the collision
	# overlay is, and every other capture is unchanged.
	var bag := InventoryPanel.new()
	bag.setup(state, content, InventoryActions.new(state, null, content))
	bag.shown = scenario in ["inventory", "item_card"]
	stage.add_child(bag)
	var bar := AbilityBar.new()
	bar.setup(state, content, null)
	bar.shown = scenario == "abilities"
	stage.add_child(bar)
	# Open only when the scenario's packets opened them, and the prompt only
	# when a scenario laid an interactive tile in reach.
	var shop := ShopActions.new(state, null, content)
	var shelves := ItemStorePanel.new()
	shelves.setup(state, content, null, shop)
	stage.add_child(shelves)
	var fame := FameStorePanel.new()
	fame.setup(state, content, shop)
	stage.add_child(fame)
	var prompt := InteractPrompt.new()
	prompt.setup(state, shop)
	stage.add_child(prompt)
	var forge := ForgePanel.new()
	forge.setup(state, content, ForgeActions.new(state, null, content))
	stage.add_child(forge)
	var market := ExchangeMarketPanel.new()
	market.setup(state, content, shop)
	stage.add_child(market)
	var trade := TradePanel.new()
	trade.setup(state, content, TradeActions.new(state, null))
	stage.add_child(trade)
	var party := PartyPanel.new()
	party.setup(state, content, PartyActions.new(state, null))
	stage.add_child(party)
	var invite := PartyInvitePopup.new()
	invite.setup(state, PartyActions.new(state, null))
	stage.add_child(invite)
	var dev := DevOverlay.new()
	stage.add_child(dev)
	# Only asked for by name: its chip would otherwise be up in every scenario
	# with a player, and move every golden that has one.
	if scenario == "quests":
		var log := QuestLogPanel.new()
		log.setup(state, content, null)
		log.shown = true
		stage.add_child(log)
	var masteries := MasteryPanel.new()
	masteries.setup(state)
	masteries.shown = scenario == "masteries"
	stage.add_child(masteries)
	var options := OptionsPanel.new()
	options.setup(state.settings, null)
	stage.add_child(options)
	var nearby := NearbyPanel.new()
	nearby.setup(state, content, TradeActions.new(state, null), PartyActions.new(state, null), null, party)
	nearby.shown = scenario == "nearby"
	stage.add_child(nearby)
	# Named after the map, so it would be up in every scenario that has a
	# player; asked for by name instead, like the bag and the bar.
	var banner := RealmBanner.new()
	banner.setup(state, content)
	banner.shown = scenario == "portals"
	stage.add_child(banner)
	# Up whenever there is a player, and asked for by name like the bag.
	var hud := PlayerHud.new()
	hud.setup(state, content)
	hud.shown = scenario == "player_hud"
	stage.add_child(hud)
	# Up whenever there is a map, like the bar, and asked for by name like it.
	var map := MinimapPanel.new()
	map.setup(state, null)
	map.shown = scenario in ["minimap", "minimap_hop"]
	stage.add_child(map)

	# The sign-in screen, torches burning: only for its own scenario, since
	# in the client it covers everything until a character is chosen.
	var login: LoginScreen = null
	if scenario.begins_with("login") or scenario in ["terms", "how_to", "leaderboard"]:
		login = LoginScreen.new()
		login.game_data = content
		stage.add_child(login)

	var camera := Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position = state.local.centre() if state.local.is_present() else Vector2.ZERO
	stage.add_child(camera)

	# Nothing added above has run _ready yet -- a node added from here is
	# initialised when the tree next processes it, and driving one before that
	# writes to controls that do not exist. One frame is the whole fix.
	await process_frame
	chat.refresh()
	# The pin pulses on the clock; pinned like the bullet layer's.
	map._canvas.clock = func() -> int: return CAPTURE_TIME_MS
	# The line the player types into, open and half-typed, under the log.
	if scenario == "chat_typing":
		chat._input.open()
		chat._input.text = "on my way, hold the portal"
	if scenario == "death":
		grave.fell("Ruu")
	# The card over the second cell, pinned where a cursor would be: the bar
	# otherwise follows the real mouse every frame, which no capture can fix.
	# The card over the equipped weapon, as a hover leaves it.
	if scenario == "item_card":
		bag._process(0.0)
		bag._tooltip.show_for(state.local.inventory.item_at(0), Vector2(700, 180))
		bag.set_process(false)
	if scenario == "abilities":
		bar._process(0.0)
		bar._tooltip.show_lines(bar.describe(2), Vector2(400, 620))
		bar.set_process(false)
	# Ninety frames of fire from a seeded field on a pinned clock, then the
	# backdrop stops stepping so the settle frames change nothing. Reset
	# first -- the particles and each emitter's carried fraction: the frame
	# above stepped them once with the real frame time, which is near zero in
	# a fresh process and a whole frame after other scenarios.
	if login != null:
		login._backdrop.clock = func() -> float: return CAPTURE_TIME_MS * 0.001
		login._backdrop.field.clear()
		login._backdrop._torch_acc.clear()
		login._backdrop._candle_acc.clear()
		login._backdrop.field.rng.seed = 7
		for frame in 90:
			login._backdrop.step(1.0 / 60.0)
		login._backdrop.set_process(false)
	# Signed in, the second character picked and Delete pressed once.
	if scenario == "login_delete":
		login._listed({"success": true, "characters": VisualScenarios.account()})
		login._stage.picker.list.select(1)
		login._stage.ask_delete()
	# Signed in, and the first character right-clicked: its lifetime stats.
	if scenario == "login_stats":
		login._listed({"success": true, "characters": VisualScenarios.account()})
		var card := login._stage.stats_card
		card.title.text = "Barbarian - Lifetime Stats"
		card.show_report(VisualScenarios.lifetime_report())
		card.visible = true
	# The Terms of Use as an account that has not accepted them meets them:
	# from the top, I Agree still dead.
	if scenario == "terms":
		login._terms.ask()
	# How to Play as the "?" leaves it: open at the top.
	if scenario == "how_to":
		login._how_to.open()
	# Signed in, the account's characters beside the server's best, and the
	# first row's card open where a hover would leave it.
	if scenario == "leaderboard":
		login._stage.show_account(VisualScenarios.leaderboard_characters())
		login._board.show_entries(VisualScenarios.leaderboard_entries())
		var card := LeaderboardCard.build(VisualScenarios.leaderboard_entries()[0], content)
		card.position = Vector2(860, 560)
		login.add_child(card)
	# The options as Escape leaves them. It shows only in a realm, and a
	# capture has no client, so it is raised by hand.
	if scenario.begins_with("options"):
		options.set_process(false)
		options.visible = true
	# The /dev readout, with no client to read: raised by hand on fixed numbers
	# that land one of each colour.
	if scenario == "dev_overlay":
		dev.set_process(false)
		dev.visible = true
		dev._text.text = DevOverlay.line(42.0, 38, 4, Vector2i(1280, 960), 1.0, 1620)
	# The Controls tab mid-rebind: one button waiting for its key.
	if scenario == "options_controls":
		options.controls.get_parent().current_tab = 1
		options.controls.listen("drink_hp")
	# The menu open on a player in the list, as a click would leave it.
	if scenario == "nearby":
		nearby._process(0.0)
		nearby.open_menu(state.entities.players[2])
	# The wait as the screen sees it, then whatever the scenario says happens
	# next -- a named splash is the frame AFTER the realm lands.
	splash._process(0.0)
	VisualScenarios.advance(scenario, state)
	splash._process(0.0)
	# The second step can move the player -- an arrival puts us somewhere new
	# -- and the camera follows it every frame in the real client.
	camera.position = state.local.centre() if state.local.is_present() else Vector2.ZERO

	for i in SETTLE_FRAMES:
		await process_frame
		camera.make_current()

	var image := root.get_texture().get_image()
	stage.queue_free()
	await process_frame
	if image == null:
		push_error("viewport capture returned null -- this must run windowed, not --headless")
		return false

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	var error := image.save_png(output)
	if error != OK:
		push_error("could not write %s: %s" % [output, error_string(error)])
		return false
	print("captured %s -> %s (%dx%d)" % [scenario, output, image.get_width(), image.get_height()])
	return true
