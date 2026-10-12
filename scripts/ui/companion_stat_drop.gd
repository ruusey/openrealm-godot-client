class_name CompanionStatDrop
extends PanelContainer

## A visible, labelled drop target for feeding a companion a stat potion: drag one
## from your bag onto this box (it highlights while a draggable item is over it).
## The server validates the item is actually a stat potion that still raises a stat
## (a maxed companion leaves it in your bag), so this just forwards the bag slot.

const IDLE := Color(0.14, 0.17, 0.14, 0.90)
const HOVER := Color(0.20, 0.34, 0.20, 0.95)
const BORDER := Color(0.45, 0.72, 0.45)

var _on_potion: Callable
var _style := StyleBoxFlat.new()


func setup(on_potion: Callable) -> void:
	_on_potion = on_potion


func _ready() -> void:
	_style.set_corner_radius_all(4)
	_style.set_border_width_all(1)
	_style.border_color = BORDER
	_style.bg_color = IDLE
	add_theme_stylebox_override("panel", _style)
	custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = "+  Drop a stat potion here to feed this companion"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok := ItemSlot.is_payload(data)
	_style.bg_color = HOVER if ok else IDLE
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_style.bg_color = IDLE
	if ItemSlot.is_payload(data) and _on_potion.is_valid():
		_on_potion.call(int(data["slot"]))


## Clear the highlight when any drag ends (including one that left this box).
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_style.bg_color = IDLE
