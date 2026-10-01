class_name MapCatalog
extends RefCounted

## What kind of map a mapId names.
##
## LoadMapPacket carries the id and nothing else, and the two transition
## guards -- do not re-enter the nexus, do not re-enter the vault -- need to
## know what is behind it. Both references answer this by id and both have
## dated differently: the native still calls the vault 1 and the nexus 29,
## the web client hardcodes 30 for the vault and reads the *name* for the
## nexus. The content we run numbers them 30 and 31. The names have not moved,
## so this asks maps.json rather than carrying a third set of numbers.

var _library: ContentLibrary


func _init(library: ContentLibrary) -> void:
	_library = library


func name(map_id: int) -> String:
	return _library.maps.get(map_id, {}).get("mapName", "")


## Data-driven on-screen tips for a static map: an array of
## {x, y, width, height, header, text, once} rects (world px). Empty when a map
## defines none. The client shows the tip while the player stands in the rect.
func triggers(map_id: int) -> Array:
	var list: Variant = _library.maps.get(map_id, {}).get("dialogueTriggers", [])
	return list if list is Array else []


func is_nexus(map_id: int) -> bool:
	return name(map_id).begins_with("Nexus")


func is_vault(map_id: int) -> bool:
	return name(map_id).begins_with("Vault")


func is_tutorial(map_id: int) -> bool:
	return name(map_id).begins_with("Tutorial")
