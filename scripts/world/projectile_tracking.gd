class_name ProjectileTracking
extends RefCounted

## The two v0.9.0 motion types that depend on another entity.
##
## HOMING steers its heading toward a target each tick; ANCHORED snaps back to
## its source entity, so a wall summoned by an enemy travels with it. Both
## live here rather than in ProjectileMotion because they need to look
## entities up, and the integrator deliberately knows nothing about the world.
##
## When the entity has gone -- unloaded, or killed -- the server leaves the
## bullet where it is until its lifetime runs out, and so do we.


## Records where the bullet sits relative to its source, so it can be snapped
## back every tick afterwards. Mirrors Bullet.setupAnchor.
static func capture_anchor(bullet: Dictionary, entities: EntityRegistry,
		player: LocalPlayer) -> void:
	var source: Variant = _position_of(int(bullet.get("src_entity_id", 0)), entities, player)
	if source == null:
		return
	bullet["anchor_offset"] = bullet["pos"] - (source as Vector2)


static func anchor(bullet: Dictionary, entities: EntityRegistry, player: LocalPlayer) -> void:
	var source: Variant = _position_of(int(bullet.get("src_entity_id", 0)), entities, player)
	if source == null:
		return
	bullet["pos"] = (source as Vector2) + bullet["anchor_offset"]


## Rotates the heading toward the target by at most `frequency` degrees this
## tick. Velocity is (sin a, cos a), so the angle pointing at the target is
## atan2(dx, dy) -- not the usual atan2(dy, dx). Mirrors Bullet.steerToward.
static func steer(bullet: Dictionary, entities: EntityRegistry, player: LocalPlayer,
		bullet_scale: float) -> void:
	var target_id := int(bullet.get("target_entity_id", 0))
	var target: Variant = _position_of(target_id, entities, player)
	if target == null:
		return

	var centre: Vector2 = (target as Vector2) \
		+ Vector2.ONE * _size_of(target_id, entities, player) * 0.5
	var origin: Vector2 = Projectile.centre(bullet)
	var desired := atan2(centre.x - origin.x, centre.y - origin.y)
	var difference := wrapf(desired - float(bullet["angle"]), -PI, PI)
	var max_turn := deg_to_rad(float(bullet.get("frequency", 0)) * bullet_scale)
	bullet["angle"] = float(bullet["angle"]) + clampf(difference, -max_turn, max_turn)


## The local player is tracked by prediction, not by the entity roster, so its
## predicted position is the one the server is steering at.
static func _position_of(id: int, entities: EntityRegistry, player: LocalPlayer) -> Variant:
	if id == 0:
		return null
	if player != null and id == player.id:
		return player.position
	var entity := entities.find_any(id)
	if entity.is_empty():
		return null
	return entities.render_position(entity)


static func _size_of(id: int, entities: EntityRegistry, player: LocalPlayer) -> float:
	if player != null and id == player.id:
		return float(GameConstants.PLAYER_SIZE)
	return float(entities.find_any(id).get("size", 16))
