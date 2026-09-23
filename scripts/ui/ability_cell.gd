class_name AbilityCell
extends PanelContainer

## One cell of the ability bar: the icon, its key, its cost, its skill
## points, and the shade that drains off it while it cools.
##
## The shade is the web client's cooldown overlay: a dark fill from the
## bottom whose height is what is left of the cooldown, so a full cell is a
## cast just made and an empty one is ready. The points are a PipColumn down
## the right edge, as both references draw them.

signal pressed(index: int)
signal secondary(index: int)
signal hovered(index: int, over: bool)

## 64 with a 48px icon: the 16px sprites at an exact 3x, crisp under the
## nearest filter, and big enough to read the pips and the cost from.
const SIZE_PX := 64
const ICON_PX := 48
const SHADE := Color(0.0, 0.0, 0.0, 0.6)
const BACKGROUND := Color(0.12, 0.10, 0.16, 0.95)
const BORDER := Color(0.45, 0.35, 0.55)
const TEXT := Color(0.91, 0.85, 0.72)

## 0 is the passive cell; 1..3 are the hotbar slots 0..2.
var index := 0

var _icon: TextureRect
var _fallback: Label
var _key: Label
var _cost: Label
var _pips: PipColumn
var _shade: ColorRect


func _init(cell_index: int, key_text: String) -> void:
	index = cell_index
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = BORDER
	style.bg_color = BACKGROUND
	add_theme_stylebox_override("panel", style)

	# A plain Control between the panel and its parts, so the parts can be
	# anchored: a container would lay them all out to fill.
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_icon)
	_fallback = _label(body, Control.PRESET_FULL_RECT, 22)
	_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_shade)

	_key = _label(body, Control.PRESET_TOP_LEFT, 13)
	_key.text = key_text
	# Bottom-left, leaving the right edge to the pips.
	_cost = _label(body, Control.PRESET_BOTTOM_LEFT, 12)
	_cost.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	_pips = PipColumn.new(SIZE_PX)
	body.add_child(_pips)

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))


## An active ability, or a passive when `cost` is negative and `cap` zero.
func show_ability(texture: Texture2D, name: String, cost: int, level: int, cap: int) -> void:
	_icon.texture = texture
	# No icon on the sheet: the web client falls back to text in the cell.
	_fallback.text = "" if texture != null else name.left(2)
	_cost.text = str(cost) if cost > 0 else ""
	_pips.show_points(level, cap)


func show_empty() -> void:
	show_ability(null, "", 0, 0, 0)
	_fallback.text = ""


## [lit, total] pips, for anyone checking.
func pips() -> Array:
	return _pips.counts()


## `fraction` is what is left: 1 shades the whole cell, 0 none of it.
func set_cooldown(fraction: float) -> void:
	_shade.anchor_top = 1.0 - clampf(fraction, 0.0, 1.0)
	_shade.offset_top = 0.0


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		secondary.emit(index)


func _label(into: Control, preset: int, size: int) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	# Anchored to a corner, a control grows away from it by default -- a
	# bottom label would hang below the cell. Grow back into it instead.
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]:
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(label)
	return label
