class_name TradePanel
extends CanvasLayer

## The trade: your page and theirs side by side, what each has put on the
## table lit, the status line the web client shows, Confirm and Cancel.
##
## Your slots toggle on a click; theirs are read-only. Both grids are the
## bag's first page -- twenty slots from the fifth -- which is all the
## server puts on the table. The grids are refilled when the trade or the
## bag changes, so a swap the server has just made shows at once.

const TITLE := "TRADE"
const SELECTED := Color(1.6, 1.45, 0.6)

var state: RealmState
var content: GameData
var actions: TradeActions

var _root: PanelContainer
var _status: Label
var _my_name: Label
var _their_name: Label
var _mine: Array = []
var _theirs: Array = []
var _confirm: Button
var _drawn := Vector2i(-1, -1)


func setup(realm_state: RealmState, game_data: GameData, trade_actions: TradeActions) -> void:
	state = realm_state
	content = game_data
	actions = trade_actions


func _ready() -> void:
	layer = 14
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = PanelContainer.new()
	centre.add_child(_root)
	var column := InventoryLayout.column(_root)
	InventoryLayout.heading(column, TITLE)
	_status = InventoryLayout.heading(column, "")
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	column.add_child(sides)
	_my_name = _side(sides, true)
	_their_name = _side(sides, false)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_confirm = InventoryLayout.button(buttons, "Confirm", func() -> void: if actions != null: actions.confirm())
	InventoryLayout.button(buttons, "Cancel", func() -> void: if actions != null: actions.decline())


func _side(into: Container, ours: bool) -> Label:
	var box := VBoxContainer.new()
	into.add_child(box)
	var name := InventoryLayout.heading(box, "")
	name.add_theme_color_override("font_color", Color.WHITE)
	var slots := InventoryLayout.grid(box, TradeSession.SLOTS, TradeSession.FIRST_SLOT)
	for slot in slots:
		if ours:
			slot.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(slot.index, event))
		else:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ours:
		_mine = slots
	else:
		_theirs = slots
	return name


func _on_slot_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.double_click and actions != null:
		actions.toggle(index)


func _process(_delta: float) -> void:
	visible = state != null and state.trade.active and state.local.is_present()
	if not visible:
		_drawn = Vector2i(-1, -1)
		return
	var now := Vector2i(state.trade.version, state.local.inventory.version)
	if now != _drawn:
		refresh()


func refresh() -> void:
	_drawn = Vector2i(state.trade.version, state.local.inventory.version)
	var trade := state.trade
	_status.text = trade.status()
	_my_name.text = state.local.name if state.local.name != "" else "YOU"
	_their_name.text = trade.partner_name if trade.partner_name != "" else "PARTNER"
	for page in TradeSession.SLOTS:
		var index := TradeSession.FIRST_SLOT + page
		var mine: ItemSlot = _mine[page]
		mine.show_from(state.local.inventory.item_at(index), content)
		mine.self_modulate = SELECTED if trade.my_selected[page] else Color.WHITE
		var theirs: ItemSlot = _theirs[page]
		theirs.show_from(trade.partner_item(index), content)
		theirs.self_modulate = SELECTED if trade.partner_selected(page) else Color.WHITE
	_confirm.text = "Confirmed" if trade.my_confirmed() else "Confirm"
	_confirm.disabled = trade.my_confirmed()


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
