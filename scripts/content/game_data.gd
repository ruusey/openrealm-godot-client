class_name GameData
extends RefCounted

## Resolves wire ids into sprites and gameplay definitions: a thin facade over
## ContentLibrary (the JSON) and SpriteCache (the atlases).

const DEFAULT_TILE_SPRITE_SIZE := SpriteCache.DEFAULT_SPRITE_SIZE
const TILE_RENDER_SIZE := 32

var library := ContentLibrary.new()
var sprites := SpriteCache.new()
## Class artwork, which is involved enough to live on its own.
var classes_art := ClassSprites.new(library, sprites)
## Per-group projectile attributes: the art's rotation offset and its spin.
var projectiles_art := ProjectileArt.new(library)
## A portal's art and name, which only its portalId carries on the wire.
var portals := PortalCatalog.new(library, sprites)
## Which map a mapId names, for the transition guards.
var maps := MapCatalog.new(library)
## What each class casts, and what a cast costs.
var abilities := AbilityCatalog.new(library, sprites)
## What experience means: level, and fame past the last level.
var levels := ExperienceLevels.new()
var ready := false


## Content first, then every sheet it refers to. Awaited, because over HTTP
## both are requests; against the data repo on disk neither suspends, so the
## desktop path stays effectively synchronous through the same call.
func load_from(source: ContentSource) -> bool:
	var loaded: bool = await library.load_from(source)
	levels.parse(library.exp_levels)
	await sprites.preload_sheets(source, library.sheet_keys())
	ready = true
	return loaded


func summary() -> String:
	return library.summary()


## Content-load problems plus any sprite sheet that turned out to be missing.
var errors: Array[String]:
	get:
		var all: Array[String] = []
		all.append_array(library.errors)
		all.append_array(sprites.errors)
		return all

var tiles: Dictionary:
	get: return library.tiles
var enemies: Dictionary:
	get: return library.enemies
var items: Dictionary:
	get: return library.items
var projectile_groups: Dictionary:
	get: return library.projectile_groups


# --- tiles -----------------------------------------------------------------

func tile_texture(tile_id: int) -> AtlasTexture:
	return sprites.atlas_for(library.tiles.get(tile_id, {}))


## How tall to draw this tile, in world pixels. Wall art is 8x16: the upper
## square is the top face and the lower one the front face, so it draws two
## cells tall anchored at the cell top and spills south over the floor below.
## Drawing it one cell tall shows only the top face.
func tile_render_height(tile_id: int) -> float:
	var definition: Dictionary = library.tiles.get(tile_id, {})
	var size := int(definition.get("spriteSize", DEFAULT_TILE_SPRITE_SIZE))
	var height := int(definition.get("spriteHeight", 0))
	if size <= 0 or height <= size:
		return float(TILE_RENDER_SIZE)
	return TILE_RENDER_SIZE * (float(height) / float(size))


## The square top face of a tall wall, or null for anything else. Redrawn
## above the entities so a character behind the wall is covered by it while
## one standing in front of its south-spilling face is not.
func tile_top_face(tile_id: int) -> AtlasTexture:
	return sprites.top_face_for(library.tiles.get(tile_id, {}), DEFAULT_TILE_SPRITE_SIZE)


func tile_data(tile_id: int) -> Dictionary:
	return library.tiles.get(tile_id, {}).get("data", {})


func tile_has_collision(tile_id: int) -> bool:
	return int(tile_data(tile_id).get("hasCollision", 0)) != 0


func tile_slows(tile_id: int) -> bool:
	return int(tile_data(tile_id).get("slows", 0)) != 0


func tile_is_wall(tile_id: int) -> bool:
	return int(tile_data(tile_id).get("isWall", 0)) != 0


func tile_name(tile_id: int) -> String:
	return library.tiles.get(tile_id, {}).get("name", "Unknown_%d" % tile_id)


# --- entities --------------------------------------------------------------

func enemy_texture(enemy_id: int) -> AtlasTexture:
	return sprites.atlas_for(library.enemies.get(enemy_id, {}))


func enemy_name(enemy_id: int) -> String:
	return library.enemies.get(enemy_id, {}).get("name", "Enemy_%d" % enemy_id)


func projectile_texture(group_id: int) -> AtlasTexture:
	return sprites.atlas_for(library.projectile_groups.get(group_id, {}))


## The projectiles a group fires, with angles resolved from their string form.
func projectiles_in_group(group_id: int) -> Array:
	var out: Array = []
	for definition in library.projectile_groups.get(group_id, {}).get("projectiles", []):
		var resolved: Dictionary = definition.duplicate()
		resolved["angle"] = ProjectileAngle.parse(definition.get("angle", 0))
		out.append(resolved)
	return out


func item_projectile_group(item_id: int) -> int:
	return int(library.items.get(item_id, {}).get("damage", {}).get("projectileGroupId", 0))


func item_name(item_id: int) -> String:
	return library.items.get(item_id, {}).get("name", "Item_%d" % item_id)


## The catalog entry behind a wire item: itemClass, archetypeId and the art
## travel by itemId, not on the item itself.
func item_definition(item_id: int) -> Dictionary:
	return library.items.get(item_id, {})


## Item art defaults to 8px cells, as the web client's `spriteSize || 8`.
func item_texture(item_id: int) -> AtlasTexture:
	return sprites.atlas_for(library.items.get(item_id, {}))


## Archetypes drive the multi-shot fan, spread, range and piercing the server
## applies, so a predicted shot has to read the same numbers.
func archetype_for_item(item_id: int) -> Dictionary:
	var archetype_id := int(library.items.get(item_id, {}).get("archetypeId", 0))
	return library.weapon_archetypes.get(archetype_id, {})
