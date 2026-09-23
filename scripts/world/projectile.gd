class_name Projectile
extends RefCounted

## Construction of bullet simulation state, from the wire or from a local
## prediction. Motion lives in ProjectileMotion, flags in ProjectileKind and
## angle handling in ProjectileAngle.

const DEFAULT_ORBIT_RADIUS := 64.0


## Simulation state for a bullet the server told us about.
static func from_wire(wire: Dictionary, now_ms: int) -> Dictionary:
	var pos: Dictionary = wire.get("pos", {})
	var bullet := {
		"id": int(wire.get("id", 0)),
		# NetBullet.projectileId carries the projectile *group* id, which is
		# what the sprite and the group definition are keyed by.
		"group_id": int(wire.get("projectileId", 0)),
		"pos": Vector2(pos.get("x", 0.0), pos.get("y", 0.0)),
		"size": int(wire.get("size", 8)),
		"angle": float(wire.get("angle", 0.0)),
		"magnitude": float(wire.get("magnitude", 0.0)),
		"range": float(wire.get("range", 0.0)),
		"traveled": 0.0,
		"damage": int(wire.get("damage", 0)),
		"flags": wire.get("flags", []),
		"invert": bool(wire.get("invert", false)),
		"time_step": float(wire.get("timeStep", 0)),
		"amplitude": float(wire.get("amplitude", 0)),
		"frequency": float(wire.get("frequency", 0)),
		"orbit_centre": Vector2(wire.get("orbitCenterX", 0.0), wire.get("orbitCenterY", 0.0)),
		"orbit_radius": float(wire.get("orbitRadius", 0.0)),
		"orbit_phase": float(wire.get("orbitPhase", 0.0)),
		# v0.9.0 fields. The optional groups ride behind a mask byte, so a
		# straight bullet carries none of them and these stay at their
		# defaults.
		"length": float(wire.get("length", 0)),
		"lifetime_ticks": int(wire.get("lifetimeTicks", 0)),
		"src_entity_id": int(wire.get("srcEntityId", 0)),
		"target_entity_id": int(wire.get("targetEntityId", 0)),
		"anchor_offset": Vector2.ZERO,
		"created_ms": now_ms,
		"predicted": false,
		"server_id": 0,
	}
	_initialise_orbit(bullet)
	return bullet


## A locally predicted bullet, spawned the instant the player clicks so firing
## feels immediate. Negative ids keep predictions out of the server id space.
static func predicted(local_id: int, group_id: int, position: Vector2, angle: float,
		definition: Dictionary, now_ms: int, range_multiplier := 1.0,
		extra_flags: Array = []) -> Dictionary:
	# Content flags parse as floats, and `in` is type-strict: a 34.0 is not
	# the HOMING 34 to any flag test, so they are made ints here, once.
	var flags: Array = []
	for flag in definition.get("flags", []):
		flags.append(int(flag))
	for flag in extra_flags:
		if not flag in flags:
			flags.append(flag)

	var bullet := {
		"id": local_id,
		"group_id": group_id,
		"pos": position,
		"size": int(definition.get("size", 8)),
		"angle": angle,
		"magnitude": float(definition.get("magnitude", 0.0)),
		"range": float(definition.get("range", 0.0)) * range_multiplier,
		"traveled": 0.0,
		"damage": int(definition.get("damage", 0)),
		"flags": flags,
		"invert": ProjectileKind.has_flag({"flags": flags}, ProjectileKind.INVERTED_PARAMETRIC),
		"time_step": 0.0,
		"amplitude": float(definition.get("amplitude", 0)),
		"frequency": float(definition.get("frequency", 0)),
		"orbit_centre": Vector2.ZERO,
		"orbit_radius": 0.0,
		"orbit_phase": angle,
		"length": float(definition.get("length", 0)),
		"lifetime_ticks": int(definition.get("lifetimeTicks", 0)),
		"src_entity_id": 0,
		"target_entity_id": 0,
		"anchor_offset": Vector2.ZERO,
		"created_ms": now_ms,
		"predicted": true,
		"server_id": 0,
	}
	_initialise_orbit(bullet)
	return bullet


static func centre(bullet: Dictionary) -> Vector2:
	var half: float = float(bullet.get("size", 8)) * 0.5
	return bullet["pos"] + Vector2(half, half)


static func _initialise_orbit(bullet: Dictionary) -> void:
	if not ProjectileKind.is_orbital(bullet):
		return
	if bullet["orbit_radius"] <= 0.0:
		var amplitude: float = bullet["amplitude"]
		bullet["orbit_radius"] = amplitude if amplitude != 0.0 else DEFAULT_ORBIT_RADIUS
	if bullet["orbit_centre"] == Vector2.ZERO:
		# Derive the centre this bullet must be orbiting from where it spawned.
		bullet["orbit_centre"] = bullet["pos"] - Vector2(
			cos(bullet["orbit_phase"]), sin(bullet["orbit_phase"])) * bullet["orbit_radius"]
