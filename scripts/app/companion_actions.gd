class_name CompanionActions
extends RefCounted

## What the companion panel sends: one CompanionActionPacket per change, the
## server authoritative. Action ids match the server's ServerCompanionHelper.

const CREATE := 0
const DELETE := 1
const DEPLOY := 2
const RECALL := 3
const EQUIP := 4
const UNEQUIP := 5
const INVEST := 6
const RENAME := 7
const SUMMON_ALL := 8
const CONSUME_POTION := 9
const RETRIEVE := 10
const BUY_SLOT := 11

var client: OpenRealmClient


func _init(net_client: OpenRealmClient) -> void:
	client = net_client


func create(class_id: int) -> void:
	_send(CREATE, "", class_id, 0, "")


func delete(uuid: String) -> void:
	_send(DELETE, uuid, 0, 0, "")


func deploy(uuid: String) -> void:
	_send(DEPLOY, uuid, 0, 0, "")


func recall(uuid: String) -> void:
	_send(RECALL, uuid, 0, 0, "")


## Equip the player's inventory item at `inventory_slot` into the companion's
## equipment `companion_slot` (0-4).
func equip(uuid: String, inventory_slot: int, companion_slot: int) -> void:
	_send(EQUIP, uuid, inventory_slot, companion_slot, "")


func unequip(uuid: String, companion_slot: int) -> void:
	_send(UNEQUIP, uuid, companion_slot, 0, "")


func invest(uuid: String, ability_id: int) -> void:
	_send(INVEST, uuid, ability_id, 0, "")


func rename(uuid: String, new_name: String) -> void:
	_send(RENAME, uuid, 0, 0, new_name)


## Teleport every deployed companion to the player — a last-resort unstick.
func summon_all() -> void:
	_send(SUMMON_ALL, "", 0, 0, "")


## Feed a stat potion from your bag (`inventory_slot`) to the companion. The
## server consumes it only if it still raises a stat (no-op if maxed).
func consume_potion(uuid: String, inventory_slot: int) -> void:
	_send(CONSUME_POTION, uuid, inventory_slot, 0, "")


## Pull an item out of the companion's backpack (`backpack_slot`, 5-44) into your bag.
func retrieve(uuid: String, backpack_slot: int) -> void:
	_send(RETRIEVE, uuid, backpack_slot, 0, "")


## Buy one more owned-roster slot for fame; the server validates fame + the 20 cap.
func buy_slot() -> void:
	_send(BUY_SLOT, "", 0, 0, "")


func _send(action: int, uuid: String, arg1: int, arg2: int, text: String) -> void:
	if client == null or not client.is_in_game():
		return
	client.send("CompanionActionPacket", {
		"action": action, "companionUuid": uuid, "arg1": arg1, "arg2": arg2, "text": text,
	})
