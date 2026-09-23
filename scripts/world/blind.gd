class_name Blind
extends RefCounted

## The BLIND status (28): tunnel vision, three tiles around the player.
##
## The web client's rule (renderer.js `_getBlindState`, `blindCull`). While
## the local player carries it, an enemy or a bullet whose whole BODY is
## outside the tunnel is not drawn -- centre distance past the radius plus
## its own half-size, so a big enemy the player is standing in stays seen --
## and neither is an enemy's bar, which would give the position away. The
## player's own bullets are exempt, predicted or confirmed, so a shot can
## still be followed. Other players, loot and portals are left alone: the
## web's comment says otherwise, its code does not, and the code is what
## players have. The server keeps every position; this only hides them, so
## a shot seems to come out of nowhere until it is close. BlindVignette
## darkens the screen past the same radius.

const EFFECT := 28
## Three tiles, in world units -- the web's BLIND_RADIUS (32 * 3).
const RADIUS := 3.0 * GameConstants.TILE_SIZE


static func active(state: RealmState) -> bool:
	return state.local.is_present() and EFFECT in state.local.effects


## The middle of the player, which the tunnel is round.
static func centre(state: RealmState) -> Vector2:
	return state.local.render_centre()


## Whether a body at `top_left`, `size` across, is out of sight.
static func hides(state: RealmState, top_left: Vector2, size: float) -> bool:
	if not active(state):
		return false
	var half := size * 0.5
	return (top_left + Vector2(half, half)).distance_to(centre(state)) > RADIUS + half


## A bullet out of sight -- never one of ours. Asked of every bullet every
## frame, so nothing about the bullet is read unless we are blind.
static func hides_bullet(state: RealmState, bullet: Dictionary) -> bool:
	if not active(state) or bullet.get("predicted", false) \
			or int(bullet.get("src_entity_id", 0)) == state.local.id:
		return false
	return hides(state, bullet["pos"], float(bullet.get("size", 8)))
