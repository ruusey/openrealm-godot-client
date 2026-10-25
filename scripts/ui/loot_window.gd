class_name LootWindow
extends CanvasLayer

## The bag at our feet, WoW's way: beside the backpack (`at`), by the left
## thumb, a thumb-high row an item and Loot all / Close under them; Close
## puts it away until the next bag. Takes are pick_ups. A vault chest opens
## even empty, as a grid of its slots that a backpack item drags onto, with
## a hint how until the vault quest is done.

const WIDTH := 300.0
const BUTTON_HEIGHT := 56.0
## The server drops into the container this close (top-left to top-left);
## further off a drop makes a new bag, so a chest's slots show only inside it.
const CHEST_REACH := 32.0
const CHEST_COLUMNS := 5
const VAULT_OBJECTIVE := "STORE_IN_VAULT"
## Beside the bag only while that leaves it at least this big; else over the bag.
const MIN_BESIDE_SCALE := 0.75

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
var _chest_slots: GridContainer
var _slots: Array[ItemSlot] = []
var _hint: Label
var _chest := false
var _full: Label
var _loot_all: Button
var _tooltip: ItemTooltip
var _drawn := ""
var _closed_on := -1   # the bag Close put away, until we step off it
## Loot bags do not move, so the proximity scan runs a few times a second rather
## than every frame; the window still appears within this of stepping onto a bag.
## Primed to the interval so the very first frame always scans (tests drive one).
const SCAN_INTERVAL := 0.1
var _scan_elapsed := SCAN_INTERVAL


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
	_chest_slots = GridContainer.new()
	_chest_slots.columns = CHEST_COLUMNS
	_chest_slots.add_theme_constant_override("h_separation", 6)
	_chest_slots.add_theme_constant_override("v_separation", 6)
	_chest_slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_chest_slots)
	for i in Inventory.LOOT_SIZE:
		var slot := ItemSlot.new(Inventory.GROUND_LOOT_START + i)
		slot.custom_minimum_size = Vector2.ONE * BUTTON_HEIGHT
		slot.dropped.connect(func(from: int, to: int) -> void:
			if not Inventory.is_ground_loot(from):
				actions.move(from, to))
		slot.activated.connect(func(index: int) -> void: take(index - Inventory.GROUND_LOOT_START))
		slot.hovered.connect(func(index: int, over: bool) -> void:
			_on_hover(index - Inventory.GROUND_LOOT_START, over))
		_chest_slots.add_child(slot)
		_slots.append(slot)
	_hint = HudWidgets.label("Drag items from your bag onto a slot to store them here.", 14, Color("b8b0a0"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = WIDTH - 24.0
	column.add_child(_hint)
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
	TouchFrame.adopt(self)


func _process(delta: float) -> void:
	_scan_elapsed += delta
	if _scan_elapsed >= SCAN_INTERVAL:
		_scan_elapsed = 0.0
		_rescan()
	if not visible:
		return
	_place()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


## Pinned by its top-left and shrunk to the screen left of and below that
## corner, not to the whole screen: a phone's bag leaves little room beside it.
func _place() -> void:
	var view := TouchScale.view_size(_root)
	var corner: Vector2 = at.call()
	var room := view - corner - Vector2.ONE * PanelFit.MARGIN
	if PanelFit.factor(_root.size, room) < MIN_BESIDE_SCALE:
		corner.x = PanelFit.MARGIN
		room = view - corner - Vector2.ONE * PanelFit.MARGIN
	_root.position = corner
	PanelFit.shrink(_root, Vector2.ZERO, PanelFit.MARGIN, room)


## Re-finds the bag at the player's feet and refreshes the strip if it changed.
## Throttled by _process; the position/tooltip follow still runs every frame.
func _rescan() -> void:
	var bag: Dictionary = {} if actions == null or state == null or not state.local.is_present() \
		else Inventory.nearest_loot(state.entities, state.local.position, GameConstants.PLAYER_SIZE)
	_chest = LootArt.is_chest(bag) and in_chest_reach(bag)
	if LootArt.is_chest(bag) and not _chest:
		bag = {}
	var bag_id := int(bag.get("id", -1))
	if bag_id != _closed_on:
		_closed_on = -1
	visible = shown and bag_id != -1 and bag_id != _closed_on and (_chest or _count(bag) > 0)
	if not visible:
		_tooltip.hide_card()
		_drawn = ""
		return
	var key := "%d:%s:%d:%d" % [bag_id, str(bag.get("items", [])), state.local.inventory.version,
		state.progress.version]
	if key != _drawn:
		_drawn = key
		refresh()


## The rows, one an item the bag holds, in the bag's own slot order; for a
## chest its slots instead.
func refresh() -> void:
	for row in _rows_box.get_children():
		row.free()
	var items := actions.loot_items()
	_title.text = "Vault Chest" if _chest else "Loot"
	_rows_box.visible = not _chest
	_chest_slots.visible = _chest
	_hint.visible = _chest and not state.progress.objective_complete(VAULT_OBJECTIVE)
	for i in _slots.size():
		_slots[i].show_from(items[i] if _chest and i < items.size() and items[i] is Dictionary else {}, content)
	for i in 0 if _chest else items.size():
		if not Inventory.holds(items[i]):
			continue
		var row := LootRow.new()
		row.show_item(i, items[i], content)
		row.pressed.connect(take.bind(i))
		row.hovered.connect(_on_hover)
		_rows_box.add_child(row)
	_full.visible = state.local.inventory.first_empty_backpack() == -1
	_loot_all.disabled = _full.visible or _count({"items": items}) == 0
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


func is_chest() -> bool:
	return visible and _chest


func chest_slot(index: int) -> ItemSlot:
	return _slots[index]


func in_chest_reach(bag: Dictionary) -> bool:
	return state.entities.render_position(bag).distance_to(state.local.position) <= CHEST_REACH


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
