class_name TradeRequestPopup
extends CanvasLayer

## "<name> wants to trade", with Accept and Decline: the web client's
## popup, up while a request stands and gone when it is answered or the
## server's fifteen seconds run out.

var state: RealmState
var actions: TradeActions

var _root: PanelContainer
var _line: Label
var _shown_for := ""


func setup(realm_state: RealmState, trade_actions: TradeActions) -> void:
	state = realm_state
	actions = trade_actions


func _ready() -> void:
	layer = 16
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.offset_top = 120.0
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
	visible = state != null and state.trade.request_from != "" and state.local.is_present()
	if visible and _shown_for != state.trade.request_from:
		_shown_for = state.trade.request_from
		_line.text = "%s wants to trade" % state.trade.request_from
	elif not visible:
		_shown_for = ""


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
