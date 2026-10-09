class_name PvpChallengePopup
extends CanvasLayer

## "<name> challenges you to a PvP battle!", with Accept and Decline: the web
## client's prompt for the server's challenge line, up while the challenge
## stands and gone when it is answered or its thirty seconds run out. Accept
## and decline send /pvpaccept and /pvpdecline -- the same commands the chat
## could send, the routing the server already has -- and drop the prompt at
## once rather than waiting for the reply.

const TOP := 240.0
const TITLE_COLOUR := Color("ff8a8a")

var state: RealmState
var chat: ChatActions

var _root: PanelContainer
var _line: Label
var _shown_for := ""


func setup(realm_state: RealmState, chat_actions: ChatActions) -> void:
	state = realm_state
	chat = chat_actions


func _ready() -> void:
	layer = 16
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.offset_top = TOP
	add_child(_root)
	var column := InventoryLayout.column(_root)
	_line = InventoryLayout.heading(column, "")
	_line.add_theme_color_override("font_color", TITLE_COLOUR)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	InventoryLayout.button(buttons, "Accept", func() -> void: _answer("/pvpaccept"))
	InventoryLayout.button(buttons, "Decline", func() -> void: _answer("/pvpdecline"))


func _process(_delta: float) -> void:
	visible = state != null and state.pvp.challenge_from != "" and state.local.is_present()
	if visible and _shown_for != state.pvp.challenge_from:
		_shown_for = state.pvp.challenge_from
		_line.text = "%s challenges you to a PvP battle!" % state.pvp.challenge_from
	elif not visible:
		_shown_for = ""


func _answer(command: String) -> void:
	if chat != null:
		chat.say(command)
	if state != null:
		state.pvp.challenge_from = ""


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
