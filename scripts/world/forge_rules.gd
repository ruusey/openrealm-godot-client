class_name ForgeRules
extends RefCounted

## What the forge will and will not do, before anything is sent.
##
## ServerForgeHelper.handleForgeEnchant mirrored, in the order the web
## client reports its problems: the server refuses with a log line and
## nothing the client can see, so every reason is decided here first and
## the first one is what the panel says. A crystal spends one of the item's
## rarity-driven crystal slots; a gem takes the single socket that only Epic
## and Legendary items carry; either costs fifty essence of the item's slot.

## forgeStatId order, the server's STAT_COLORS.
const STAT_LABELS := ["VIT", "WIS", "HP", "MP", "STR", "DEF", "SPD", "DEX"]
## Equipment slots, as an essence's forgeSlotId names them.
const SLOT_LABELS := ["Weapon", "Armor", "Gauntlet", "Boots", "Ring"]
const ESSENCE_COST := 50
## Crystal slots by rarity: Mundane through Legendary.
const CRYSTAL_SLOTS := [0, 1, 2, 3, 4, 5]
const GEM_SOCKET_RARITY := 4
## HP and MP crystals add five, the rest one -- their scale is larger.
const HP_MP_DELTA := 5
const GEM_NAMES := {1: "Vampiric Gem", 2: "Crit Gem", 3: "Multishot Gem", 4: "Venom Gem",
	5: "Frost Gem", 6: "Thorns Gem", 7: "Crushing Gem", 8: "Wisdom Scaling Gem",
	9: "Swift Scaling Gem", 10: "Attack Scaling Gem", 11: "Defense Scaling Gem",
	12: "Dexterity Scaling Gem", 13: "Vitality Scaling Gem", 14: "Health Scaling Gem",
	15: "Mana Scaling Gem"}


static func is_equipment(item: Dictionary) -> bool:
	return Inventory.holds(item) and not bool(item.get("stackable", false)) \
		and Inventory.is_equipment(int(item.get("targetSlot", -1)))


static func is_crystal(item: Dictionary) -> bool:
	return str(item.get("category", "")) == "crystal"


static func is_gem(item: Dictionary) -> bool:
	return str(item.get("category", "")) == "gem"


static func is_essence(item: Dictionary) -> bool:
	return str(item.get("category", "")) == "essence"


static func rarity(item: Dictionary) -> int:
	return clampi(int(item.get("rarity", 0)), 0, CRYSTAL_SLOTS.size() - 1)


static func crystal_cap(item: Dictionary) -> int:
	return CRYSTAL_SLOTS[rarity(item)]


static func has_gem_socket(item: Dictionary) -> bool:
	return rarity(item) >= GEM_SOCKET_RARITY


static func enchantments(item: Dictionary) -> Array:
	return item.get("enchantments", [])


## The slots a gem may go into: the catalog's socketSlots when it has them,
## else the gem's own, else nothing known -- which defers to the server.
static func gem_slots(gem: Dictionary, content: GameData) -> Array:
	var slots: Array = gem.get("socketSlots", [])
	if slots.is_empty() and content != null:
		slots = content.item_definition(int(gem.get("itemId", -1))).get("socketSlots", [])
	return slots


## The first reason the forge would refuse, or "" when it would not.
static func problem(target: Dictionary, crystal: Dictionary, essence: Dictionary,
		content: GameData) -> String:
	if not Inventory.holds(target):
		return "Pick an item."
	var gem := is_gem(crystal)
	if Inventory.holds(crystal) and not gem and enchantments(target).size() >= crystal_cap(target):
		return "Max crystal slots (%d) reached for this rarity." % crystal_cap(target)
	if gem and not has_gem_socket(target):
		return "This rarity has no gem socket (Epic+ only)."
	if gem and int(target.get("gemstoneType", 0)) != 0:
		return "Item already has a gem socketed."
	if gem:
		var slots := gem_slots(crystal, content)
		if not slots.is_empty() and not _lists(slots, int(target.get("targetSlot", -1))):
			return "%s can only socket into: %s." % [crystal.get("name", "That gem"), _slot_names(slots)]
	if not Inventory.holds(crystal):
		return "Pick a Crystal or Gem."
	if not Inventory.holds(essence):
		return "Pick Essence."
	if int(essence.get("forgeSlotId", -1)) != int(target.get("targetSlot", -2)):
		return "Essence type must be %s." % _slot_name(int(target.get("targetSlot", -1)))
	if int(essence.get("stackCount", 0)) < ESSENCE_COST:
		return "Need %d essence (have %d)." % [ESSENCE_COST, int(essence.get("stackCount", 0))]
	return ""


static func can_disenchant(target: Dictionary) -> bool:
	return Inventory.holds(target) \
		and (not enchantments(target).is_empty() or int(target.get("gemstoneType", 0)) != 0)


## "Wood Cloak - Common  Crystal slots: 1/1  Gem: empty"
static func summary(target: Dictionary) -> String:
	var line := "%s - %s   Crystal slots: %d/%d" % [target.get("name", "?"),
		ItemTooltip.RARITY_NAMES[rarity(target)], enchantments(target).size(), crystal_cap(target)]
	if has_gem_socket(target):
		var gem := int(target.get("gemstoneType", 0))
		line += "   Gem: %s" % (GEM_NAMES.get(gem, "socketed") if gem != 0 else "empty")
	return line


## What the cast would forge in: "+1 DEF", "+5 HP", or the gem's name.
static func effect_preview(crystal: Dictionary) -> String:
	if is_gem(crystal):
		return GEM_NAMES.get(int(crystal.get("gemstoneType", 0)), str(crystal.get("name", "Gem")))
	var stat := int(crystal.get("forgeStatId", -1))
	if stat < 0 or stat >= STAT_LABELS.size():
		return "?"
	return "+%d %s" % [HP_MP_DELTA if stat in [2, 3] else 1, STAT_LABELS[stat]]


## One line per crystal already on an item, for its card.
static func enchantment_label(enchantment: Dictionary) -> String:
	var stat := int(enchantment.get("statId", -1))
	var label: String = STAT_LABELS[stat] if stat >= 0 and stat < STAT_LABELS.size() else "?"
	return "+%d %s" % [int(enchantment.get("deltaValue", 0)), label]


static func _slot_name(slot: int) -> String:
	return SLOT_LABELS[slot] if slot >= 0 and slot < SLOT_LABELS.size() else "?"


static func _slot_names(slots: Array) -> String:
	var names := PackedStringArray()
	for slot in slots:
		names.append(_slot_name(int(slot)))
	return ", ".join(names)


static func _lists(values: Array, wanted: int) -> bool:
	for value in values:
		if int(value) == wanted:
			return true
	return false
