class_name ItemRules
extends RefCounted

## Whether an item may go where the player wants to put it.
##
## A mirror of ServerItemHelper.canEquipInSlot, so a move the server would
## refuse is never sent -- both references check before sending, because the
## server answers a refusal with a log line and nothing the client can see.
## The wire item does not carry itemClass or archetypeId; those are catalog
## fields, looked up by itemId, which is why this needs the content.

const CLASS_NONE := 0
const CLASS_UNIVERSAL := 99
const WEAPON_CLASSES := [1, 2, 3]
const ARMOR_CLASSES := [10, 11, 12]


static func can_equip(item: Dictionary, slot: int, class_id: int, content: GameData) -> bool:
	if not Inventory.holds(item) or not Inventory.is_equipment(slot):
		return false
	# Consumables and stacks are never equipment, whatever their slot says.
	if bool(item.get("consumable", false)) or bool(item.get("stackable", false)):
		return false
	# Strict: a targetSlot of -1 is refused from every slot, not accepted by all.
	if int(item.get("targetSlot", -1)) != slot:
		return false
	return class_allows(class_id, int(item.get("itemId", -1)), content)


## CharacterClass.canEquip: the item's class must be on the character's list,
## and a weapon's archetype too when the class restricts those. An item the
## catalog does not know, or one with no class, is refused -- the server
## fails closed and so do we.
static func class_allows(class_id: int, item_id: int, content: GameData) -> bool:
	if content == null:
		return false
	var definition := content.item_definition(item_id)
	var character: Dictionary = content.library.classes.get(class_id, {})
	var item_class := int(definition.get("itemClass", CLASS_NONE))
	if item_class == CLASS_NONE or character.is_empty():
		return false
	if item_class == CLASS_UNIVERSAL:
		return true
	if item_class in WEAPON_CLASSES:
		if not _lists(character.get("allowedWeaponClasses", []), item_class):
			return false
		var archetypes: Array = character.get("allowedWeaponArchetypes", [])
		# An empty list is "any archetype", not "none".
		return archetypes.is_empty() or _lists(archetypes, int(definition.get("archetypeId", 0)))
	if item_class in ARMOR_CLASSES:
		return _lists(character.get("allowedArmorClasses", []), item_class)
	return false


## JSON numbers parse as floats, so `in` would miss every match.
static func _lists(values: Array, wanted: int) -> bool:
	for value in values:
		if int(value) == wanted:
			return true
	return false
