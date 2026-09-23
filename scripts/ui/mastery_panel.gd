class_name MasteryPanel
extends CanvasLayer

## The web client's Skills window: the nine account-wide masteries.
##
## A cell a skill, three across as the web lays them out: the name, the
## level out of 99, and a bar for the way into the next level, with the
## web's hover card -- what the skill covers, its effect a level and now,
## how XP is earned, and how much is left -- as the cell's tooltip. The XP
## comes from SkillsPacket (AccountProgress.mastery_xp); everything shown is
## derived from it by Mastery, since the packet carries nothing else. The
## key is the toggle_masteries action, J by default: the web's M is the
## minimap here. Nothing on it is clickable but Close.

const COLUMNS := 3
const CELL_WIDTH := 200
const BAR := Color(0.36, 0.62, 1.0)
const BAR_FULL := Color(1.0, 0.8, 0.3)

var state: RealmState
var shown := false

var _root: PanelContainer
var _cells: Array = []   # [PanelContainer, level Label, ProgressBar] per skill
var _drawn := ""


func setup(realm_state: RealmState) -> void:
	state = realm_state


func _ready() -> void:
	# The character sheet's layer: over the bar and the bag.
	layer = 13
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ItemTooltip.BACKGROUND
	style.border_color = ItemTooltip.EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_root.add_theme_stylebox_override("panel", style)
	centre.add_child(_root)
	var column := InventoryLayout.column(_root)
	var title := HudWidgets.label("Skills", 18, OptionsPanel.HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for skill in Mastery.SKILLS:
		_cells.append(_cell(grid, skill[0]))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	InventoryLayout.button(buttons, "Close", close)


func _process(_delta: float) -> void:
	visible = shown and state != null and state.local.is_present()
	if visible and str(state.progress.mastery_xp) != _drawn:
		refresh()


## Every cell to the XP the server last sent.
func refresh() -> void:
	var xp: Array = state.progress.mastery_xp
	_drawn = str(xp)
	for index in _cells.size():
		var total := maxi(0, int(xp[index]))
		var level := Mastery.level_for_xp(total)
		var cell: Array = _cells[index]
		cell[0].tooltip_text = Mastery.describe(index, total)
		cell[1].text = "Level %d / %d" % [level, Mastery.MAX_LEVEL]
		cell[2].value = Mastery.progress(total)
		var fill := cell[2].get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = BAR_FULL if level >= Mastery.MAX_LEVEL else BAR


func toggle() -> void:
	shown = not shown


func close() -> void:
	shown = false


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


## A key the chat line or the Controls tab consumed never arrives here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.is_action_pressed("toggle_masteries") and state != null and state.local.is_present():
		toggle()


func _cell(into: Container, skill_name: String) -> Array:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	into.add_child(cell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	cell.add_child(column)
	column.add_child(HudWidgets.label(skill_name, 13, Color.WHITE))
	var level := HudWidgets.label("", 12, SkillsPanel.MUTED)
	column.add_child(level)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.07, 0.1)
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	return [cell, level, bar]
