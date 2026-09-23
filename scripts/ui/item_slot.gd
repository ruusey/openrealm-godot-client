class_name ItemSlot
extends PanelContainer

## One cell of the bag: an icon, a stack count, and the gestures on it.
##
## Godot's own drag-and-drop carries the move. `_get_drag_data` starts one
## with the slot index as its payload, any other slot accepts it, and the
## drop hands both indices up. A drag that ends on nothing is the web
## client's "dropped on the game canvas", which throws the item on the ground
## -- so the panel behind the slots accepts drops too and swallows them, or a
## clumsy release inside the panel would be a throw.

signal dropped(from_index: int, to_index: int)
signal activated(index: int)
signal secondary(index: int, split: bool)
signal thrown(index: int)
signal hovered(index: int, over: bool)

const SIZE_PX := 40
const ICON_PX := 32
const EMPTY := Color(0.10, 0.10, 0.12, 0.85)
const FILLED := Color(0.16, 0.16, 0.20, 0.95)
const BORDER := Color(0.35, 0.35, 0.40)
const EQUIPMENT_BORDER := Color(0.65, 0.55, 0.25)

## Rewritten on a page switch: the twenty backpack cells stand for whichever
## page is showing, so handlers read this rather than what they were built with.
var index := 0
var item := {}

var _icon: TextureRect
var _count: Label
var _style := StyleBoxFlat.new()
var _dragging := false


func _init(slot_index: int, equipment := false) -> void:
	index = slot_index
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_style.set_corner_radius_all(3)
	_style.set_border_width_all(1)
	_style.border_color = EQUIPMENT_BORDER if equipment else BORDER
	_style.bg_color = EMPTY
	add_theme_stylebox_override("panel", _style)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override("font_size", 10)
	_count.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 3)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))


func show_item(new_item: Dictionary, texture: Texture2D) -> void:
	item = new_item
	var held := Inventory.holds(item)
	_icon.texture = texture if held else null
	_style.bg_color = FILLED if held else EMPTY
	var count := int(item.get("stackCount", 1)) if held else 0
	_count.text = "x%d" % count if bool(item.get("stackable", false)) and count > 1 else ""


## The icon comes off the catalog by id; without content there is none.
func show_from(item: Dictionary, content: GameData) -> void:
	var texture: Texture2D = null
	if content != null and Inventory.holds(item):
		texture = content.item_texture(int(item.get("itemId", -1)))
	show_item(item, texture)


## What a drag from here carries: nothing from an empty cell.
func drag_payload() -> Variant:
	return {"slot": index} if Inventory.holds(item) else null


static func is_payload(data: Variant) -> bool:
	return data is Dictionary and data.has("slot")


func _get_drag_data(_at: Vector2) -> Variant:
	var payload: Variant = drag_payload()
	if payload == null:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	_dragging = true
	return payload


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return is_payload(data)


func _drop_data(_at: Vector2, data: Variant) -> void:
	if int(data["slot"]) != index:
		dropped.emit(int(data["slot"]), index)


## A drag of ours that no control accepted ended over the world.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if not is_drag_successful():
			thrown.emit(index)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		activated.emit(index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		secondary.emit(index, event.shift_pressed)
