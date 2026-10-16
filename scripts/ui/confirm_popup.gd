class_name ConfirmPopup
extends CanvasLayer

## A small reusable yes/no modal: a message and two buttons, centered over
## everything. request() shows it and remembers the callback to fire on confirm;
## a second request while one stands is ignored so a held key can't stack dialogs.
## Mirrors TutorialExitConfirm's look so confirmations read the same everywhere.

var _root: PanelContainer
var _message: Label
var _confirm_button: Button
var _on_confirm: Callable
var _showing := false


func _ready() -> void:
	layer = 18
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171f")
	style.border_color = Color("8a6d3b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_root.add_theme_stylebox_override("panel", style)
	centre.add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)
	_message = HudWidgets.label("", 15, Color("f0d890"))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 268
	column.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_confirm_button = InventoryLayout.button(buttons, "Confirm", func() -> void: _answer(true))
	InventoryLayout.button(buttons, "Cancel", func() -> void: _answer(false))


## Show the prompt with `message`, a confirm button reading `confirm_label`, and
## the action to run if the player confirms.
func request(message: String, confirm_label: String, on_confirm: Callable) -> void:
	if _showing:
		return
	_showing = true
	_message.text = message
	_confirm_button.text = confirm_label
	_on_confirm = on_confirm
	visible = true


func _answer(confirmed: bool) -> void:
	if not _showing:
		return
	_showing = false
	visible = false
	if confirmed and _on_confirm.is_valid():
		_on_confirm.call()


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
