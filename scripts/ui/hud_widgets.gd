class_name HudWidgets
extends RefCounted

## The player HUD's parts, built from Godot's own controls.
##
## Construction only, as InventoryLayout is for the bag: a bar is a
## ProgressBar with flat style boxes and a label laid over it, a stat cell
## is a caption, a value and the equipment bonus beside it. PlayerHud owns
## the state and writes the text; this knows what the pieces look like.

const BAR_HEIGHT := 16
const BAR_BACK := Color(0.08, 0.08, 0.1, 0.9)
const TEXT_SIZE := 12
const CAPTION := Color(0.7, 0.7, 0.75)


## A filled bar with its text centred over the fill: [bar, label]. A
## party row's bars are a few pixels tall and carry no text.
static func bar(into: Container, fill: Color, height := BAR_HEIGHT) -> Array:
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, height)
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.step = 0.0
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _flat(BAR_BACK))
	progress.add_theme_stylebox_override("fill", _flat(fill))
	into.add_child(progress)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TEXT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(label)
	return [progress, label]


## Recolour a bar's fill: the XP bar turns gold once it is fame.
static func refill(progress: ProgressBar, fill: Color) -> void:
	progress.add_theme_stylebox_override("fill", _flat(fill))


## One cell of the stats grid: "STR" over "75 +5", as [value, bonus].
static func stat_cell(into: Container, caption: String) -> Array:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(column)
	column.add_child(label(caption, 10, CAPTION))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	column.add_child(row)
	var value := label("", TEXT_SIZE, Color.WHITE)
	row.add_child(value)
	var bonus := label("", 10, Color.WHITE)
	row.add_child(bonus)
	return [value, bonus]


static func label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _flat(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(2)
	return box
