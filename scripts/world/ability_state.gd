class_name AbilityState
extends RefCounted

## Skill points, cooldowns, and what is being cast or has just landed.
##
## Points and levels arrive on UpdatePacket; a cast in progress on
## AbilityCastStartPacket; an effect that has resolved on CreateEffectPacket.
## The cooldowns are the client's own, kept so that a spammed key does not
## burn mana on sends the server would silently refuse -- it answers a
## refused cast with nothing at all, which is why the web client gates on
## its overlay before sending.

const SLOTS := 4
## The two persistent-refresh effects (blade orbit, blade blender): the
## server re-sends one every ~250ms while it runs, and only the newest of
## each may draw, or they stack at different phases and jitter.
const PERSISTENT_TYPES := [EffectType.BLADE_ORBIT, EffectType.BLADE_BLENDER]
## How long the cast-range ring lingers; the web client's showCastRing.
const RING_MS := 700

var available_points := 0
var invested: Array = [0, 0, 0, 0]
## Bumped when the points or levels change, so the bar redraws only then.
var version := 0
var cooldown_until: Array = [0, 0, 0, 0]
var cooldown_total: Array = [0, 0, 0, 0]
var global_until := 0
## playerId -> the cast in progress.
var casts := {}
var effects: Array = []
var rings: Array = []

var _clock: Callable


func _init(clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	_clock = clock


func now() -> int:
	return _clock.call()


func clear() -> void:
	available_points = 0
	invested = [0, 0, 0, 0]
	cooldown_until = [0, 0, 0, 0]
	cooldown_total = [0, 0, 0, 0]
	global_until = 0
	casts.clear()
	effects.clear()
	rings.clear()
	version += 1


## The skill-point half of an UpdatePacket, ours only.
func apply_update(data: Dictionary, local_id: int) -> void:
	if int(data.get("playerId", 0)) != local_id:
		return
	available_points = int(data.get("availableSkillPoints", 0))
	for slot in SLOTS:
		invested[slot] = int(data.get("investedSlot%d" % slot, 0))
	version += 1


## Someone began a timed cast. The local caster already posed when it sent
## the packet; a remote one gets its swing from here, aimed at the target,
## the way the web client drives remotes off this packet.
func apply_cast_start(data: Dictionary, entities: EntityRegistry, local_id: int) -> void:
	var duration := int(data.get("durationMs", 0))
	if duration <= 0:
		return
	var id := int(data.get("playerId", 0))
	var target := Vector2(data.get("worldTargetX", 0.0), data.get("worldTargetY", 0.0))
	casts[id] = {"ability_id": int(data.get("abilityId", 0)), "slot": int(data.get("slot", 0)),
		"started": now(), "duration_ms": duration, "target": target}
	var caster: Dictionary = entities.players.get(id, {})
	if id != local_id and not caster.is_empty():
		var centre := entities.render_position(caster) + Vector2.ONE * float(caster.get("size", 0)) * 0.5
		caster["attack"].begin(target - centre)


func apply_effect(data: Dictionary) -> void:
	var kind := int(data.get("effectType", 0))
	if kind in PERSISTENT_TYPES:
		effects = effects.filter(func(fx: Dictionary) -> bool: return fx["type"] != kind)
	effects.append({"type": kind, "pos": Vector2(data.get("posX", 0.0), data.get("posY", 0.0)),
		"radius": float(data.get("radius", 0.0)), "duration_ms": int(data.get("duration", 0)),
		"target": Vector2(data.get("targetPosX", 0.0), data.get("targetPosY", 0.0)),
		"tier": int(data.get("tier", 0)), "owner": int(data.get("ownerId", 0)), "started": now()})


## Drops what has run its course.
func expire() -> void:
	var at := now()
	effects = effects.filter(func(fx: Dictionary) -> bool: return at - fx["started"] < fx["duration_ms"])
	rings = rings.filter(func(ring: Dictionary) -> bool: return at - ring["started"] < RING_MS)
	for id in casts.keys():
		if at - casts[id]["started"] >= casts[id]["duration_ms"]:
			casts.erase(id)


## How far along a player's cast is, or -1 for a player not casting.
func cast_progress(player_id: int) -> float:
	if not casts.has(player_id):
		return -1.0
	var cast: Dictionary = casts[player_id]
	return clampf(float(now() - cast["started"]) / float(cast["duration_ms"]), 0.0, 1.0)


func start_cooldown(slot: int, duration_ms: int) -> void:
	cooldown_until[slot] = now() + duration_ms
	cooldown_total[slot] = duration_ms


func on_cooldown(slot: int) -> bool:
	return now() < cooldown_until[slot]


## What is left of a cooldown, 1 at the start and 0 once it has run.
func cooldown_fraction(slot: int) -> float:
	if cooldown_total[slot] <= 0:
		return 0.0
	return clampf(float(cooldown_until[slot] - now()) / float(cooldown_total[slot]), 0.0, 1.0)


func show_ring(centre: Vector2, radius: float) -> void:
	rings.append({"pos": centre, "radius": radius, "started": now()})
