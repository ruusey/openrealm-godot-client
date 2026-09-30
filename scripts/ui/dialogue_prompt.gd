class_name DialoguePrompt
extends CanvasLayer

## An on-screen tip shown while the local player stands inside a map's
## dialogueTrigger rect (data-driven, from maps.json). Built for the tutorial:
## a header + body that teaches the player based on where they are.
##
## Purely client-side -- the client already loads maps.json and knows the local
## player's position, so no server packet is involved. A trigger flagged `once`
## shows only the first time it's entered; the spent set resets on a map change.

const MARGIN_TOP := 40.0
const WIDTH := 520.0
const HEADER_SIZE := 18
const BODY_SIZE := 14

var state: RealmState
var content: GameData

var _panel: PanelContainer
var _header: Label
var _body: Label
var _map_id := -9999
## Indices of `once` triggers already spent this map visit.
var _spent := {}
## Index of the trigger currently displayed, or -1.
var _active := -1


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	# Above the world, alongside the realm banner (which sits at the very top).
	layer = 11
	visible = false
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = MARGIN_TOP
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	style.border_color = Color(0.5, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	top.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_header = _line(column, HEADER_SIZE, Color(1.0, 0.9, 0.55))
	_body = _line(column, BODY_SIZE, Color(0.9, 0.92, 0.98))


func _line(into: VBoxContainer, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 24.0, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(label)
	return label


func _process(_delta: float) -> void:
	if state == null or content == null or not state.local.is_present() or state.transition_pending:
		visible = false
		return
	var map_id: int = state.tiles.map_id
	if map_id != _map_id:
		_map_id = map_id
		_spent.clear()
		_active = -1
	var triggers := content.maps.triggers(map_id)
	if triggers.is_empty():
		visible = false
		_active = -1
		return
	var current := _current_trigger(triggers, state.local.render_centre())
	if current < 0:
		visible = false
		_active = -1
		return
	if current != _active:
		_active = current
		var trigger: Dictionary = triggers[current]
		if bool(trigger.get("once", false)):
			_spent[current] = true
		_header.text = String(trigger.get("header", ""))
		_header.visible = _header.text != ""
		_body.text = String(trigger.get("text", ""))
		_body.visible = _body.text != ""
	visible = true


## The index of the trigger the player is inside, skipping spent `once` ones, or -1.
func _current_trigger(triggers: Array, centre: Vector2) -> int:
	for i in triggers.size():
		var trigger: Dictionary = triggers[i]
		var rect := Rect2(float(trigger.get("x", 0.0)), float(trigger.get("y", 0.0)),
			float(trigger.get("width", 0.0)), float(trigger.get("height", 0.0)))
		if not rect.has_point(centre):
			continue
		# A spent `once` trigger stays hidden unless it is the one already showing.
		if i != _active and bool(trigger.get("once", false)) and _spent.get(i, false):
			continue
		return i
	return -1
