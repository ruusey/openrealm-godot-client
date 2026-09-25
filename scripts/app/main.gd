extends Node

## Entry point: builds the stack and runs the frame loop.
##
## Construction and per-frame ordering only -- the session flow lives in
## SessionController, gameplay input in PlayerInput, the realm transitions in
## PortalInput, and the screens over the world in Screens.

const CAMERA_ZOOM := DisplayScale.WORLD_ZOOM

var config: ClientConfig
var game_data: GameData
var client: OpenRealmClient
var state: RealmState
var session: SessionController
var input: PlayerInput
var portals: PortalInput
var inventory_actions: InventoryActions
var inventory_input: InventoryInput
var caster: AbilityCaster
var shop: ShopActions
var forge_actions: ForgeActions
var chat_actions: ChatActions
var ability_input: AbilityInput
var screens: Screens
var trace := MotionTrace.new()

var _world: WorldRenderer
var _camera: Camera2D
var _data_service: DataService
var _http: HttpBackend


func _ready() -> void:
	# Assigned ahead of _ready by tests; otherwise taken from the command line.
	if config == null:
		config = ClientConfig.from_command_line()
	if OS.has_feature("web"):
		_hide_web_input_caret()
	var display := DisplayScale.new()
	var mobile := OS.has_feature("web") or OS.has_feature("android")
	display.device_scale = DisplayScale.pixel_ratio(OS.has_feature("web"), JavaScriptBridge.eval,
		OS.has_feature("android"), DisplayServer.screen_get_dpi())
	add_child(display)
	# Short by the screen's own rows: a phone in landscape, or a small window.
	# Not under a headless display, whose 64-row window the unit suite shares:
	# the default is process-wide, and one Main would fold every panel after it.
	if DisplayServer.get_name() != "headless":
		PanelFold.short_screen = PanelFold.default_folded(float(get_window().size.y) / display.device_scale)

	game_data = GameData.new()
	state = RealmState.new(game_data)
	state.settings.load_from(config.settings_path)
	display.follow(state.settings)
	client = OpenRealmClient.new()
	client.connection.transport = config.open_transport()
	client.name = "OpenRealmClient"
	add_child(client)
	# Stepped from _process below, at the frame's start, not by the engine.
	client.set_process(false)

	_data_service = DataService.new()
	_data_service.base_url = ServerAddress.data_url(config)
	add_child(_data_service)
	_http = GodotHttpBackend.new(self)

	_world = WorldRenderer.new()
	_world.setup(state, game_data)
	add_child(_world)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()
	display.camera = _camera   # the world's zoom, apart from the UI's

	inventory_actions = InventoryActions.new(state, client, game_data)
	caster = AbilityCaster.new(state, client, game_data, _world)
	shop = ShopActions.new(state, client, game_data)
	inventory_actions.shop = shop
	forge_actions = ForgeActions.new(state, client, game_data)
	chat_actions = ChatActions.new(state, client)
	screens = Screens.new()
	screens.build(state, game_data, client, _data_service, inventory_actions, caster, shop,
		forge_actions, _world, chat_actions)
	add_child(screens)
	screens.death.dismissed.connect(screens.login.return_after_death)
	screens.death.quit.connect(screens.login.forget_characters.bind("Signed out."))
	screens.login.last_email.path = LastEmail.DEFAULT_PATH if config.settings_path != "" else ""
	screens.login.prefill(config.email if config.email != "" else screens.login.last_email.read(), config.password)

	session = SessionController.new(client, state, screens.login, config)
	session.entered_realm.connect(_on_entered_realm)
	session.died.connect(screens.death.fell)
	input = PlayerInput.new(state, client, _world, game_data)
	portals = PortalInput.new(state, client, game_data)
	inventory_input = InventoryInput.new(client, inventory_actions, screens.inventory)
	inventory_input.shop = shop
	ability_input = AbilityInput.new(client, caster, screens.skills)
	# A click on a panel is not a shot at, or a cast into, the world behind it.
	input.mouse_captured = screens.captures_mouse
	ability_input.mouse_captured = screens.captures_mouse
	# And a key typed into the chat line is a letter, not a move or a cast.
	for ticker in [input, portals, inventory_input, ability_input]:
		ticker.keyboard_captured = screens.captures_keyboard
	# A phone's sticks, or --touch to try them here with the mouse as a finger.
	var touchscreen := DisplayServer.is_touchscreen_available()
	screens.touch.pixel_ratio = display.device_scale if mobile else DisplayServer.screen_get_scale()
	screens.touch.enable(TouchControls.wanted(config.touch, touchscreen, OS.has_feature), not touchscreen)
	input.touch_aim = screens.touch.aim_point
	caster.aim_point = screens.touch.cast_point
	# The prompt over the bar is the phone's F and Space.
	screens.prompt.portals = portals
	screens.prompt.touch = screens.touch.enabled

	# The moment before the frame is drawn, for the motion trace: the
	# transform the world is about to be drawn with, against the player.
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_load_content()


## The web virtual keyboard rides on a transparent DOM <input> Godot overlays
## on the focused LineEdit; on a scaled canvas the browser draws that element's
## own caret offset from Godot's -- a stray marker below-left of the field.
## Make the DOM element's caret and text invisible so only Godot's own caret,
## drawn in the canvas, shows. Godot's are the only text inputs on the page.
func _hide_web_input_caret() -> void:
	JavaScriptBridge.eval("""
		(function () {
			if (document.getElementById('or-input-caret-fix')) return;
			var style = document.createElement('style');
			style.id = 'or-input-caret-fix';
			style.textContent = 'input, textarea { caret-color: transparent !important; color: transparent !important; -webkit-text-fill-color: transparent !important; }';
			document.head.appendChild(style);
		})();
	""", true)


func _on_pre_draw() -> void:
	if client.is_in_game():
		trace.sample_draw(get_viewport().get_canvas_transform(), state.local.render_centre(),
			get_viewport().get_visible_rect().size)


## Fetched rather than read, in a browser, so this cannot block the first
## frame. Everything built above holds the GameData object and reads through
## it, so the UI is already up while it fills; against the data repo on disk
## nothing suspends and it is finished before _ready returns.
func _load_content() -> void:
	var source := config.open_content_source(_http)
	if await game_data.load_from(source):
		print("[content] %s from %s" % [game_data.summary(), source.describe()])
	else:
		push_error("Content failed to load from %s:\n  %s" % [
			source.describe(), "\n  ".join(game_data.errors)])
	if not game_data.errors.is_empty():
		screens.login.set_status("Content warnings:\n  %s" % "\n  ".join(game_data.errors.slice(0, 3)), true)

	if session.can_autoconnect():
		session.begin(config.email, config.password, config.character_uuid)


## Snap rather than ease, so the first frame in a realm is already framed on
## the player instead of panning in from the origin.
func _on_entered_realm(_response: Dictionary) -> void:
	PixelSnap.camera(_camera, state.local.render_centre(), state.local.render_position())


## The character is gone from the account, so the list we hold is stale and
## the picker has to be filled again from the data service.
## The order is the frame's consistency. The network first, so every ack
## has been reconciled before prediction runs; then prediction; then the
## camera on the result, applied at once rather than at the camera's own
## step, so the world, the camera and the tags over it are drawn from one
## state. Doing the network after the camera drew the sprite up to 3px off
## the camera's centre on every correction frame.
func _process(delta: float) -> void:
	client.tick(delta)
	input.tick(delta)
	portals.tick(delta)
	inventory_input.tick(delta)
	ability_input.tick(delta)
	if client.is_in_game():
		PixelSnap.camera(_camera, state.local.render_centre(), state.local.render_position())
		trace.observe(delta, state)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			print("\n[packet mix]\n%s" % client.stats.mix())
		KEY_F2:
			_world.show_collision = not _world.show_collision
		# Tilde rather than an F key: on a Mac the F row is brightness and
		# volume unless fn is held, which is not something to do mid-fight.
		KEY_QUOTELEFT:
			var where := Screenshot.take(get_viewport())
			print("[screenshot] %s" % (where if where != "" else "nothing to capture"))
			# And the motion of the next second, which no screenshot can show.
			trace.start(state.movement.corrections)
		KEY_ESCAPE:
			if client.is_in_game():
				screens.options.toggle()
