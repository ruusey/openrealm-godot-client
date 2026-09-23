class_name MinimapState
extends RefCounted

## The realm from above: one pixel a tile, everyone in it, and the events on it.
##
## Three feeds, none of them the ones the world is drawn from:
##
##   apply_load_map()          paints the tiles a chunk carried, once
##                             TileMapState has them, into an Image the
##                             panel uploads when `version` moves
##   apply_global_positions()  GlobalPlayerPositionPacket, every player in
##                             the realm whenever any of them moved
##   apply_text()              EVENT_MARKER lines, a minimap payload in a
##                             chat packet's clothes: where a realm event's
##                             boss stands, re-sent every three seconds --
##                             and the SYSTEM line that answers an admin's
##                             /hop, which turns a click into a teleport
##
## The web client's minimap.js keeps the same three (tileImage,
## minimapPlayers, eventMarkers); the native's Minimap rebuilds its pixmap
## from the whole tile grid instead, which is why it needs a dirty flag.

const COLLISION_LAYER := GameConstants.COLLISION_LAYER
## A pin the server has not refreshed for this long is gone: two missed
## broadcasts, the web client's guard against a REMOVE that never arrived.
const MARKER_STALE_MS := 8000
## What the server answers a bare /hop with, then "ON" or "OFF". Both
## references read the same prefix off a SYSTEM line.
const HOP_REPLY := "Hop mode: "

## Null until a map with a size has been sent.
var image: Image
var width := 0
var height := 0
## Moves on every paint and every clear, so the panel re-uploads the
## texture only when the picture changed.
var version := 0
## [{id, name, position, teleportable}], the whole realm, ourselves included.
var players: Array = []
## Boss pins by boss id: {event_id, position, name, seen_ms}.
var markers := {}
## The realm as RealmPurificationPacket describes it: {progress, goal,
## difficulty, tier, modifiers}, empty until one arrives.
var realm := {}
## Admin hop mode: a click on the map sends `/hop x y`. The server keeps it
## on the player, not the realm, so a realm change leaves it as it was and
## only a new session starts it off.
var hop := false

var _content: GameData
var _clock: Callable


func _init(content: GameData = null,
		clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	_content = content
	_clock = clock


## The session is over: everything, hop mode included.
func clear() -> void:
	clear_realm()
	hop = false


## A new realm: its picture, its players, its pins.
func clear_realm() -> void:
	image = null
	width = 0
	height = 0
	players.clear()
	markers.clear()
	realm.clear()
	version += 1


## Paints what a LoadMapPacket carried. `changed` is TileMapState's verdict on
## whether this is a different place: a new picture, rather than more of the
## same one -- and it is a verdict rather than a size comparison because a
## dungeon can be the size of the realm it was assembled in, which is the
## case the web client's minimap.reset() comment records getting wrong.
func apply_load_map(data: Dictionary, tiles: TileMapState, changed: bool) -> void:
	var incoming_width := int(data.get("mapWidth", 0))
	var incoming_height := int(data.get("mapHeight", 0))
	if incoming_width <= 0 or incoming_height <= 0:
		return
	if image == null or changed or incoming_width != width or incoming_height != height:
		width = incoming_width
		height = incoming_height
		image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(MinimapPalette.VOID)
	for tile in data.get("tiles", []):
		# xIndex is the row and yIndex the column, as TileMapState reads them.
		var column := int(tile.get("yIndex", 0))
		var row := int(tile.get("xIndex", 0))
		if column < 0 or row < 0 or column >= width or row >= height:
			continue
		image.set_pixel(column, row, MinimapPalette.for_cell(_content,
			tiles.tile_at(0, column, row), tiles.tile_at(COLLISION_LAYER, column, row)))
	version += 1


## The server sends the whole roster whenever anyone in it moved, so this
## replaces rather than merges.
func apply_global_positions(data: Dictionary) -> void:
	players = []
	for entry in data.get("players", []):
		players.append({
			"id": int(entry.get("playerId", 0)),
			"name": String(entry.get("name", "")),
			"position": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
			# The server's own rule: a player neither hidden nor in stasis.
			"teleportable": bool(entry.get("teleportable", false)),
		})


## How far the realm's cleansing has come, and how hard it is.
func apply_purification(data: Dictionary) -> void:
	realm = {"progress": int(data.get("progress", 0)), "goal": int(data.get("goal", 0)),
		"difficulty": float(data.get("difficulty", 0.0)), "tier": int(data.get("tier", 0)),
		"modifiers": String(data.get("modifiers", ""))}


## SYSTEM's "Hop mode: ON|OFF", or from EVENT_MARKER `ADD|eventId|bossId|x|y|name`
## or `REMOVE|bossId` -- a name may contain the separator, so it is everything
## after the fifth, and anything malformed is dropped as the web drops it.
func apply_text(data: Dictionary) -> void:
	var from := String(data.get("from", ""))
	if from == ChatLog.SYSTEM and String(data.get("message", "")).begins_with(HOP_REPLY):
		hop = String(data["message"]).ends_with("ON")
	if from != ChatLog.EVENT_MARKER:
		return
	var parts := String(data.get("message", "")).split("|")
	if parts[0] == "ADD" and parts.size() >= 6:
		markers[parts[2]] = {
			"event_id": int(parts[1]),
			"position": Vector2(parts[3].to_float(), parts[4].to_float()),
			"name": "|".join(parts.slice(5)),
			"seen_ms": int(_clock.call()),
		}
	elif parts[0] == "REMOVE" and parts.size() >= 2:
		markers.erase(parts[1])


## Forgets the pins the server stopped refreshing.
func expire() -> void:
	var now := int(_clock.call())
	for boss_id in markers.keys():
		if now - int(markers[boss_id]["seen_ms"]) > MARKER_STALE_MS:
			markers.erase(boss_id)
