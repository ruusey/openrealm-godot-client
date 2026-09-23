class_name TextAnchor
extends RefCounted

## Where a combat number goes when the server gives it no impact point.

## A zero position means the server did not pick an impact point, so the
## number belongs on whatever it was about. Bullets count: a shot that expires
## against terrain reports through the bullet it came from.
##
## Our own player is the exception: its roster entry trails the server's
## snapshots, so a number about us -- damage taken, "+xp", a status -- would
## land wherever we were a moment ago, and the further we moved while
## fighting, the further off. The predicted position is where we are, and
## it is what the web client's players map holds for us.
##
## A target that has already been unloaded lands the number at the world
## origin, which is the web client's behaviour -- the native drops the text
## instead. It is the common case for a kill shot, since the UnloadPacket
## usually beats the TextEffectPacket, so the accepted cost is a small pile of
## numbers stacking at tile 0,0 where nobody is looking.
static func of(entity_type: int, id: int, entities: EntityRegistry,
		projectiles: ProjectileSystem, local: LocalPlayer = null) -> Vector2:
	if entity_type == GameConstants.ENTITY_PLAYER and local != null and local.is_present() and id == local.id:
		return local.render_position()
	match entity_type:
		GameConstants.ENTITY_PLAYER, GameConstants.ENTITY_ENEMY:
			var entity := entities.find(entity_type, id)
			if not entity.is_empty():
				return entities.render_position(entity)
		GameConstants.ENTITY_BULLET:
			var bullet: Dictionary = projectiles.bullets.get(id, {})
			if not bullet.is_empty():
				return bullet.get("pos", Vector2.ZERO)
	return Vector2.ZERO
