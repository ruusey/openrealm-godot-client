class_name ShotPredictor
extends RefCounted

## Builds the locally predicted bullets for a shot, and recognises the server's
## copies of them when they arrive.
##
## The fan has to match the server's exactly -- count, spread, range and
## piercing all come from the weapon archetype. Get any of them wrong and the
## predicted bullets never line up with the authoritative ones, so the player
## sees ghosts flying alongside the real shots.

## Fan spread for weapons whose archetype does not specify one.
const DEFAULT_SPREAD_RAD := 0.12
## A prediction and an incoming bullet are the same shot within this angle...
const ANGLE_TOLERANCE := 0.20
## ...and, for bullets not flagged as player shots, this distance.
const MATCH_DISTANCE := 96.0


## Returns the predicted bullets for one shot, keyed by their local (negative) id.
static func build(shot_number: int, group_id: int, definitions: Array, base_angle: float,
		origin: Vector2, archetype: Dictionary, now_ms: int) -> Dictionary:
	var count := maxi(int(archetype.get("projectileCount", 1)), 1)
	var spread := float(archetype.get("spreadRad", 0.0))
	if spread <= 0.0:
		spread = DEFAULT_SPREAD_RAD
	var range_multiplier := float(archetype.get("rangeMul", 1.0))
	if range_multiplier <= 0.0:
		range_multiplier = 1.0

	var extra_flags: Array = []
	if bool(archetype.get("piercing", false)):
		extra_flags.append(ProjectileKind.PASS_THROUGH_ENEMIES)

	var built := {}
	var index := 0
	for definition in definitions:
		var definition_angle: float = base_angle + float(definition.get("angle", 0.0))
		for i in count:
			var offset := (float(i) - float(count - 1) * 0.5) * spread
			# Negative ids keep predictions out of the server id space.
			var local_id := -(shot_number * 100 + index)
			index += 1
			built[local_id] = Projectile.predicted(local_id, group_id, origin,
				definition_angle + offset, definition, now_ms, range_multiplier, extra_flags)
	return built


## Finds the prediction matching an incoming server bullet, or an empty
## dictionary. A matched prediction adopts the server id so a later Unload
## removes it.
static func claim(bullets: Dictionary, wire: Dictionary, server_id: int) -> bool:
	var incoming_angle := float(wire.get("angle", 0.0))
	var incoming_position := _wire_position(wire)
	var is_player_shot: bool = ProjectileKind.PLAYER_PROJECTILE in wire.get("flags", [])

	for local_id in bullets:
		if local_id >= 0:
			continue
		var prediction: Dictionary = bullets[local_id]
		if prediction.get("server_id", 0) != 0:
			continue
		if absf(angle_difference(prediction["angle"], incoming_angle)) > ANGLE_TOLERANCE:
			continue
		# A player-flagged bullet can only be ours, so the angle is enough.
		# Anything else also has to have spawned near where we predicted.
		if not is_player_shot and prediction["pos"].distance_to(incoming_position) > MATCH_DISTANCE:
			continue
		prediction["server_id"] = server_id
		return true
	return false


static func _wire_position(wire: Dictionary) -> Vector2:
	var pos: Dictionary = wire.get("pos", {})
	return Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
