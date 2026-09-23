class_name FameStore
extends RefCounted

## What the fame store says when it opens: your balance.
##
## The catalogue is content -- `fame-store.json`, item id to cost -- and the
## server reads the same file, so the prices shown are the prices charged.
## A purchase is answered with a fresh balance, or with a SYSTEM line in the
## chat saying why not; the server is the only one that spends.

var balance := 0
var is_open := false
var version := 0


func clear() -> void:
	balance = 0
	is_open = false
	version += 1


func apply_open(data: Dictionary, local_id: int) -> void:
	if int(data.get("playerId", 0)) != local_id:
		return
	balance = int(data.get("accountFame", 0))
	is_open = true
	version += 1


func close() -> void:
	is_open = false
	version += 1


func can_afford(cost: int) -> bool:
	return cost > 0 and balance >= cost


## [item id, cost] pairs, cheapest first and then by id -- the web client's
## order -- for every catalogue entry the item table actually knows.
static func catalogue(content: GameData) -> Array:
	var out: Array = []
	if content == null:
		return out
	for item_id in content.library.fame_store:
		if not content.item_definition(item_id).is_empty():
			out.append([item_id, int(content.library.fame_store[item_id])])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] if a[1] != b[1] else a[0] < b[0])
	return out
