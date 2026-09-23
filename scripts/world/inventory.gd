class_name Inventory
extends RefCounted

## What the character is carrying, in the server's slot order.
##
## One flat array, because that is what the wire and every packet that moves
## an item speak: a slot index. MoveItemPacket derives its regions from
## Player.EQUIPMENT_SLOT_COUNT, Player.INVENTORY_SIZE and LootContainer.SIZE,
## which in v0.9.0 come to
##
##   0..4    equipment: weapon, armor, gauntlets, boots, ring
##   5..44   backpack, two pages of twenty
##   45..54  the loot bag at your feet -- not carried, read off the nearest
##           container, but addressed through the same index space
##   55, 56  the HP and MP potion pools, which are counts rather than items
##
## The comment over MoveItemPacket's fields still says 5..24 / 25..34 / 35 /
## 36. It is stale: BACKPACK_SIZE was doubled to 40. The web client's
## constants agree with the derivation, not the comment.

const EQUIPMENT_SLOTS := 5
const BACKPACK_SIZE := 40
const BACKPACK_START := EQUIPMENT_SLOTS
const SIZE := EQUIPMENT_SLOTS + BACKPACK_SIZE
const PAGE_SIZE := 20
const GROUND_LOOT_START := SIZE
const LOOT_SIZE := 10
const HP_POTION_SLOT := GROUND_LOOT_START + LOOT_SIZE
const MP_POTION_SLOT := HP_POTION_SLOT + 1
## Player.MAX_CONSUMABLE_POTIONS.
const MAX_POTIONS := 6
## The server's pickup radius is the player's size plus this, corner to
## corner. The web client mirrors the exact figure because its old guess,
## three quarters of the sprite, sat under it and F never found anything.
const PICKUP_MARGIN := 24

var slots: Array = []
var hp_potions := 0
var mp_potions := 0
var experience := 0
## Bumped on every change, so a panel can redraw only when something moved.
var version := 0


func _init() -> void:
	clear()


func clear() -> void:
	slots = []
	for i in SIZE:
		slots.append({})
	hp_potions = 0
	mp_potions = 0
	experience = 0
	version += 1


## The inventory half of an UpdatePacket. The server sends a fixed-length
## array with an itemId of -1 in every empty slot (NetGameItem's no-arg
## constructor), and a shorter one for other players, whose backpacks are
## stripped before sending -- so anything not mentioned is empty.
func apply_update(data: Dictionary) -> void:
	var wire: Array = data.get("inventory", [])
	for i in SIZE:
		var item: Variant = wire[i] if i < wire.size() else null
		slots[i] = item if holds(item) else {}
	hp_potions = int(data.get("hpPotions", 0))
	mp_potions = int(data.get("mpPotions", 0))
	experience = int(data.get("experience", 0))
	version += 1


## A wire item that is actually something, rather than the -1 placeholder.
static func holds(item: Variant) -> bool:
	return item is Dictionary and not item.is_empty() and int(item.get("itemId", -1)) >= 0


func item_at(index: int) -> Dictionary:
	if index < 0 or index >= SIZE:
		return {}
	return slots[index]


## For scenarios and tests; a live client only ever hears from the server.
func put(index: int, item: Dictionary) -> void:
	slots[index] = item
	version += 1


static func is_equipment(index: int) -> bool:
	return index >= 0 and index < EQUIPMENT_SLOTS


static func is_backpack(index: int) -> bool:
	return index >= BACKPACK_START and index < SIZE


static func is_ground_loot(index: int) -> bool:
	return index >= GROUND_LOOT_START and index < GROUND_LOOT_START + LOOT_SIZE


func first_empty_backpack() -> int:
	for i in range(BACKPACK_START, SIZE):
		if slots[i].is_empty():
			return i
	return -1


## The bag under our feet: the closest container within the server's pickup
## radius. Measured top-left to top-left, as the wire positions are.
static func nearest_loot(entities: EntityRegistry, position: Vector2, size: int) -> Dictionary:
	var found := {}
	var closest := float(size + PICKUP_MARGIN)
	for id in entities.containers:
		var container: Dictionary = entities.containers[id]
		var distance := position.distance_to(entities.render_position(container))
		if distance < closest:
			closest = distance
			found = container
	return found
