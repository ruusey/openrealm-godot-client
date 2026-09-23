class_name PartyInvitePopup
extends CanvasLayer

## "<name> wants you in their party", with Accept and Decline: both
## references' prompt for the server's invite line, up while the invite
## stands and gone when it is answered or its sixty seconds run out.

const TOP := 200.0

var state: RealmState
var actions: PartyActions

var _root: PanelContainer
var _line: Label
var _shown_for := ""


func setup(realm_state: RealmState, party_actions: PartyActions) -> void:
	state = realm_state
	actions = party_actions


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
	InventoryLayout.button(buttons, "Accept", func() -> void: if actions != null: actions.accept())
	InventoryLayout.button(buttons, "Decline", func() -> void: if actions != null: actions.decline())


func _process(_delta: float) -> void:
	visible = state != null and state.party.invite_from != "" and state.local.is_present()
	if visible and _shown_for != state.party.invite_from:
		_shown_for = state.party.invite_from
		_line.text = "%s wants you in their party" % state.party.invite_from
	elif not visible:
		_shown_for = ""


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
