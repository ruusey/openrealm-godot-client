class_name HowToPanel
extends Control

## The web client's "How to Play" modal: the "?" on the sign-in panel opens
## it, and the close button, a click on the dimmed screen around it or
## Escape put it away.
##
## One RichTextLabel with its own scroll bar holds the guide (HowToGuide),
## written afresh each time it opens so the keys it names are the keys as
## they are bound now. It sits over the sign-in panel, which the web's
## covers the same way, and does nothing while shut.

const WIDTH := 640
const BODY_HEIGHT := 520

var body: RichTextLabel
var close_button: Button
var _dim: ColorRect


func _ready() -> void:
	# The offsets too: under a CanvasLayer the anchors alone leave a
	# Control at zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.10, 0.14), 4))
	centre.add_child(panel)
	var column := InventoryLayout.column(panel)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := HudWidgets.label(HowToGuide.TITLE, 20, OptionsPanel.HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = InventoryLayout.button(header, "×", close)
	close_button.flat = true
	close_button.tooltip_text = "Close"
	close_button.add_theme_font_size_override("font_size", 22)

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.focus_mode = Control.FOCUS_ALL
	body.custom_minimum_size = Vector2(WIDTH - 24, BODY_HEIGHT)
	body.add_theme_font_size_override("normal_font_size", 13)
	body.add_theme_font_size_override("bold_font_size", 13)
	body.add_theme_font_size_override("italics_font_size", 13)
	body.add_theme_stylebox_override("normal", _box(Color(0.05, 0.04, 0.06), 10))
	column.add_child(body)


func open() -> void:
	body.text = HowToGuide.bbcode()
	body.scroll_to_line(0)
	visible = true
	body.grab_focus.call_deferred()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## A click on the dimmed screen outside the box, as the web's overlay.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


## The round "?" that opens it, `size` across, into `into`: a badge, as the
## web's is -- the theme's flat button reads as a stray character in a corner.
static func badge(into: Container, size: int, on_press: Callable) -> Button:
	var button := InventoryLayout.button(into, "?", on_press)
	button.custom_minimum_size = Vector2(size, size)
	button.tooltip_text = "How to Play"
	for state in ["normal", "hover", "pressed"]:
		var round := StyleBoxFlat.new()
		round.bg_color = Color(0.24, 0.19, 0.28) if state == "normal" else Color(0.34, 0.27, 0.40)
		round.border_color = PlayerHud.GOLD
		round.set_border_width_all(1)
		round.set_corner_radius_all(size / 2)
		button.add_theme_stylebox_override(state, round)
	button.add_theme_color_override("font_color", PlayerHud.GOLD)
	return button


static func _box(colour: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = ItemTooltip.EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(margin)
	return style
