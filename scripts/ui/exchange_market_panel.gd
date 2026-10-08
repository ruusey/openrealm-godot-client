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

const SELL_HINT := "Sell backpack items for REALM. Only gear, gems, rings and uniques pay out; consumables don't. Cash out from the Economy menu."

var state: RealmState
var content: GameData
var shop: ShopActions
var actions: InventoryActions

var _root: PanelContainer
var _give: VBoxContainer
var _receive: VBoxContainer
var _count: Label
var _summary: Label
var _confirm: Button
var _tooltip: ItemTooltip
var _rows := {"give": [], "receive": []}
var _drawn := Vector2i(-1, -1)
# Tabs: "swap" (consumable exchange) and "exchange" (sell for REALM).
var _tab := "swap"
var _swap_tab: Button
var _exchange_tab: Button
var _swap_view: VBoxContainer
var _exchange_view: VBoxContainer
var _sell_list: VBoxContainer
var _points_label: Label
var _sell_drawn := -1


func setup(realm_state: RealmState, game_data: GameData, shop_actions: ShopActions,
		inventory_actions: InventoryActions) -> void:
	state = realm_state
	content = game_data
	shop = shop_actions
	actions = inventory_actions


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

	# Tab bar: Item Swap (consumable exchange) vs Item Exchange (sell for REALM).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	_swap_tab = InventoryLayout.button(tabs, "Item Swap", func() -> void: _show_tab("swap"))
	_exchange_tab = InventoryLayout.button(tabs, "Item Exchange", func() -> void: _show_tab("exchange"))

	# --- Item Swap view (the original exchange market) ---
	_swap_view = VBoxContainer.new()
	_swap_view.add_theme_constant_override("separation", 8)
	column.add_child(_swap_view)
	InventoryLayout.heading(_swap_view, HINT)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	_swap_view.add_child(columns)
	_give = ExchangeRows.column(columns, "You give")
	_receive = ExchangeRows.column(columns, "You receive")
	var counter := HBoxContainer.new()
	_swap_view.add_child(counter)
	InventoryLayout.heading(counter, "Give")
	InventoryLayout.button(counter, "-", func() -> void: _adjust(-1))
	_count = InventoryLayout.heading(counter, "2")
	_count.add_theme_color_override("font_color", Color.WHITE)
	InventoryLayout.button(counter, "+", func() -> void: _adjust(1))
	InventoryLayout.button(counter, "Max", func() -> void: _adjust(999_999))
	_summary = InventoryLayout.heading(_swap_view, "")
	_confirm = InventoryLayout.button(_swap_view, "Exchange", func() -> void: if shop != null: shop.exchange())

	# --- Item Exchange view (sell backpack items for REALM) ---
	_exchange_view = VBoxContainer.new()
	_exchange_view.add_theme_constant_override("separation", 8)
	_exchange_view.visible = false
	column.add_child(_exchange_view)
	InventoryLayout.heading(_exchange_view, SELL_HINT)
	_points_label = InventoryLayout.heading(_exchange_view, "")
	_points_label.add_theme_color_override("font_color", EconomyStyle.GOLD)
	_points_label.add_theme_font_size_override("font_size", 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_exchange_view.add_child(scroll)
	_sell_list = VBoxContainer.new()
	_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_sell_list)

	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)
	_show_tab("swap")


func _process(_delta: float) -> void:
	visible = state != null and state.market.is_open and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	PanelFit.shrink(_root)
	if _tab == "swap":
		var now := Vector2i(state.market.version, state.local.inventory.version)
		if now != _drawn:
			refresh()
	else:
		var stamp := state.local.inventory.version + state.progress.version
		if stamp != _sell_drawn:
			refresh_sell()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func _show_tab(name: String) -> void:
	_tab = name
	_swap_view.visible = name == "swap"
	_exchange_view.visible = name == "exchange"
	_swap_tab.disabled = name == "swap"
	_exchange_tab.disabled = name == "exchange"
	_drawn = Vector2i(-1, -1)
	_sell_drawn = -1


## Rebuild the sell list: one row per backpack item, with a Sell button that
## fires SellItemForPointsPacket. The server rejects zero-value items, so no
## client price copy is needed; results arrive as a system message + points sync.
func refresh_sell() -> void:
	_sell_drawn = state.local.inventory.version + state.progress.version
	_points_label.text = "Banked: %d REALM" % state.progress.earned_points
	for child in _sell_list.get_children():
		child.queue_free()
	var any := false
	for slot in range(Inventory.BACKPACK_START, Inventory.BACKPACK_START + Inventory.BACKPACK_SIZE):
		var item := state.local.inventory.item_at(slot)
		if not Inventory.holds(item):
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_sell_list.add_child(row)
		var name_label := InventoryLayout.heading(row, String(item.get("name", "Item")))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price := content.realm_price_for(item)
		# Only items earned during an active membership are cashable (server-enforced);
		# show why the rest can't sell instead of letting the player hit a rejection.
		var eligible: bool = bool(item.get("earnedDuringMembership", false))
		var label_text := "not sellable"
		if price > 0:
			label_text = ("%d REALM" % price) if eligible else ("%d REALM - not earned with membership" % price)
		var price_label := InventoryLayout.heading(row, label_text)
		price_label.add_theme_color_override("font_color", EconomyStyle.GOLD if (price > 0 and eligible) else EconomyStyle.MUTED)
		if price > 0 and eligible:
			var captured := slot
			InventoryLayout.button(row, "Sell", func() -> void: if actions != null: actions.sell_for_points(captured))
	if not any:
		InventoryLayout.heading(_sell_list, "Your backpack is empty.")


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
