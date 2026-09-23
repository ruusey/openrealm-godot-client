class_name FameStorePanel
extends CanvasLayer

## The fame store: what is for sale, what it costs, and what you have.
##
## The rows are the catalogue in `fame-store.json`, cheapest first, each
## with the item's icon, its name, its price and a Buy button that is only
## live when the balance covers it -- the web client's list. The balance is
## whatever the server said when it opened the store, and again after each
## purchase; a refusal arrives as a SYSTEM line in the chat.

const TITLE := "FAME STORE"
const ICON_PX := 32
const LIST_HEIGHT := 260.0

var state: RealmState
var content: GameData
var shop: ShopActions

var _root: PanelContainer
var _balance: Label
var _list: VBoxContainer
var _rows: Array = []
var _tooltip: ItemTooltip
var _drawn := -1


func setup(realm_state: RealmState, game_data: GameData, shop_actions: ShopActions) -> void:
	state = realm_state
	content = game_data
	shop = shop_actions


func _ready() -> void:
	layer = 14
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(340, 0)
	centre.add_child(_root)
	var column := InventoryLayout.column(_root)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	InventoryLayout.heading(bar, TITLE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: state.fame.close())
	bar.add_child(close)
	_balance = InventoryLayout.heading(column, "")
	_balance.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and state.fame.is_open and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	# Content can land after the panel is built; the rows wait for it.
	if _rows.is_empty():
		_build_rows()
	if state.fame.version != _drawn:
		refresh()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	_drawn = state.fame.version
	_balance.text = "Your fame: %d" % state.fame.balance
	for row in _rows:
		row["button"].disabled = not state.fame.can_afford(row["cost"])


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


func _build_rows() -> void:
	for entry in FameStore.catalogue(content):
		var item_id: int = entry[0]
		var definition := content.item_definition(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_entered.connect(func() -> void:
			_tooltip.show_for(definition, _root.get_global_mouse_position()))
		row.mouse_exited.connect(_tooltip.hide_card)
		_list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = content.item_texture(item_id)
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		InventoryLayout.heading(words, str(definition.get("name", "Item %d" % item_id))) \
			.add_theme_color_override("font_color", Color.WHITE)
		InventoryLayout.heading(words, "%d Fame" % entry[1])
		var button := Button.new()
		button.text = "Buy"
		button.pressed.connect(func() -> void: if shop != null: shop.buy(item_id))
		row.add_child(button)
		_rows.append({"item_id": item_id, "cost": entry[1], "button": button})
	_drawn = -1
