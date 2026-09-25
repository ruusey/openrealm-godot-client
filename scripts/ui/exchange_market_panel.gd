class_name ExchangeMarketPanel
extends CanvasLayer

## The exchange market: what you could give, what you would get for it,
## how many, and the one button.
##
## The web client's modal: a column of every exchangeable stack you hold
## with its count, a column of the other items of the chosen one's kind, a
## counter from two up to what you hold, a summary line, Exchange. Both
## columns are rebuilt whenever the bag or the choice changes, so the
## counts track a swap the server has just answered.

const TITLE := "EXCHANGE MARKET"
const HINT := "Swap consumables of the same kind. One item is kept by the market as tax."
const ICON_PX := 32
const LIST_HEIGHT := 220.0

var state: RealmState
var content: GameData
var shop: ShopActions

var _root: PanelContainer
var _give: VBoxContainer
var _receive: VBoxContainer
var _count: Label
var _summary: Label
var _confirm: Button
var _tooltip: ItemTooltip
var _rows := {"give": [], "receive": []}
var _drawn := Vector2i(-1, -1)


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
	_root.custom_minimum_size = Vector2(560, 0)
	centre.add_child(_root)
	var column := InventoryLayout.column(_root)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	InventoryLayout.heading(bar, TITLE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryLayout.button(bar, "Close", func() -> void: state.market.close())
	InventoryLayout.heading(column, HINT)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	column.add_child(columns)
	_give = ExchangeRows.column(columns, "You give")
	_receive = ExchangeRows.column(columns, "You receive")
	var counter := HBoxContainer.new()
	column.add_child(counter)
	InventoryLayout.heading(counter, "Give")
	InventoryLayout.button(counter, "-", func() -> void: _adjust(-1))
	_count = InventoryLayout.heading(counter, "2")
	_count.add_theme_color_override("font_color", Color.WHITE)
	InventoryLayout.button(counter, "+", func() -> void: _adjust(1))
	InventoryLayout.button(counter, "Max", func() -> void: _adjust(999_999))
	_summary = InventoryLayout.heading(column, "")
	_confirm = InventoryLayout.button(column, "Exchange", func() -> void: if shop != null: shop.exchange())
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and state.market.is_open and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	PanelFit.shrink(_root)
	var now := Vector2i(state.market.version, state.local.inventory.version)
	if now != _drawn:
		refresh()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	_drawn = Vector2i(state.market.version, state.local.inventory.version)
	var market := state.market
	var owned := ExchangeMarket.owned(state.local.inventory, content)
	# A stack given away entirely is no longer a choice.
	if market.source >= 0 and not owned.has(market.source):
		market.select_source(-1, 0)
	var ids := owned.keys()
	ids.sort()
	_rows["give"] = ExchangeRows.fill(_give, content, ids, market.source, _tooltip, _root,
		func(item_id: int) -> String: return "x%d" % owned[item_id],
		func(item_id: int) -> void: market.select_source(item_id, owned[item_id]))
	_rows["receive"] = ExchangeRows.fill(_receive, content,
		ExchangeMarket.members(content, market.source) if market.source >= 0 else [],
		market.target, _tooltip, _root,
		func(_item_id: int) -> String: return "",
		func(item_id: int) -> void: market.select_target(item_id))
	ExchangeRows.empty_note(_give, _rows["give"], "No exchangeable items.")
	ExchangeRows.empty_note(_receive, _rows["receive"],
		"Pick an item to give." if market.source < 0 else "Nothing to swap for.")
	var held := int(owned.get(market.source, 0))
	_count.text = str(market.quantity)
	_summary.text = summary(market, held)
	_confirm.disabled = not market.ready(held)


## The web client's three lines.
func summary(market: ExchangeMarket, held: int) -> String:
	if market.ready(held):
		return "%d %s -> %d %s" % [market.quantity, content.item_name(market.source),
			ExchangeMarket.output(market.quantity), content.item_name(market.target)]
	if market.source >= 0 and held < ExchangeMarket.MIN_QUANTITY:
		return "Need at least 2 to exchange."
	return "Select an item to give and one to receive."


func _adjust(by: int) -> void:
	var market := state.market
	var held := int(ExchangeMarket.owned(state.local.inventory, content).get(market.source, 0))
	market.set_quantity(market.quantity + by, held)


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
