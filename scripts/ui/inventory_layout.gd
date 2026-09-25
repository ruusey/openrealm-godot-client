class_name InventoryLayout
extends RefCounted

## The widgets of the bag, built from Godot's own controls.
##
## Construction only. The panel owns the state and wires the gestures; this
## knows what a heading, a grid of slots or a potion button looks like, so
## that file stays about what the bag shows rather than how it is laid out.

## A drop on the panel's own background is a change of mind, not a throw:
## accepted, so that the drag counts as successful, and then ignored.
class DropSink extends PanelContainer:
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return ItemSlot.is_payload(data)

	func _drop_data(_at: Vector2, _data: Variant) -> void:
		pass

const MARGIN := 8
const PADDING := 10
const COLUMNS := 5
const CAPTIONS := ["Wpn", "Arm", "Gnt", "Bts", "Rng"]
const HEADING_COLOUR := Color(0.7, 0.7, 0.75)


## The frame, on the left edge and growing right to fit; the panel sets its
## top under the left column. The same place on a desktop and a phone, so
## the right side is the map and stats on one and Attack on the other.
static func root(into: Node) -> DropSink:
	var frame := DropSink.new()
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.grow_horizontal = Control.GROW_DIRECTION_END
	frame.offset_left = MARGIN
	frame.offset_right = MARGIN
	into.add_child(frame)
	return frame


## The column everything stacks in, padded from the frame's edge.
static func column(frame: Container) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	frame.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	return stack


static func heading(into: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", HEADING_COLOUR)
	into.add_child(label)
	return label


## The five equipment cells, each captioned underneath.
static func gear_row(into: Container) -> Array:
	var row := HBoxContainer.new()
	into.add_child(row)
	var slots: Array = []
	for i in Inventory.EQUIPMENT_SLOTS:
		var cell := VBoxContainer.new()
		var slot := ItemSlot.new(i, true)
		cell.add_child(slot)
		heading(cell, CAPTIONS[i]).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cell)
		slots.append(slot)
	return slots


## A heading with a button per backpack page at its right.
static func page_bar(into: Container, pages: int, on_page: Callable) -> Array:
	var bar := HBoxContainer.new()
	into.add_child(bar)
	heading(bar, "Backpack").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tabs: Array = []
	for p in pages:
		var tab := Button.new()
		tab.text = str(p + 1)
		tab.toggle_mode = true
		tab.pressed.connect(on_page.bind(p))
		bar.add_child(tab)
		tabs.append(tab)
	return tabs


## Cells `columns` across, indexed from `first_index` in reading order.
static func grid(into: Container, count: int, first_index: int, columns := COLUMNS) -> Array:
	var cells := GridContainer.new()
	cells.columns = columns
	into.add_child(cells)
	var slots: Array = []
	for i in count:
		var slot := ItemSlot.new(first_index + i)
		cells.add_child(slot)
		slots.append(slot)
	return slots


## One captioned cell -- an equipment-styled slot with its name under it.
static func captioned_slot(into: Container, index: int, caption: String) -> ItemSlot:
	var cell := VBoxContainer.new()
	into.add_child(cell)
	var slot := ItemSlot.new(index, true)
	cell.add_child(slot)
	heading(cell, caption).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return slot


static func button(into: Container, text: String, on_press: Callable) -> Button:
	var pressed := Button.new()
	pressed.text = text
	pressed.pressed.connect(on_press)
	into.add_child(pressed)
	return pressed


## The potion pools are counts, not items: a button that drinks one.
static func potion(into: Container, on_drink: Callable) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_drink)
	into.add_child(button)
	return button
