class_name GemCatalog
extends RefCounted

## What each gemstone does, where it fits, and what it does to a shot --
## the server's GemstoneRegistry as the web client's tables spell it
## (game.js GEMSTONE_DESCRIPTIONS, GEM_SOCKET_SLOTS, GEM_SHOT_EFFECTS). The
## names are ForgeRules.GEM_NAMES. Keyed by gemstoneType; 0 is no gem.

const DESCRIPTIONS := {
	1: "Heals 8% of damage dealt on basic attack hits.",
	2: "+15% chance per shot to deal double damage.",
	3: "Splits your basic attack into 2 spread projectiles.",
	4: "Basic attacks poison targets for 4s.",
	5: "Basic attacks slow targets for 2s.",
	6: "Reflects 20% of damage taken back to enemy attackers.",
	7: "+15% basic attack damage.",
	8: "+10% Wisdom while equipped.",
	9: "+10% Speed while equipped.",
	10: "+10% Attack while equipped.",
	11: "+10% Defense while equipped.",
	12: "+10% Dexterity while equipped.",
	13: "+10% Vitality while equipped.",
	14: "+10% Max HP while equipped.",
	15: "+10% Max MP while equipped.",
}
## Gemstone.canSocketInto: equipment slots 0 weapon .. 4 ring. On-hit gems
## are weapon-only; scaling ones fit anywhere; thorns fits the armour.
const SOCKET_SLOTS := {
	1: [0], 2: [0], 3: [0], 4: [0], 5: [0], 6: [1, 2, 3], 7: [0],
	8: [0, 1, 2, 3, 4], 9: [0, 1, 2, 3, 4], 10: [0, 1, 2, 3, 4], 11: [0, 1, 2, 3, 4],
	12: [0, 1, 2, 3, 4], 13: [0, 1, 2, 3, 4], 14: [0, 1, 2, 3, 4], 15: [0, 1, 2, 3, 4],
}
## Gemstone.modifyShot for the gems that change a shot. The scaling gems
## are left out on purpose: their bonus is already in the stats the server
## sends, and counting it here would count it twice.
const SHOT_EFFECTS := {
	2: {"crit_pct": 15},
	3: {"extra_projectiles": 1},
	7: {"damage_pct": 15},
}


static func name_of(gem_type: int) -> String:
	return ForgeRules.GEM_NAMES.get(gem_type, "Gem %d" % gem_type)


static func description(gem_type: int) -> String:
	return DESCRIPTIONS.get(gem_type, "")


## The catalog's socketSlots when the item names them, the table's otherwise.
static func sockets(gem_type: int, definition: Dictionary) -> Array:
	var slots: Array = definition.get("socketSlots", [])
	return slots if not slots.is_empty() else SOCKET_SLOTS.get(gem_type, [])


static func shot_effect(gem_type: int) -> Dictionary:
	return SHOT_EFFECTS.get(gem_type, {})
