class_name BulletVisibility
extends RefCounted

## Which bullets nobody draws this frame, with every per-frame input (Blind, the
## "show other players' bullets" setting, who we are) read once up front, so the
## sprite, glow and particle passes each ask one cheap question per bullet.
##
## A bullet is hidden -- sprite, afterimage, glow, trail and impact all skip it --
## when Blind hides it, or when "Show other players' bullets" is off and the shot
## isn't ours: another player's bullet, OR an allied shot (a companion's or another
## player's summon) that carries ALLY_PROJECTILE. Our own shots always draw.

## False when nothing can be hidden this frame: callers skip the per-bullet test.
var any := false

var _blind := false
var _blind_centre := Vector2.ZERO
var _others_hidden := false
var _local_id := 0
var _players: Dictionary = {}


static func of(state: RealmState) -> BulletVisibility:
	var visibility := BulletVisibility.new()
	visibility._blind = Blind.active(state)
	if visibility._blind:
		visibility._blind_centre = Blind.centre(state)
	visibility._others_hidden = not state.settings.is_on("show_other_bullets")
	visibility._local_id = state.local.id
	visibility._players = state.entities.players
	visibility.any = visibility._blind or visibility._others_hidden
	return visibility


func hides(bullet: Dictionary) -> bool:
	if not any:
		return false
	var src := int(bullet.get("src_entity_id", 0))
	if _blind and src != _local_id and not bullet.get("predicted", false):
		var half := float(bullet.get("size", 8)) * 0.5
		var centre: Vector2 = bullet["pos"] + Vector2(half, half)
		if centre.distance_to(_blind_centre) > Blind.RADIUS + half:
			return true
	if not _others_hidden or src == _local_id:
		return false
	return _players.has(src) or ProjectileKind.has_flag(bullet, ProjectileKind.ALLY_PROJECTILE)
