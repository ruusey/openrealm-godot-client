class_name ExchangeMarket
extends RefCounted

## The exchange market: hand in N of one consumable, get another of the
## same kind. One given is the market's tax; the rest convert by each item's
## exchangeValue (default 1), so equal-worth items trade N for N-1 and the
## smallest trade is two for one.
##
## Which items are of a kind is the server's rule (ServerExchangeMarketHelper,
## which both references copy so their lists only offer legal swaps): a
## shard, a crystal or an essence swaps within its category, and a stackable
## consumable of the generic category -- the stat potions, never the heal
## potions -- swaps with the others of those. The server re-checks every
## request and answers with a SYSTEM line and an inventory update; nothing
## here changes the bag.

const MIN_QUANTITY := 2
const CATEGORIES := ["shard", "crystal", "essence"]
const STAT_POTION := "stat_potion"

var is_open := false
var version := 0
## The item given, the item received (ids, -1 for none) and how many given.
var source := -1
var target := -1
var quantity := MIN_QUANTITY


func clear() -> void:
	is_open = false
	_reset_choice()
	version += 1


func apply_open(data: Dictionary, local_id: int) -> void:
	if int(data.get("playerId", 0)) != local_id:
		return
	is_open = true
	_reset_choice()
	version += 1


func close() -> void:
	is_open = false
	version += 1


## The kind an item swaps within, or "" when it cannot be exchanged.
static func group_key(definition: Dictionary) -> String:
	var category := String(definition.get("category", ""))
	if category in CATEGORIES:
		return category
	if category == "generic" and bool(definition.get("consumable", false)) \
			and bool(definition.get("stackable", false)):
		return STAT_POTION
	return ""


## What could be given: item id to how many are held, counted across the
## backpack only -- not the equipment, not the loot at your feet -- for
## every exchangeable item, which is the server's countOwned.
static func owned(inventory: Inventory, content: GameData) -> Dictionary:
	var counts := {}
	if content == null:
		return counts
	for index in range(Inventory.BACKPACK_START, Inventory.SIZE):
		var item := inventory.item_at(index)
		if not Inventory.holds(item):
			continue
		var item_id := int(item.get("itemId", -1))
		if group_key(content.item_definition(item_id)) == "":
			continue
		var held: int = int(item.get("stackCount", 1)) if bool(item.get("stackable", false)) else 1
		counts[item_id] = int(counts.get(item_id, 0)) + held
	return counts


## What could be received for `item_id`: the other items of its kind, by id.
static func members(content: GameData, item_id: int) -> Array:
	var out: Array = []
	if content == null:
		return out
	var group := group_key(content.item_definition(item_id))
	if group == "":
		return out
	for other_id in content.items:
		if int(other_id) != item_id and group_key(content.items[other_id]) == group:
			out.append(int(other_id))
	out.sort()
	return out


## Picking what to give drops what was to be received, since it may no
## longer be of a kind, and clamps the quantity to what is held.
func select_source(item_id: int, held: int) -> void:
	source = item_id
	target = -1
	set_quantity(quantity, held)


func select_target(item_id: int) -> void:
	target = item_id
	version += 1


## Never under two, never over what is held -- and two when nothing is,
## so the counter reads sensibly with nothing chosen.
func set_quantity(wanted: int, held: int) -> void:
	quantity = clampi(wanted, MIN_QUANTITY, maxi(MIN_QUANTITY, held))
	version += 1


## Whether a request could be sent: both sides chosen and enough held.
func ready(held: int) -> bool:
	return source >= 0 and target >= 0 and held >= MIN_QUANTITY and quantity <= held


## An item's worth within its kind -- the server's exchangeValue.
static func value_of(definition: Dictionary) -> int:
	return maxi(1, int(definition.get("exchangeValue", 1)))


## What comes back for a quantity given, at the two items' worths.
static func output(given: int, source_value := 1, target_value := 1) -> int:
	return (given - 1) * source_value / target_value


## The smallest hand-in that returns at least one.
static func minimum(source_value: int, target_value: int) -> int:
	return maxi(MIN_QUANTITY, 1 + ceili(float(target_value) / source_value))


## What the current choice returns.
func received(content: GameData) -> int:
	if content == null or source < 0 or target < 0:
		return 0
	return output(quantity, value_of(content.item_definition(source)),
		value_of(content.item_definition(target)))


func _reset_choice() -> void:
	source = -1
	target = -1
	quantity = MIN_QUANTITY
