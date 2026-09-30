class_name ForgeBench
extends RefCounted

## The forge as the server opened it, and the three bag slots laid on it.
##
## Nothing is moved onto the bench: each zone remembers which bag slot the
## player dropped there, and the items stay in the bag until the server
## forges them. A zone whose slot has since emptied -- the crystal the last
## forge consumed -- is let go on the next look.

const ZONES := ["target", "crystal", "essence"]
const NONE := -1

var is_open := false
var version := 0
var slots := {"target": NONE, "crystal": NONE, "essence": NONE}
## The pixel the player picked for the next mount, or (-1, -1) for none (the
## enchant then falls back to the first free pixel). Set by the forge's picker.
var selected_pixel := Vector2i(-1, -1)


func clear() -> void:
	is_open = false
	for zone in ZONES:
		slots[zone] = NONE
	selected_pixel = Vector2i(-1, -1)
	version += 1


func apply_open(data: Dictionary, local_id: int) -> void:
	if int(data.get("playerId", 0)) != local_id:
		return
	is_open = true
	version += 1


func close() -> void:
	is_open = false
	selected_pixel = Vector2i(-1, -1)
	version += 1


func assign(zone: String, bag_index: int) -> void:
	slots[zone] = bag_index
	version += 1


func unassign(zone: String) -> void:
	assign(zone, NONE)


func index_of(zone: String) -> int:
	return int(slots.get(zone, NONE))


## The item on a zone, read from the bag right now.
func item_on(zone: String, inventory: Inventory) -> Dictionary:
	return inventory.item_at(index_of(zone))


## Drops any zone whose bag slot no longer holds a thing.
func prune(inventory: Inventory) -> void:
	for zone in ZONES:
		if index_of(zone) != NONE and not Inventory.holds(inventory.item_at(index_of(zone))):
			unassign(zone)
