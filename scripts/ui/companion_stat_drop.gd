class_name CompanionStatDrop
extends PanelContainer

## A companion's stat line that doubles as a drop target: drag a stat potion
## from your bag onto it to feed the companion. The server validates that the
## dropped item is actually a stat potion and that it still raises a stat (a
## maxed companion leaves it in your bag), so this just forwards the bag slot.

var _on_potion: Callable


func setup(on_potion: Callable) -> void:
	_on_potion = on_potion


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return ItemSlot.is_payload(data)


func _drop_data(_at: Vector2, data: Variant) -> void:
	if ItemSlot.is_payload(data) and _on_potion.is_valid():
		_on_potion.call(int(data["slot"]))
