class_name AbilityBar
extends CanvasLayer

## The hotbar: the class passive, then the three abilities and their keys.
##
## Godot's own controls, like the bag. The cells are built once and repainted
## when the class, the points or the levels change; the cooldown shades are
## driven every frame off AbilityState, which is where a cast puts them, so
## a cast from a key and a cast from a click drain the same cell.

const MARGIN := 8
const KEYS := ["", "1", "2", "3"]

var state: RealmState
var content: GameData
var caster: AbilityCaster
## Opened by a right-click on a cell, where the web client invests a point.
var skills: SkillsPanel
var shown := true

var _root: PanelContainer
var _cells: Array = []
var _companion_cell: CompanionSummonCell
var _tooltip: ItemTooltip
var _drawn := ""


func setup(realm_state: RealmState, game_data: GameData, ability_caster: AbilityCaster,
		skills_panel: SkillsPanel = null) -> void:
	state = realm_state
	content = game_data
	caster = ability_caster
	skills = skills_panel


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.offset_bottom = -MARGIN
	add_child(_root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_root.add_child(row)
	for i in KEYS.size():
		var cell := AbilityCell.new(i, KEYS[i])
		cell.pressed.connect(_on_pressed)
		cell.secondary.connect(_on_secondary)
		cell.hovered.connect(_on_hover)
		row.add_child(cell)
		_cells.append(cell)
	# Companion summon readout at the right end of the hotbar (C key + its timer).
	# Self-hides when the account owns no companion.
	_companion_cell = CompanionSummonCell.new()
	row.add_child(_companion_cell)
	_tooltip = ItemTooltip.new()
	add_child(_tooltip)
	TouchFrame.adopt(self)


func _process(_delta: float) -> void:
	visible = state != null and content != null and shown and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	var key := "%d:%d" % [state.local.class_id, state.abilities.version]
	if key != _drawn:
		refresh()
	for slot in AbilityCatalog.SLOTS:
		_cells[slot + 1].set_cooldown(state.abilities.cooldown_fraction(slot))
	_companion_cell.update_from(state.companions)
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	var class_id := state.local.class_id
	_drawn = "%d:%d" % [class_id, state.abilities.version]
	var passive := content.abilities.passive(class_id)
	if passive.is_empty():
		_cells[0].show_empty()
	else:
		_cells[0].show_ability(null, str(passive.get("name", "?")), 0, 0, 0)
	for slot in AbilityCatalog.SLOTS:
		var id := content.abilities.hotbar_id(class_id, slot)
		var definition := content.abilities.ability(id)
		if definition.is_empty():
			_cells[slot + 1].show_empty()
			continue
		_cells[slot + 1].show_ability(content.abilities.icon(id), str(definition.get("name", "")),
			int(definition.get("mpCost", 0)), state.abilities.invested[slot],
			content.abilities.cap(id))


func toggle() -> void:
	shown = not shown


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


## What the card over a cell says.
func describe(index: int) -> Array:
	var class_id := state.local.class_id
	if index == 0:
		return AbilityDescriber.passive_lines(content.abilities, class_id)
	var slot := index - 1
	return AbilityDescriber.ability_lines(content.abilities, content.abilities.hotbar_id(class_id, slot),
		state.abilities.invested[slot], state.local.stats, "Active - Key %s" % KEYS[index])


func _on_pressed(index: int) -> void:
	if index > 0 and caster != null:
		caster.cast_at_cursor(index - 1)


func _on_secondary(index: int) -> void:
	if index > 0 and skills != null:
		skills.toggle()


func _on_hover(index: int, over: bool) -> void:
	var lines := describe(index) if over and visible else []
	if lines.is_empty():
		_tooltip.hide_card()
	else:
		_tooltip.show_lines(lines, _root.get_global_mouse_position())
