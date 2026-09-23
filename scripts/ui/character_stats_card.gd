class_name CharacterStatsCard
extends CanvasLayer

## "<Class> - Lifetime Stats": the web client's card for a right-clicked
## character, over the sign-in panel with the page dimmed behind it.
##
## It opens at once on "Loading..." and fills when the report lands; a
## failure says why in the same place. The sections run in two columns, as
## the web's two-column body does at this width. The dim, the x and Escape
## all close it, and a report that lands after it was closed, or after it
## was opened on someone else, is dropped.

const TITLE := Color(1.0, 0.85, 0.42)
const LABEL := Color(0.72, 0.66, 0.53)
const VALUE := Color(0.91, 0.86, 0.75)
const MUTED := Color(0.53, 0.47, 0.41)

var data_service: DataService

var title: Label
var columns: HBoxContainer
var message: Label
var close_button: Button

var _asking := 0


func _ready() -> void:
	layer = 21
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: close())
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame())
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = _label(header, "", TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = Button.new()
	close_button.text = "x"
	close_button.flat = true
	close_button.pressed.connect(close)
	header.add_child(close_button)
	message = _label(column, "", MUTED)
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	column.add_child(columns)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Opens on `character` and asks the service for its report.
func open(character: Dictionary, class_label: String) -> void:
	_asking += 1
	var asked := _asking
	title.text = "%s - Lifetime Stats" % class_label
	show_message("Loading...")
	visible = true
	var got: Dictionary = await CharacterMetrics.fetch(
		data_service, str(character.get("characterUuid", "")))
	if asked != _asking or not visible:
		return
	if got["success"]:
		show_report(got["metrics"])
	else:
		show_message("Could not load stats: %s" % got["result"])


func close() -> void:
	_asking += 1
	visible = false


func show_message(text: String) -> void:
	message.text = text
	message.visible = true
	columns.visible = false


func show_report(metrics: Dictionary) -> void:
	for child in columns.get_children():
		columns.remove_child(child)
		child.queue_free()
	var sections := LifetimeStats.sections(metrics)
	var left := _column()
	var right := _column()
	for index in sections.size():
		_section(left if index < 2 else right, sections[index][0], sections[index][1])
	var dungeons := LifetimeStats.dungeons(metrics)
	_section(right, LifetimeStats.DUNGEONS, dungeons)
	if dungeons.is_empty():
		_label(right, LifetimeStats.NONE_YET, MUTED)
	message.visible = false
	columns.visible = true


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 0)
	columns.add_child(box)
	return box


func _section(into: VBoxContainer, heading: String, rows: Array) -> void:
	_label(into, heading.to_upper(), TITLE).add_theme_font_size_override("font_size", 14)
	var grid := GridContainer.new()
	grid.columns = 2
	into.add_child(grid)
	for row in rows:
		_label(grid, row[0], LABEL).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(grid, row[1], VALUE).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(into: Node, text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	into.add_child(label)
	return label


## The web card's frame: near-black, a gold edge, rounded corners.
static func _frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.07, 0.09)
	box.border_color = Color(0.78, 0.66, 0.43)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(16)
	return box
