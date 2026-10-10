class_name CompanionEquipSlot
extends ItemSlot

## A companion's equipment cell. Reuses ItemSlot for display and for accepting
## a bag item dropped on it, but is NOT draggable out and always fires `dropped`
## on a drop (ItemSlot suppresses it when the source and target indices match —
## a companion slot 0-4 collides with the bag's own equipment indices). Unequip
## is a double-click instead, so a drag can never be misread as a bag move.

func _get_drag_data(_at: Vector2) -> Variant:
	return null


func _drop_data(_at: Vector2, data: Variant) -> void:
	if is_payload(data):
		dropped.emit(int(data["slot"]), index)
