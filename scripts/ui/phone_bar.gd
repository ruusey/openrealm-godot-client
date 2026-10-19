class_name PhoneBar
extends CanvasLayer

## Menu, Bag and Chat in a column beside the map (PhoneLayout), in the
## panels' points so they stay level with it at any UI scale.

signal menu
signal bag
signal chat

var _column := VBoxContainer.new()


func _ready() -> void:
	layer = 11
	var labels := ["Menu", "Bag", "Chat"]
	var signals := [menu, bag, chat]
	_column.add_theme_constant_override("separation",
		int((PhoneLayout.MAP_SIDE - PhoneLayout.BUTTON_SIZE.y * labels.size()) / (labels.size() - 1)))
	for i in labels.size():
		var pressed: Signal = signals[i]
		var button := TouchButtons.flat(labels[i], PhoneLayout.BUTTON_SIZE, func() -> void: pressed.emit())
		button.add_theme_font_size_override("font_size", PhoneLayout.BUTTON_FONT)
		_column.add_child(button)
	add_child(_column)
	TouchFrame.adopt(self)


func _process(_delta: float) -> void:
	_column.position = PhoneLayout.buttons_at(TouchScale.view_size(_column))


func captures_mouse() -> bool:
	return visible and _column.get_global_rect().has_point(_column.get_global_mouse_position())
