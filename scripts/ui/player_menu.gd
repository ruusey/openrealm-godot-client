class_name PlayerMenu
extends PanelContainer

## What you can do to a player you clicked: the web client's context
## menu, in Godot's own controls -- the name as a header in its role
## colour, then Trade, Teleport, Invite to Party, Challenge to PvP and, when
## your guild rank allows it, Invite to Guild. Opens where it was asked to and
## closes on any choice or on a press anywhere else.

const INVITE_COLOUR := Color("fff0a0")
const GUILD_COLOUR := Color("a0d8ff")
const PVP_COLOUR := Color("ff8a8a")

var player_name := ""

var _header: Label
var _actions: Dictionary   # "trade" / "teleport" / "invite" / "guild" -> Callable
## Shown only when the local player's rank can invite to their guild; the
## server re-checks, so this is UX, not the authority.
var _guild_button: Button
var _can_guild_invite: Callable


func _init(on_trade: Callable, on_teleport: Callable, on_invite: Callable,
		on_guild_invite: Callable, can_guild_invite: Callable, on_pvp: Callable) -> void:
	_actions = {"trade": on_trade, "teleport": on_teleport, "invite": on_invite,
		"guild": on_guild_invite, "pvp": on_pvp}
	_can_guild_invite = can_guild_invite
	visible = false
	var column := InventoryLayout.column(self)
	_header = InventoryLayout.heading(column, "")
	_option(column, "trade", "Trade", Color.WHITE)
	_option(column, "teleport", "Teleport", Color.WHITE)
	_option(column, "invite", "Invite to Party", INVITE_COLOUR)
	_option(column, "pvp", "Challenge to PvP", PVP_COLOUR)
	_guild_button = _option(column, "guild", "Invite to Guild", GUILD_COLOUR)


func open_for(name: String, colour: Color, at: Vector2) -> void:
	player_name = name
	_header.text = name
	_header.add_theme_color_override("font_color", colour)
	_guild_button.visible = _can_guild_invite.is_valid() and _can_guild_invite.call()
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


func _option(into: Container, action: String, text: String, colour: Color) -> Button:
	var button := InventoryLayout.button(into, text, func() -> void: choose(action))
	button.add_theme_color_override("font_color", colour)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button
