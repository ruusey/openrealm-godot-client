class_name InventoryPanel
extends CanvasLayer

## The bag on screen: equipment, backpack and potions -- the loot at your
## feet is the LootWindow's -- in Godot's own controls with the sprites kept for the items. Up in
## a realm, as both references keep theirs; Tab puts it away. On the left,
## under the party and nearby lists (`below`) -- the same place on a desktop
## and a phone, where it also stays under the Bag button (`floor_top`).
## Every gesture goes straight to InventoryActions; the next UpdatePacket
## redraws the slots. `setup` comes before the panel enters the tree.

const PAGES := Inventory.BACKPACK_SIZE / Inventory.PAGE_SIZE

var state: RealmState
var content: GameData
var actions: InventoryActions
var shown := true
var page := 0

var _root: Container
var _equipment: Array = []
var _backpack: Array = []
var _tabs: Array = []
var _hp: Button
var _mp: Button
var _tooltip: ItemTooltip
var _drawn_version := -1
## Where the left column above it ends, and the least top a phone's Bag
## row leaves it, both in the canvas's pixels.
var below: Callable = func() -> float: return float(PartyPanel.TOP)
var floor_top := 0.0


func setup(realm_state: RealmState, game_data: GameData, inventory_actions: InventoryActions) -> void:
	state = realm_state
	content = game_data
	actions = inventory_actions


func _ready() -> void:
	layer = 11   # over the diagnostics, under the chat and the transition cover
	visible = false
	_root = InventoryLayout.root(self)
	var column := InventoryLayout.column(_root)
	InventoryLayout.heading(column, "Equipment")
	_equipment = InventoryLayout.gear_row(column)
	_tabs = InventoryLayout.page_bar(column, PAGES, set_page)
	_backpack = InventoryLayout.grid(column, Inventory.PAGE_SIZE, Inventory.BACKPACK_START)
	var potions := HBoxContainer.new()
	column.add_child(potions)
	_hp = InventoryLayout.potion(potions, func() -> void: if actions != null: actions.drink(true))
	_mp = InventoryLayout.potion(potions, func() -> void: if actions != null: actions.drink(false))
	for slot in _equipment + _backpack:
		_wire(slot)
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and shown and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	_root.offset_top = top()
	PanelFit.shrink(_root, Vector2.ZERO)
	if state.local.inventory.version != _drawn_version:
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


func toggle() -> void:
	shown = not shown


func set_page(wanted: int) -> void:
	page = clampi(wanted, 0, PAGES - 1)
	_drawn_version = -1


## A click on the panel is not a shot at the world.
func captures_mouse() -> bool:
	return visible and (_root.get_global_rect().has_point(_root.get_global_mouse_position())
		or get_viewport().gui_is_dragging())


func _wire(slot: ItemSlot) -> void:
	slot.hovered.connect(_on_hover)
	if actions == null:
		return
	slot.dropped.connect(actions.move)
	slot.activated.connect(actions.activate)
	slot.thrown.connect(actions.drop)
	slot.secondary.connect(_on_secondary)


## Right-click drops, or stashes into an open potion store; Shift splits.
func _on_secondary(index: int, split: bool) -> void:
	if split:
		actions.split(index)
	elif not actions.stash(index):
		actions.drop(index)


func _on_hover(index: int, over: bool) -> void:
	var item := actions.item_in(index) if over and actions != null else {}
	if Inventory.holds(item):
		_tooltip.show_for(item, _root.get_global_mouse_position())
	else:
		_tooltip.hide_card()


## Where the bag's top sits, shown or not.
func top() -> float:
	return maxf(below.call() + InventoryLayout.MARGIN, floor_top)


## Just right of where the bag sits, level with its top, whether it is open
## or put away: the loot window's corner (LootWindow.at).
func beside() -> Vector2:
	var wide := _root.get_combined_minimum_size().x * _root.scale.x if _root != null else 0.0
	return Vector2(InventoryLayout.MARGIN * 2.0 + wide, top())
