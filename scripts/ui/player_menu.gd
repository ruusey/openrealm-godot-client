class_name PlayerMenu
extends PanelContainer

## What you can do to a player you clicked: the web client's context
## menu, in Godot's own controls -- the name as a header in its role
## colour, then Trade, Teleport and Invite to Party. Opens where it was
## asked to and closes on any choice or on a press anywhere else.

const INVITE_COLOUR := Color("fff0a0")

var player_name := ""

var _header: Label
var _actions: Dictionary   # "trade" / "teleport" / "invite" -> Callable


func _init(on_trade: Callable, on_teleport: Callable, on_invite: Callable) -> void:
	_actions = {"trade": on_trade, "teleport": on_teleport, "invite": on_invite}
	visible = false
	var column := InventoryLayout.column(self)
	_header = InventoryLayout.heading(column, "")
	_option(column, "trade", "Trade", Color.WHITE)
	_option(column, "teleport", "Teleport", Color.WHITE)
	_option(column, "invite", "Invite to Party", INVITE_COLOUR)


func open_for(name: String, colour: Color, at: Vector2) -> void:
	player_name = name
	_header.text = name
	_header.add_theme_color_override("font_color", colour)
	position = at
	visible = true


func close() -> void:
	visible = false
	player_name = ""


## A choice: the action for the player the menu is open on, then closed.
func choose(action: String) -> bool:
	if not visible or not _actions.has(action):
		return false
	var name := player_name
	close()
	return _actions[action].call(name)


func _option(into: Container, action: String, text: String, colour: Color) -> void:
	var button := InventoryLayout.button(into, text, func() -> void: choose(action))
	button.add_theme_color_override("font_color", colour)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
