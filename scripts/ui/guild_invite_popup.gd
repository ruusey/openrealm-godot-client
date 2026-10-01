class_name GuildInvitePopup
extends CanvasLayer

## "<name> invites you to <guild>", with Accept and Decline. Up while an invite
## stands, gone the moment it is answered. Accept joins as an Initiate; the
## server answers with a guild update either way.

const TOP := 240.0

var state: RealmState
var actions: GuildActions

var _root: PanelContainer
var _line: Label
var _shown_for := ""


func setup(realm_state: RealmState, guild_actions: GuildActions) -> void:
	state = realm_state
	actions = guild_actions


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
	_line.add_theme_color_override("font_color", Color.WHITE)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	InventoryLayout.button(buttons, "Accept", func() -> void: if actions != null: actions.respond_invite(true))
	InventoryLayout.button(buttons, "Decline", func() -> void: if actions != null: actions.respond_invite(false))


func _process(_delta: float) -> void:
	visible = state != null and state.guild.invite_from != "" and state.local.is_present()
	if visible and _shown_for != state.guild.invite_from:
		_shown_for = state.guild.invite_from
		_line.text = "%s invites you to %s" % [state.guild.invite_from, state.guild.invite_guild_name]
	elif not visible:
		_shown_for = ""


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
