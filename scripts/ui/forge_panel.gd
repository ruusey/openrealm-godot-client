class_name ForgePanel
extends CanvasLayer

## The forge: three zones to drop bag items on, a line saying what is still
## wrong, and the two buttons.
##
## Godot's own controls, like every other panel; the web client's pixel
## editor is left out on purpose and the pixel is picked by ForgePixel. The
## zones are ItemSlots with indices of their own, so a drag from the bag
## lands here through the same gesture as a drag inside the bag; the item is
## not moved, the zone just remembers its bag slot.

const TITLE := "FORGE"
const ZONE_BASE := 3000
const ZONE_CAPTIONS := {"target": "Equipment", "crystal": "Crystal or Gem",
	"essence": "Essence (x%d)" % ForgeRules.ESSENCE_COST}
const STATUS_WIDTH := 380.0
const GOOD := Color(0.5, 0.9, 0.5)
const BAD := Color(1.0, 0.55, 0.45)

var state: RealmState
var content: GameData
var actions: ForgeActions

var _root: Container
var _zones := {}
var _status: Label
var _cost: Label
var _enchant: Button
var _disenchant: Button
var _tooltip: ItemTooltip
var _flash := ""
var _drawn := ""


func setup(realm_state: RealmState, game_data: GameData, forge_actions: ForgeActions) -> void:
	state = realm_state
	content = game_data
	actions = forge_actions


func _ready() -> void:
	layer = 14
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = InventoryLayout.DropSink.new()
	centre.add_child(_root)
	var column := InventoryLayout.column(_root)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	InventoryLayout.heading(bar, TITLE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: state.forge.close())
	bar.add_child(close)

	var zones := HBoxContainer.new()
	zones.add_theme_constant_override("separation", 16)
	column.add_child(zones)
	for i in ForgeBench.ZONES.size():
		var zone: String = ForgeBench.ZONES[i]
		var slot := InventoryLayout.captioned_slot(zones, ZONE_BASE + i, ZONE_CAPTIONS[zone])
		slot.dropped.connect(_on_dropped)
		slot.secondary.connect(func(index: int, _split: bool) -> void: _clear(index))
		slot.hovered.connect(_on_hover)
		_zones[zone] = slot

	_status = InventoryLayout.heading(column, "")
	_status.custom_minimum_size.x = STATUS_WIDTH
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cost = InventoryLayout.heading(column, "")
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_enchant = InventoryLayout.button(buttons, "Enchant", _press.bind(true))
	_disenchant = InventoryLayout.button(buttons, "Disenchant", _press.bind(false))
	_tooltip = ItemTooltip.of(state, content)
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and state.forge.is_open and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	state.forge.prune(state.local.inventory)
	var key := "%d:%d:%s" % [state.forge.version, state.local.inventory.version, _flash]
	if key != _drawn:
		refresh()
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	_drawn = "%d:%d:%s" % [state.forge.version, state.local.inventory.version, _flash]
	var items := {}
	for zone in ForgeBench.ZONES:
		items[zone] = state.forge.item_on(zone, state.local.inventory)
		_zones[zone].show_from(items[zone], content)
	var problem := ForgeRules.problem(items["target"], items["crystal"], items["essence"], content)
	# A rejected drop is said once, ahead of whatever else is still wrong.
	var wrong := _flash if _flash != "" else problem
	var head := ForgeRules.summary(items["target"]) + "   " if Inventory.holds(items["target"]) else ""
	_status.text = (head + wrong).strip_edges()
	_status.add_theme_color_override("font_color", GOOD if wrong == "" else BAD)
	_cost.text = ""
	if Inventory.holds(items["crystal"]) and Inventory.holds(items["essence"]):
		_cost.text = "Cost: 1 %s + %d %s -> %s" % [items["crystal"].get("name", "?"),
			ForgeRules.ESSENCE_COST, items["essence"].get("name", "essence"),
			ForgeRules.effect_preview(items["crystal"])]
	_enchant.disabled = problem != ""
	_disenchant.disabled = not ForgeRules.can_disenchant(items["target"])


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


static func zone_of(index: int) -> String:
	var i := index - ZONE_BASE
	return ForgeBench.ZONES[i] if i >= 0 and i < ForgeBench.ZONES.size() else ""


func _on_dropped(from: int, to: int) -> void:
	if actions != null:
		_flash = actions.place(zone_of(to), from)


func _press(enchant: bool) -> void:
	_flash = ""
	if actions != null:
		(actions.enchant if enchant else actions.disenchant).call()


func _clear(index: int) -> void:
	_flash = ""
	if zone_of(index) != "":
		state.forge.unassign(zone_of(index))


func _on_hover(index: int, over: bool) -> void:
	var item := state.forge.item_on(zone_of(index), state.local.inventory) if over and zone_of(index) != "" else {}
	if Inventory.holds(item):
		_tooltip.show_for(item, _root.get_global_mouse_position())
	else:
		_tooltip.hide_card()

