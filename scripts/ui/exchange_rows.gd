class_name ExchangeRows
extends RefCounted

## The rows of the exchange market's two columns: an icon, the item's name
## as a button that stays down while chosen, and a count on the give side.

const ICON_PX := 32
const LIST_HEIGHT := 220.0


## A titled, scrolling column; returns the list rows go into.
static func column(into: Container, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(box)
	InventoryLayout.heading(box, title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list


## Rebuilds `list` with a row per id; returns [{item_id, button}].
static func fill(list: VBoxContainer, content: GameData, ids: Array, chosen: int,
		tooltip: ItemTooltip, anchor: Control, count_for: Callable, on_pick: Callable) -> Array:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var rows: Array = []
	for item_id in ids:
		var definition := content.item_definition(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_entered.connect(func() -> void: tooltip.show_for(definition, anchor.get_global_mouse_position()))
		row.mouse_exited.connect(tooltip.hide_card)
		list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = content.item_texture(item_id)
		row.add_child(icon)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = item_id == chosen
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count: String = count_for.call(item_id)
		button.text = content.item_name(item_id) + ("   " + count if count != "" else "")
		button.pressed.connect(func() -> void: on_pick.call(item_id))
		row.add_child(button)
		rows.append({"item_id": item_id, "button": button})
	return rows


## A line in place of rows when there are none.
static func empty_note(list: VBoxContainer, rows: Array, text: String) -> void:
	if rows.is_empty():
		InventoryLayout.heading(list, text)
