class_name LootRow
extends Button

## One item in the loot window: its icon, its name in its rarity's colour,
## and the stack. The whole row is the button -- a thumb's width on a phone,
## a click on a desktop -- and a press takes the item.

const HEIGHT := 52.0
const ICON_PX := 40.0
const FONT_SIZE := 18

signal hovered(index: int, over: bool)

## Which of the bag's slots this row is.
var index := -1

var _icon: TextureRect
var _name: Label
var _count: Label


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	focus_mode = Control.FOCUS_NONE
	for look in ["normal", "hover", "pressed", "focus"]:
		var fill := Color(0.22, 0.2, 0.26) if look in ["hover", "pressed"] else Color(0.13, 0.12, 0.16)
		add_theme_stylebox_override(look, LootWindow.box(fill, Color(0.35, 0.32, 0.4)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_name = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long name is cut short rather than widening the window.
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_name)
	_count = _label(HORIZONTAL_ALIGNMENT_RIGHT)
	_count.custom_minimum_size.x = 48.0
	row.add_child(_count)
	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))


func show_item(slot: int, item: Dictionary, content: GameData) -> void:
	index = slot
	var id := int(item.get("itemId", -1))
	_icon.texture = content.item_texture(id) if content != null else null
	_name.text = str(item.get("name", content.item_name(id) if content != null else "Item %d" % id))
	_name.add_theme_color_override("font_color", ItemTooltip.RARITY_COLOURS[ForgeRules.rarity(item)])
	var stack := int(item.get("stackCount", 1))
	_count.text = "x%d" % stack if bool(item.get("stackable", false)) and stack > 1 else ""


func item_name() -> String:
	return _name.text


func _label(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
