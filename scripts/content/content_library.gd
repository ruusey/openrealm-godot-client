class_name ContentLibrary
extends RefCounted

## Loads the game-content JSON the server also reads.
##
## Only ids travel on the wire (tileId, enemyId, classId, projectileGroupId),
## so everything visual and every gameplay constant is resolved from here.
## Where it comes from is ContentSource's problem -- the data repo on disk, or
## the data service over HTTP, which is what a web build has to use.

## filename -> destination dictionary key, keyed by the id field in each entry.
const SOURCES := {
	"tiles.json": ["tiles", "tileId"],
	"enemies.json": ["enemies", "enemyId"],
	"character-classes.json": ["classes", "classId"],
	"game-items.json": ["items", "itemId"],
	"weapon-archetypes.json": ["weapon_archetypes", "id"],
	"projectile-groups.json": ["projectile_groups", "projectileGroupId"],
	"portals.json": ["portals", "portalId"],
	"maps.json": ["maps", "mapId"],
	"abilities.json": ["abilities", "id"],
	"passives.json": ["passives", "id"],
	"loot-containers.json": ["loot_containers", "tierId"],
	"dye-assets.json": ["dyes", "dyeId"],
	"character-class-masks.json": ["class_masks", "classId"],
}

var tiles := {}
var enemies := {}
var classes := {}
var items := {}
var weapon_archetypes := {}
var projectile_groups := {}
var portals := {}
## Only the name is read off a map, for the nexus and vault guards.
var maps := {}
var abilities := {}
var passives := {}
## A dropped bag's art by its tier; LootArt reads it.
var loot_containers := {}
var animations := {}   # classId -> player animation set
## A dye by its id, and each class's painted masks of which pixels take one.
var dyes := {}
var class_masks := {}
## itemId -> fame cost; the one content file that is an object, not a list.
var fame_store := {}
## REALM sale-price table (realm-prices.json) for Item Exchange quotes. The game
## server is authoritative on the actual payout; this only drives the estimate
## shown in the list. Defaults apply if the file is absent.
var realm_rarity_mult := [0.25, 1.0, 2.0, 5.0, 12.0, 30.0]
var realm_zero_categories := {}
var realm_tier_base := []
var realm_untiered_base := 800
var realm_default_base := 8
var realm_overrides := {}
## exp-levels.json as it comes: level -> "min-max". ExperienceLevels reads it.
var exp_levels := {}
var errors: Array[String] = []


func load_from(source: ContentSource) -> bool:
	errors.clear()
	var blocked := source.unavailable()
	if blocked != "":
		errors.append(blocked)
		return false

	for filename in SOURCES:
		var target: String = SOURCES[filename][0]
		var id_field: String = SOURCES[filename][1]
		var destination: Dictionary = get(target)
		for entry in await _read_array(source, filename):
			destination[int(entry.get(id_field, -1))] = entry

	var prices: Dictionary = await _read_object(source, "fame-store.json")
	for key in prices:
		fame_store[int(key)] = int(prices[key])
	await _load_realm_prices(source)
	exp_levels = await _read_object(source, "exp-levels.json")
	# Animations are keyed by objectId but only the player sets are useful here.
	for entry in await _read_array(source, "animations.json"):
		if entry.get("objectType", "") == "player":
			animations[int(entry.get("objectId", -1))] = entry

	return errors.is_empty()


## Every sprite sheet the loaded content refers to. SpriteCache reads them up
## front, because a sheet cannot be fetched from inside _draw.
func sheet_keys() -> Array:
	var keys := {}
	for table in [tiles, enemies, classes, items, projectile_groups, portals, animations, abilities,
			loot_containers]:
		for entry in table.values():
			var key: String = entry.get("spriteKey", "")
			if key != "":
				keys[key] = true
	return keys.keys()


func summary() -> String:
	return "%d tiles, %d enemies, %d classes, %d animation sets, %d items, %d projectile groups, %d portals, %d abilities" % [
		tiles.size(), enemies.size(), classes.size(), animations.size(),
		items.size(), projectile_groups.size(), portals.size(), abilities.size(),
	]


## Load the REALM price table. Tolerant: a missing/invalid file leaves defaults
## and does NOT fail the content load (it only affects the estimate quote).
func _load_realm_prices(source: ContentSource) -> void:
	var result: Array = await source.read("realm-prices.json")
	if result[0] != OK:
		return
	var parsed = JSON.parse_string(PackedByteArray(result[1]).get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var mult = parsed.get("rarityMultiplier", {})
	for i in range(realm_rarity_mult.size()):
		if mult.has(str(i)):
			realm_rarity_mult[i] = float(mult[str(i)])
	for cat in parsed.get("zeroCategories", []):
		realm_zero_categories[String(cat)] = true
	var buckets: Array = parsed.get("tierBase", [])
	if not buckets.is_empty():
		realm_tier_base.clear()
		for b in buckets:
			realm_tier_base.append({"max": int(b.get("maxTier", 0)), "realm": int(b.get("realm", 0))})
	realm_untiered_base = int(parsed.get("untieredBase", realm_untiered_base))
	realm_default_base = int(parsed.get("defaultBase", realm_default_base))
	var ov = parsed.get("overrides", {})
	for k in ov:
		realm_overrides[int(k)] = int(ov[k])


## Estimated REALM a backpack item sells for (0 = not cashable). Mirrors the
## server's ServerRealmEconomyHelper.pointsForItem.
func realm_price_for(item: Dictionary) -> int:
	if item == null or item.is_empty():
		return 0
	var id := int(item.get("itemId", -1))
	if realm_overrides.has(id):
		return int(realm_overrides[id])
	if realm_zero_categories.has(String(item.get("category", ""))):
		return 0
	if bool(item.get("consumable", false)) and bool(item.get("stackable", false)):
		return 0
	var base := _realm_base_for_tier(int(item.get("tier", 0)))
	if base <= 0:
		return 0
	var rarity := clampi(int(item.get("rarity", 0)), 0, realm_rarity_mult.size() - 1)
	return int(round(base * realm_rarity_mult[rarity]))


func _realm_base_for_tier(tier: int) -> int:
	if tier < 0:
		return realm_untiered_base
	for b in realm_tier_base:
		if tier <= int(b["max"]):
			return int(b["realm"])
	return int(realm_tier_base[-1]["realm"]) if not realm_tier_base.is_empty() else realm_default_base


## A content file that is one JSON object rather than a list of entries.
func _read_object(source: ContentSource, filename: String) -> Dictionary:
	var result: Array = await source.read(filename)
	if result[0] != OK:
		errors.append("missing content file: %s" % filename)
		return {}
	var parsed = JSON.parse_string(PackedByteArray(result[1]).get_string_from_utf8())
	if not parsed is Dictionary:
		errors.append("%s did not contain a JSON object" % filename)
		return {}
	return parsed


func _read_array(source: ContentSource, filename: String) -> Array:
	var result: Array = await source.read(filename)
	if result[0] != OK:
		errors.append("missing content file: %s" % filename)
		return []
	var parsed = JSON.parse_string(PackedByteArray(result[1]).get_string_from_utf8())
	if not parsed is Array:
		errors.append("%s did not contain a JSON array" % filename)
		return []
	return parsed
