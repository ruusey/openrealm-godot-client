class_name LootWindow
extends CanvasLayer

## The bag at our feet, WoW's way: beside the backpack (`at`), by the left
## thumb, a thumb-high row an item and Loot all / Close under them; Close
## puts it away until the next bag. Takes are pick_ups.

const WIDTH := 300.0
const BUTTON_HEIGHT := 56.0

var state: RealmState
var content: GameData
var actions: InventoryActions
## Asked for by name in a scripted capture; otherwise always.
var shown := true
## Its corner: InventoryPanel.beside, or the top-left with no bag.
var at: Callable = func() -> Vector2: return Vector2(InventoryLayout.MARGIN, PartyPanel.TOP)

var _root: PanelContainer
var _title: Label
var _rows_box: VBoxContainer
var _full: Label
var _loot_all: Button
var _tooltip: ItemTooltip
var _drawn := ""
var _closed_on := -1   # the bag Close put away, until we step off it


func setup(realm_state: RealmState, game_data: GameData, inventory_actions: InventoryActions,
		corner: Callable = Callable()) -> void:
	state = realm_state
	content = game_data
	actions = inventory_actions
	at = corner if corner.is_valid() else at


func _ready() -> void:
	layer = 13   # over the bag and the chat, under the shops
	visible = false
	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(WIDTH, 0.0)
	# Opaque, as the options are: the default panel let the world through.
	_root.add_theme_stylebox_override("panel", box(ItemTooltip.BACKGROUND, ItemTooltip.EDGE))
	add_child(_root)
	var column := InventoryLayout.column(_root)
	_title = HudWidgets.label("Loot", 20, Color("c8a86e"))
	column.add_child(_title)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	column.add_child(_rows_box)
	_full = HudWidgets.label("Your backpack is full.", 14, Color("e85050"))
	column.add_child(_full)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_loot_all = InventoryLayout.button(buttons, "Loot all", loot_all)
	InventoryLayout.button(buttons, "Close", close)
	for button in buttons.get_children():
		button.custom_minimum_size.y = BUTTON_HEIGHT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	var bag: Dictionary = {} if actions == null or state == null or not state.local.is_present() \
		else Inventory.nearest_loot(state.entities, state.local.position, GameConstants.PLAYER_SIZE)
	var bag_id := int(bag.get("id", -1))
	if bag_id != _closed_on:
		_closed_on = -1
	visible = shown and bag_id != -1 and bag_id != _closed_on and _count(bag) > 0
	if not visible:
		_tooltip.hide_card()
		_drawn = ""
		return
	var key := "%d:%s:%d" % [bag_id, str(bag.get("items", [])), state.local.inventory.version]
	if key != _drawn:
		_drawn = key
		refresh()
	_root.position = at.call()
	PanelFit.shrink(_root, Vector2.ZERO)   # about its top-left, where it is pinned
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


## The rows, one an item the bag holds, in the bag's own slot order.
func refresh() -> void:
	for row in _rows_box.get_children():
		row.free()
	var items := actions.loot_items()
	for i in items.size():
		if not Inventory.holds(items[i]):
			continue
		var row := LootRow.new()
		row.show_item(i, items[i], content)
		row.pressed.connect(take.bind(i))
		row.hovered.connect(_on_hover)
		_rows_box.add_child(row)
	_full.visible = state.local.inventory.first_empty_backpack() == -1
	_loot_all.disabled = _full.visible
	_root.reset_size()


func take(index: int) -> bool:
	return actions.pick_up(index)


## Everything, one pickup an item; the server fills the backpack in order
## and refuses what does not fit.
func loot_all() -> int:
	var taken := 0
	for i in actions.loot_items().size():
		if take(i):
			taken += 1
	return taken


func close() -> void:
	var bag := Inventory.nearest_loot(state.entities, state.local.position, GameConstants.PLAYER_SIZE)
	_closed_on = int(bag.get("id", -1))


func row_count() -> int:
	return _rows_box.get_child_count()


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


static func box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


static func _count(bag: Dictionary) -> int:
	return (bag.get("items", []) as Array).filter(func(item: Variant) -> bool: return Inventory.holds(item)).size()


func _on_hover(index: int, over: bool) -> void:
	var item := actions.loot_item(index) if over else {}
	if Inventory.holds(item):
		_tooltip.show_for(item, _root.get_global_mouse_position())
	else:
		_tooltip.hide_card()
