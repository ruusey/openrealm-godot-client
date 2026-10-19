class_name PhoneMenu
extends CanvasLayer

## What the phone's Menu opens: every panel in one grid of big buttons
## over a dim that closes it on a tap. An item is [label, open] or
## [label, open, shown], `shown` asked each time the menu opens.

const COLUMNS := 3
const BUTTON_SIZE := Vector2(140.0, 44.0)
const FONT_SIZE := 15
const DIM := Color(0.0, 0.0, 0.0, 0.6)

var _grid := GridContainer.new()
var _items: Array = []


func _ready() -> void:
	layer = 13
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var column := InventoryLayout.column(panel)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := HudWidgets.label("Menu", FONT_SIZE + 2, PlayerHud.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := _button("Close", close)
	close_button.custom_minimum_size.x = 0.0
	heading.add_child(close_button)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_grid)
	TouchFrame.adopt(self)


func set_items(items: Array) -> void:
	_items = items
	for child in _grid.get_children():
		child.free()
	for item in items:
		var open: Callable = item[1]
		_grid.add_child(_button(item[0], func() -> void:
			close()
			open.call()))


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	for i in _items.size():
		var item: Array = _items[i]
		_grid.get_child(i).visible = item.size() < 3 or (item[2] as Callable).call()
	visible = true


func close() -> void:
	visible = false


func count() -> int:
	return _grid.get_child_count()


func item(index: int) -> Button:
	return _grid.get_child(index)


## Open, it covers the screen: every tap is the menu's.
func captures_mouse() -> bool:
	return visible


func _button(label: String, pressed: Callable) -> Button:
	var button := TouchButtons.flat(label, BUTTON_SIZE, pressed)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button
