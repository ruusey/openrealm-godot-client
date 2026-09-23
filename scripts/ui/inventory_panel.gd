class_name InventoryPanel
extends CanvasLayer

## The bag on screen: equipment, backpack, potions, and the loot at your feet.
##
## Built from Godot's own controls rather than the reference clients' UI
## atlas -- panels, grids and buttons, with the sprites kept for the items
## themselves. Up whenever we are in a realm, as both references keep theirs,
## and Tab puts it away.
##
## Nothing here changes the bag: every gesture goes straight to
## InventoryActions, and the next UpdatePacket redraws the slots. `setup`
## comes before the panel enters the tree.

const PAGES := Inventory.BACKPACK_SIZE / Inventory.PAGE_SIZE

var state: RealmState
var content: GameData
var actions: InventoryActions
## Tab's say. The realm's say is whether there is a local player at all.
var shown := true
var page := 0

var _root: Container
var _equipment: Array = []
var _backpack: Array = []
var _loot: Array = []
var _loot_box: VBoxContainer
var _tabs: Array = []
var _hp: Button
var _mp: Button
var _tooltip: ItemTooltip
var _drawn_version := -1
var _drawn_loot := ""


func setup(realm_state: RealmState, game_data: GameData, inventory_actions: InventoryActions) -> void:
	state = realm_state
	content = game_data
	actions = inventory_actions


func _ready() -> void:
	# Over the diagnostic overlay, under the chat and the transition cover.
	layer = 11
	visible = false
	_root = InventoryLayout.root(self)
	var column := InventoryLayout.column(_root)
	InventoryLayout.heading(column, "Equipment")
	_equipment = InventoryLayout.gear_row(column)
	_tabs = InventoryLayout.page_bar(column, PAGES, set_page)
	_backpack = InventoryLayout.grid(column, Inventory.PAGE_SIZE, Inventory.BACKPACK_START)
	var potions := HBoxContainer.new()
	column.add_child(potions)
	_hp = InventoryLayout.potion(potions, _drink.bind(true))
	_mp = InventoryLayout.potion(potions, _drink.bind(false))
	_loot_box = VBoxContainer.new()
	_loot_box.visible = false
	column.add_child(_loot_box)
	InventoryLayout.heading(_loot_box, "Loot")
	_loot = InventoryLayout.grid(_loot_box, Inventory.LOOT_SIZE, Inventory.GROUND_LOOT_START)
	for slot in _equipment + _backpack + _loot:
		_wire(slot)
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and shown and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	if state.local.inventory.version != _drawn_version or _loot_key() != _drawn_loot:
		refresh()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	var bag := state.local.inventory
	_drawn_version = bag.version
	for slot in _equipment:
		slot.show_from(bag.item_at(slot.index), content)
	for i in _backpack.size():
		_backpack[i].index = Inventory.BACKPACK_START + page * Inventory.PAGE_SIZE + i
		_backpack[i].show_from(bag.item_at(_backpack[i].index), content)
	for p in _tabs.size():
		_tabs[p].set_pressed_no_signal(p == page)
	_hp.text = "HP x%d" % bag.hp_potions
	_mp.text = "MP x%d" % bag.mp_potions
	var items := actions.loot_items()
	_drawn_loot = _loot_key()
	_loot_box.visible = not items.is_empty()
	for i in _loot.size():
		_loot[i].show_from(items[i] if i < items.size() and items[i] is Dictionary else {}, content)


func toggle() -> void:
	shown = not shown


func set_page(wanted: int) -> void:
	page = clampi(wanted, 0, PAGES - 1)
	_drawn_version = -1


## Whether a click right now is the panel's rather than a shot at the world.
func captures_mouse() -> bool:
	return visible and (_root.get_global_rect().has_point(_root.get_global_mouse_position())
		or get_viewport().gui_is_dragging())


## The bag's contents, so a pickup redraws the strip without a version.
func _loot_key() -> String:
	var ids := PackedStringArray()
	for item in actions.loot_items():
		ids.append(str(item.get("itemId", -1)) if item is Dictionary else "-1")
	return ",".join(ids)


func _wire(slot: ItemSlot) -> void:
	slot.hovered.connect(_on_hover)
	if actions == null:
		return
	slot.dropped.connect(actions.move)
	slot.activated.connect(actions.activate)
	slot.thrown.connect(actions.drop)
	slot.secondary.connect(_on_secondary)


## Right-click drops -- or stashes, while the potion store is open and
## will take the item; with Shift it splits a stack instead.
func _on_secondary(index: int, split: bool) -> void:
	if split:
		actions.split(index)
	elif not actions.stash(index):
		actions.drop(index)


func _drink(hp: bool) -> void:
	if actions != null:
		actions.drink(hp)


func _on_hover(index: int, over: bool) -> void:
	var item := actions.item_in(index) if over and actions != null else {}
	if Inventory.holds(item):
		_tooltip.show_for(item, _root.get_global_mouse_position())
	else:
		_tooltip.hide_card()
