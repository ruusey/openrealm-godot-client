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
## A prediction and an incoming bullet are the same shot within this angle.
const ANGLE_TOLERANCE := 0.20


## Returns the predicted bullets for one shot, keyed by their local (negative)
## id. `extra_projectiles` is the count a socketed gem adds on top of the
## archetype's (a Multishot Gem is +1) -- it MUST match the server's total or
## the extra server bullet arrives late and the fan looks staggered.
static func build(shot_number: int, group_id: int, definitions: Array, base_angle: float,
		origin: Vector2, archetype: Dictionary, now_ms: int, extra_projectiles := 0) -> Dictionary:
	var count := maxi(int(archetype.get("projectileCount", 1)), 1) + maxi(extra_projectiles, 0)
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


## Finds the prediction matching an incoming server bullet and adopts its id, or
## returns false. `owner_id` is the local player: only a bullet the server says
## WE fired can be one of our predictions. Matching any other bullet (a nearby
## enemy shot at a similar angle) would drop the server's real, damaging bullet
## so it never draws -- an invisible projectile that still kills. So an enemy
## bullet is never claimed here; it always falls through to be spawned and drawn.
static func claim(bullets: Dictionary, wire: Dictionary, server_id: int, owner_id: int) -> bool:
	if int(wire.get("srcEntityId", 0)) != owner_id:
		return false
	var incoming_angle := float(wire.get("angle", 0.0))
	for local_id in bullets:
		if local_id >= 0:
			continue
		var prediction: Dictionary = bullets[local_id]
		if prediction.get("server_id", 0) != 0:
			continue
		if absf(angle_difference(prediction["angle"], incoming_angle)) > ANGLE_TOLERANCE:
			continue
		prediction["server_id"] = server_id
		return true
	return false
