class_name EconomyStyle
extends RefCounted

## Shared styling for the REALM economy UIs (Economy hub + Item Exchange), so
## they read as a deliberate panel rather than raw Godot controls. Dark rounded
## cards, a teal accent, gold for REALM values. Construction only.

const BG := Color("12151c")
const CARD := Color("1b2030")
const BORDER := Color("2c3650")
const ACCENT := Color("4fd1c5")
const GOLD := Color("f0b429")
const TEXT := Color("d7dbe4")
const MUTED := Color("8a93a6")
const DANGER := Color("e2576f")


static func _box(fill: Color, border: Color, radius: int, border_w := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


## The outer dialog frame.
static func dialog() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(BG, BORDER, 12, 1))
	panel.custom_minimum_size = Vector2(400, 0)
	return panel


## A raised card to group a section inside the dialog.
static func card(into: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(CARD, BORDER, 8, 1))
	into.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box


static func title(into: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ACCENT)
	into.add_child(label)
	return label


static func section(into: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	into.add_child(label)
	return label


static func body(into: Container, text: String, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(label)
	return label


## A label:value row with the value emphasised (gold by default).
static func stat(into: Container, label_text: String, value_text: String, value_color := GOLD) -> Label:
	var row := HBoxContainer.new()
	into.add_child(row)
	var left := Label.new()
	left.text = label_text
	left.add_theme_color_override("font_color", MUTED)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := Label.new()
	right.text = value_text
	right.add_theme_color_override("font_color", value_color)
	right.add_theme_font_size_override("font_size", 15)
	row.add_child(right)
	return right


static func _style_button(btn: Button, fill: Color, text_color: Color, border: Color) -> void:
	var normal := _box(fill, border, 7, 1)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := _box(fill.lightened(0.08), border, 7, 1)
	hover.content_margin_top = 9
	hover.content_margin_bottom = 9
	var pressed := _box(fill.darkened(0.12), border, 7, 1)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 9
	var disabled := _box(fill.darkened(0.4), border.darkened(0.3), 7, 1)
	disabled.content_margin_top = 9
	disabled.content_margin_bottom = 9
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)


static func primary(into: Container, text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	_style_button(btn, ACCENT, Color("06121a"), ACCENT)
	btn.pressed.connect(on_press)
	into.add_child(btn)
	return btn


static func secondary(into: Container, text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	_style_button(btn, CARD, TEXT, BORDER)
	btn.pressed.connect(on_press)
	into.add_child(btn)
	return btn
