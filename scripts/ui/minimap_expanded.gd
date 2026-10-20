class_name MinimapExpanded
extends CanvasLayer

## The phone's map opened up: a tap on the corner map spreads it over the
## screen, where a finger drags it, two pinch it, and - / + / Me / Close sit
## beside it. Tapping a player names them; tapping them again teleports, so
## a stray tap while panning never sends anyone anywhere. In hop mode a tap
## hops, as a click does on the corner map.

const MARGIN := 10.0
const BUTTON_SIZE := Vector2(64.0, 40.0)
const FONT_SIZE := 15
const DIM := Color(0.0, 0.0, 0.0, 0.7)
## A fingertip, not a cursor: generous, in panel pixels.
const TAP_RADIUS_SQ := 400.0
## Further than this and a touch was a drag, not a tap.
const TAP_SLOP := 12.0
## How much one - or + press zooms.
const BUTTON_ZOOM := 1.5

var state: RealmState
var chat: ChatActions
var zoom := MinimapView.MAX_ZOOM
## The tile the map centres on, while it is not following us.
var focus := Vector2.ZERO
var following := true
## The player a first tap named, waiting on a second to teleport.
var picked := {}

var _dim: ColorRect
var _map: ColorRect
var _canvas: MinimapCanvas
var _bar: BoxContainer
var _touches := {}
var _pinch_distance := 0.0
var _pinch_middle := Vector2.ZERO
var _press_at := Vector2.ZERO
var _dragged := false
var _mouse_down := false
var _mouse_at := Vector2.ZERO


func setup(realm_state: RealmState, chat_actions: ChatActions) -> void:
	state = realm_state
	chat = chat_actions


func _ready() -> void:
	layer = 13
	visible = false
	_dim = ColorRect.new()
	_dim.color = DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_dim)
	_map = ColorRect.new()
	_map.color = MinimapPanel.BACKGROUND
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.gui_input.connect(_on_map_input)
	add_child(_map)
	_canvas = MinimapCanvas.new()
	_canvas.state = state
	_canvas.tp_hint = "tap again to tp"
	_map.add_child(_canvas)
	_bar = BoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	add_child(_bar)
	for item in [["-", func() -> void: zoom_by(BUTTON_ZOOM)], ["+", func() -> void: zoom_by(1.0 / BUTTON_ZOOM)],
			["Me", recentre], ["Close", close]]:
		var button := TouchButtons.flat(item[0], BUTTON_SIZE, item[1])
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		_bar.add_child(button)
	TouchFrame.adopt(self)


func open(start_zoom: float) -> void:
	if state == null or state.minimap.image == null:
		return
	zoom = start_zoom
	following = true
	picked = {}
	_touches.clear()
	visible = true
	_process(0.0)


func close() -> void:
	visible = false


func recentre() -> void:
	following = true


## Shrinks (below one) or widens the window about its centre.
func zoom_by(factor: float) -> void:
	_zoom_about(zoom * factor, Vector2.ONE * _canvas.side * 0.5)


## Open, it covers the screen: every tap is the map's.
func captures_mouse() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not visible:
		return
	if state == null or state.minimap.image == null or not state.local.is_present():
		close()
		return
	_layout()
	if following:
		focus = state.local.render_position() / MinimapView.TILE
	_canvas.window = MinimapView.window(_map_size(), zoom, focus)
	_canvas.hovered = picked
	_canvas.queue_redraw()


## The map as big as the screen allows, the buttons under it held upright
## and beside it held sideways.
func _layout() -> void:
	var view := _dim.size
	_bar.vertical = view.x > view.y
	var bar := _bar.get_combined_minimum_size()
	var side: float
	var origin: Vector2
	if _bar.vertical:
		side = floorf(minf(view.y - MARGIN * 2.0, view.x - bar.x - MARGIN * 3.0))
		origin = Vector2((view.x - side - MARGIN - bar.x) * 0.5, (view.y - side) * 0.5)
		_bar.position = Vector2(origin.x + side + MARGIN, origin.y)
	else:
		side = floorf(minf(view.x - MARGIN * 2.0, view.y - bar.y - MARGIN * 3.0))
		origin = Vector2((view.x - side) * 0.5, (view.y - side - MARGIN - bar.y) * 0.5)
		_bar.position = Vector2((view.x - bar.x) * 0.5, origin.y + side + MARGIN)
	side = maxf(side, MinimapCanvas.SIDE)
	_bar.size = bar
	_map.position = origin.round()
	_map.size = Vector2(side, side)
	if _canvas.side != side:
		_canvas.resize(side)


func _map_size() -> Vector2i:
	return Vector2i(state.minimap.width, state.minimap.height)


func _zoom_about(next_zoom: float, point: Vector2) -> void:
	next_zoom = clampf(next_zoom, MinimapView.MIN_ZOOM, MinimapView.MAX_ZOOM)
	if next_zoom == zoom:
		return
	var from := _current_focus()
	focus = MinimapView.settled_focus(_map_size(), next_zoom,
		MinimapView.focus_zoomed_about(_map_size(), from, zoom, next_zoom, point, _canvas.side))
	zoom = next_zoom
	following = false


func _drag(moved: Vector2) -> void:
	focus = MinimapView.settled_focus(_map_size(), zoom,
		MinimapView.focus_dragged(_map_size(), _current_focus(), zoom, moved, _canvas.side))
	following = false


func _current_focus() -> Vector2:
	if following:
		return state.local.render_position() / MinimapView.TILE
	return focus


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_finger_drag(event)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_on_mouse(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_press_at = event.position
			_dragged = false
		else:
			_dragged = true
			_start_pinch()
		return
	_touches.erase(event.index)
	if _touches.size() >= 2:
		_start_pinch()
	elif _touches.is_empty() and not _dragged:
		_tap(event.position)


func _on_finger_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var was: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if _touches.size() == 1:
		if _dragged or event.position.distance_to(_press_at) > TAP_SLOP:
			_dragged = true
			_drag(event.position - was)
		return
	var points: Array = _touches.values()
	var middle: Vector2 = (points[0] + points[1]) * 0.5
	var distance: float = (points[0] as Vector2).distance_to(points[1])
	if _pinch_distance > 0.0 and distance > 0.0:
		_zoom_about(zoom * _pinch_distance / distance, middle)
	_drag(middle - _pinch_middle)
	_pinch_distance = distance
	_pinch_middle = middle


func _start_pinch() -> void:
	var points: Array = _touches.values()
	_pinch_middle = (points[0] + points[1]) * 0.5
	_pinch_distance = (points[0] as Vector2).distance_to(points[1])


## A real mouse (a laptop's touchscreen browser, or a test): drag, wheel, click.
func _on_mouse(event: InputEventMouse) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_about(zoom / BUTTON_ZOOM, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_about(zoom * BUTTON_ZOOM, event.position)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_mouse_down = true
					_press_at = event.position
					_mouse_at = event.position
					_dragged = false
				else:
					_mouse_down = false
					if not _dragged:
						_tap(event.position)
	elif event is InputEventMouseMotion and _mouse_down:
		if _dragged or event.position.distance_to(_press_at) > TAP_SLOP:
			_dragged = true
			_drag(event.position - _mouse_at)
		_mouse_at = event.position


func _tap(point: Vector2) -> void:
	_canvas.window = MinimapView.window(_map_size(), zoom, _current_focus())
	if state.minimap.hop:
		var world := MinimapView.to_world(point, _canvas.window, _canvas.side).round()
		if chat != null:
			chat.say("/hop %d %d" % [int(world.x), int(world.y)])
		return
	var player := MinimapView.player_at(state.minimap.players, state.local.id, point, _canvas.window,
		_canvas.side, TAP_RADIUS_SQ)
	if player.is_empty():
		picked = {}
	elif not picked.is_empty() and int(picked["id"]) == int(player["id"]) and player["teleportable"]:
		if chat != null and chat.say("/tp %s" % player["name"]):
			close()
	else:
		picked = player
