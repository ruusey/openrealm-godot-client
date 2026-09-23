class_name EntityRegistry
extends RefCounted

## The visible world minus bullets: players, enemies, loot and portals.
##
## Bullets are deliberately absent. The server never streams their positions,
## so they are re-simulated by ProjectileSystem instead of interpolated here.

const VELOCITY_SCALE := 128.0
const FLAG_ATTACKING := 0x01

var players := {}
var enemies := {}
var containers := {}
var portals := {}

var _short_ids := {}   # shortId -> entity id
var _clock: Callable
## The local player's centre, for the viewport gate on extrapolation; INF
## when there is no local player to gate on. RealmState wires it.
var viewer: Callable = func() -> Vector2: return Vector2.INF


func _init(clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	_clock = clock


func clear() -> void:
	players.clear()
	enemies.clear()
	containers.clear()
	portals.clear()
	_short_ids.clear()


## Everything except one player, which is what a realm change leaves behind.
##
## The player crossing is the one entity that exists on both sides, and it is
## drawn from this roster rather than from LocalPlayer -- clear it outright
## and the screen goes black until the next realm streams in, with not even a
## character on it. Both references keep exactly this one: the web client's
## wipe is commented "local player persists across realms", the native's is
## `removeIf(key != localId)`.
func clear_but(keep_id: int) -> void:
	var kept: Dictionary = players.get(keep_id, {})
	clear()
	if not kept.is_empty():
		players[keep_id] = kept


func render_position(entity: Dictionary) -> Vector2:
	return EntitySnapshots.render_position(entity, _clock.call(), viewer.call())


## Applies a LoadPacket's entity tables. The wire mapping itself lives in
## EntityLoader; this keeps the registry to storage, lookup and movement.
func apply_load(data: Dictionary) -> void:
	EntityLoader.apply(self, data, _clock.call())


func apply_unload(data: Dictionary) -> void:
	for id in data.get("players", []):
		_release_short_id(players.get(int(id), {}))
		players.erase(int(id))
	for id in data.get("enemies", []):
		_release_short_id(enemies.get(int(id), {}))
		enemies.erase(int(id))
	for id in data.get("containers", []):
		containers.erase(int(id))
	for id in data.get("portals", []):
		portals.erase(int(id))


func apply_object_move(data: Dictionary) -> void:
	var now: int = _clock.call()
	for movement in data.get("movements", []):
		var entity := find(int(movement.get("entityType", 0)), int(movement.get("entityId", 0)))
		if entity.is_empty():
			continue
		EntitySnapshots.push(entity,
			Vector2(movement.get("posX", 0.0), movement.get("posY", 0.0)),
			Vector2(movement.get("velX", 0.0), movement.get("velY", 0.0)), now, viewer.call())
		entity["attacking"] = (int(movement.get("flags", 0)) & FLAG_ATTACKING) != 0


func apply_compact_move(data: Dictionary) -> void:
	var now: int = _clock.call()
	for movement in data.get("movements", []):
		var short_id := int(movement.get("shortEntityId", 0))
		if not _short_ids.has(short_id):
			continue
		var entity := find_any(_short_ids[short_id])
		if entity.is_empty():
			continue
		EntitySnapshots.push(entity,
			Vector2(movement.get("posX", 0.0), movement.get("posY", 0.0)),
			Vector2(float(movement.get("velXFixed", 0)) / VELOCITY_SCALE,
				float(movement.get("velYFixed", 0)) / VELOCITY_SCALE), now, viewer.call())
		entity["attacking"] = (int(movement.get("flags", 0)) & FLAG_ATTACKING) != 0


func find(entity_type: int, id: int) -> Dictionary:
	match entity_type:
		GameConstants.ENTITY_PLAYER: return players.get(id, {})
		GameConstants.ENTITY_ENEMY: return enemies.get(id, {})
	return {}


## Only players and enemies are given short ids (LoadPacket.from assigns them
## through ShortIdAllocator), so those are the only tables worth searching.
func find_any(id: int) -> Dictionary:
	if players.has(id):
		return players[id]
	return enemies.get(id, {})


func upsert(table: Dictionary, id: int, kind: int) -> Dictionary:
	if not table.has(id):
		table[id] = {"id": id, "kind": kind, "snaps": [], "attacking": false,
			"walk": WalkCycle.new(), "attack": AttackPose.new(),
			"facing": "front", "facing_left": false}
	return table[id]


func snapshot_from_wire(entity: Dictionary, wire: Dictionary, now: int) -> void:
	var pos: Dictionary = wire.get("pos", {})
	EntitySnapshots.push(entity, Vector2(pos.get("x", 0.0), pos.get("y", 0.0)),
		Vector2(wire.get("dX", 0.0), wire.get("dY", 0.0)), now, viewer.call())


## shortId 0 means "none assigned"; mapping it would alias entities together.
func register_short_id(value: Variant, id: int) -> void:
	var short_id := int(value)
	if short_id != 0:
		_short_ids[short_id] = id


func _release_short_id(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	for short_id in _short_ids.keys():
		if _short_ids[short_id] == entity.get("id", -1):
			_short_ids.erase(short_id)
			return
