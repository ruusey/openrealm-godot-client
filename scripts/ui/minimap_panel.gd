class_name MinimapPanel
extends CanvasLayer

## The realm from above, top right: the web client's minimap-canvas, at the
## native client's 200 pixels.
##
## The wheel zooms, a dot under the cursor is named, and a click on a
## named dot sends `/tp <name>` -- which the server allows only to a player
## neither hidden nor in stasis, and says so on the wire, so a dot that
## would be refused is greyed and ignored. M hides it. In an admin's hop
## mode -- /hop in the chat, answered "Hop mode: ON" -- a click anywhere
## sends `/hop x y` with the world point under it instead, and a HOP badge
## says so, as both references do.

const SIDE := MinimapCanvas.SIDE
const MARGIN := 10.0
## The web client's 8px hit radius, squared.
const HOVER_RADIUS_SQ := 64.0
const BACKGROUND := Color("#0a080c")

var state: RealmState
var chat: ChatActions
var shown := true
var zoom := MinimapView.MAX_ZOOM
## The player under the cursor, if any: what a click would teleport to.
var hovered := {}

var _root: Control
var _canvas: MinimapCanvas
var _sized_for := Vector2i.ZERO
var _mouse := Vector2(-1.0, -1.0)


func setup(realm_state: RealmState, chat_actions: ChatActions) -> void:
	state = realm_state
	chat = chat_actions


func _ready() -> void:
	layer = 11
	visible = false
	_root = ColorRect.new()
	_root.color = BACKGROUND
	_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.offset_left = -SIDE - MARGIN
	_root.offset_right = -MARGIN
	_root.offset_top = MARGIN
	_root.offset_bottom = MARGIN + SIDE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	_root.mouse_exited.connect(func() -> void: _mouse = Vector2(-1.0, -1.0))
	add_child(_root)

	_canvas = MinimapCanvas.new()
	_canvas.state = state
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_canvas)


func _process(_delta: float) -> void:
	visible = state != null and shown and state.local.is_present() and state.minimap.image != null
	if not visible:
		return
	var map_size := Vector2i(state.minimap.width, state.minimap.height)
	# A new map starts at the zoom that shows it best, not the one the last
	# map was left at.
	if map_size != _sized_for:
		zoom = MinimapView.initial_zoom(map_size)
		_sized_for = map_size
	_canvas.window = MinimapView.window(map_size, zoom, state.local.render_position() / MinimapView.TILE)
	hovered = player_under(_mouse)
	_canvas.hovered = hovered
	_canvas.queue_redraw()


## The other player nearest the point, within the hit radius -- never
## ourselves, who are not a destination.
func player_under(point: Vector2) -> Dictionary:
	var best := {}
	var best_distance := HOVER_RADIUS_SQ
	for player in state.minimap.players:
		if int(player["id"]) == state.local.id:
			continue
		var distance: float = MinimapView.to_panel(player["position"], _canvas.window, SIDE) \
			.distance_squared_to(point)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


## Sends the teleport, and says whether it did.
func teleport_to_hovered() -> bool:
	if hovered.is_empty() or not hovered["teleportable"] or chat == null:
		return false
	return chat.say("/tp %s" % hovered["name"])


## Sends `/hop x y` for the world point under `point`, whole pixels as the
## web client rounds them, and says whether it did.
func hop_to(point: Vector2) -> bool:
	if chat == null:
		return false
	var world := MinimapView.to_world(point, _canvas.window, SIDE).round()
	return chat.say("/hop %d %d" % [int(world.x), int(world.y)])


func _click() -> void:
	if state.minimap.hop:
		hop_to(_mouse)
	else:
		teleport_to_hovered()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: zoom = MinimapView.step(zoom, -1)
			MOUSE_BUTTON_WHEEL_DOWN: zoom = MinimapView.step(zoom, 1)
			MOUSE_BUTTON_LEFT: _click()


## A click on the map is a look at it, not a shot at the world behind it.
func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


func toggle() -> void:
	shown = not shown


## A key the chat line consumed never arrives here, so no gate is needed
## against typing an m. The key is the toggle_minimap action, M by default.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("toggle_minimap"):
		toggle()
