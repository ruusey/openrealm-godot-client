class_name TermsGate
extends Control

## The Terms of Use, between signing in and the character list: read to the
## end, then I Agree -- or Decline & Log Out.
##
## Both references' gate: a dimmed screen, the terms in a scrolling box, and
## I Agree dead until the box has been scrolled to its end (or needs no
## scrolling at all). Once unlocked it stays unlocked. It knows nothing of
## the service; `ask()` shows it and comes back with the answer, and
## AccountSignIn does the rest. Godot's own Controls: the body is one
## RichTextLabel with its own scroll bar, so the wheel, the bar and Page
## Down all move it.

signal answered(agreed: bool)

const WIDTH := 560
const BODY_HEIGHT := 300
## How close to the end counts as the end, as the web client allows.
const SLACK_PX := 8.0

var body: RichTextLabel
var hint: Label
var agree_button: Button
var decline_button: Button


func _ready() -> void:
	# The offsets too: under a CanvasLayer the anchors alone leave it at
	# zero size, the dim covering nothing and the box in the corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Watches the scroll only while it is up; hidden it costs nothing.
	set_process(false)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.10, 0.14), 4))
	centre.add_child(panel)
	var column := InventoryLayout.column(panel)
	var title := HudWidgets.label(TermsText.TITLE, 18, OptionsPanel.HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_wrapped(TermsText.SUBTITLE, 12, HudWidgets.CAPTION))

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.selection_enabled = true
	body.focus_mode = Control.FOCUS_ALL
	body.custom_minimum_size = Vector2(WIDTH - 24, BODY_HEIGHT)
	body.add_theme_font_size_override("normal_font_size", 13)
	body.add_theme_font_size_override("bold_font_size", 13)
	body.add_theme_stylebox_override("normal", _box(Color(0.05, 0.04, 0.06), 8))
	body.text = TermsText.BODY
	column.add_child(body)

	hint = HudWidgets.label(TermsText.SCROLL_HINT, 12, PlayerHud.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	decline_button = InventoryLayout.button(buttons, "Decline & Log Out", answer.bind(false))
	agree_button = InventoryLayout.button(buttons, "I Agree", answer.bind(true))
	agree_button.disabled = true


## Shows the terms from the top and waits for a button.
func ask() -> bool:
	visible = true
	set_process(true)
	agree_button.disabled = true
	hint.modulate.a = 1.0
	body.scroll_to_line(0)
	body.grab_focus.call_deferred()
	return await answered


func answer(agreed: bool) -> void:
	if agreed and agree_button.disabled:
		return
	visible = false
	set_process(false)
	answered.emit(agreed)


func _process(_delta: float) -> void:
	if visible and agree_button.disabled and read_to_end():
		agree_button.disabled = false
		# Kept in the layout, as the web's hint keeps its line, so the
		# buttons do not jump when it goes.
		hint.modulate.a = 0.0


## Whether the box is at its end, or has none to scroll to. Nothing laid
## out yet is neither: an empty box must not unlock the button.
func read_to_end() -> bool:
	if body.get_content_height() <= 0 or body.size.y <= 0:
		return false
	var bar := body.get_v_scroll_bar()
	return bar.value + bar.page >= bar.max_value - SLACK_PX


static func _box(colour: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = ItemTooltip.EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(margin)
	return style


## A wrapping label given its width before it enters the tree, or it is
## measured at zero and wraps a character a line.
static func _wrapped(text: String, size: int, colour: Color) -> Label:
	var label := HudWidgets.label(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = WIDTH - 24
	label.size.x = WIDTH - 24
	return label
