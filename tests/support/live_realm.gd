class_name LiveRealm
extends RefCounted

## Getting a live session out of the nexus, where nothing can be fought.
##
## The nexus is the one place enemies cannot be attacked, so every live test
## that hits or is hit leaves it first, the way a player does: through one
## of its own portals -- any but the vault, which is furniture rather than a
## realm -- walked to under real prediction and used.

const LOAD_TIMEOUT := 20.0
const WALK_TIMEOUT := 45.0
## Stop short of the client's own reach, so arrival is unambiguous.
const ARRIVE_PX := PortalInput.REACH_PX - 16.0


## Returns false, having said why, if no portal offers a way out or the
## realm never changes.
static func leave_nexus(drive: LiveDriver) -> bool:
	var state: RealmState = drive.main.state
	if not await drive.wait(LOAD_TIMEOUT, func() -> bool: return not state.entities.portals.is_empty()):
		push_error("no portals ever arrived in realm %d" % state.tiles.realm_id)
		return false
	var portal := _a_portal_out(state)
	if portal.is_empty():
		push_error("the nexus offered nothing but the vault")
		return false
	var at: Vector2 = state.entities.render_position(portal)
	print("taking the portal to %s at %s" % [portal.get("label", "?"), at])
	if not await drive.walk_to(at, ARRIVE_PX, WALK_TIMEOUT):
		push_error("never reached the portal; stopped %.0f px away" % drive.distance_to(at))
		return false

	var realm: int = state.tiles.realm_id
	drive.main.portals.use_nearest()
	var moved := await drive.wait(LOAD_TIMEOUT, func() -> bool:
		return state.tiles.realm_id != realm and state.tiles.tile_count() > 0)
	await drive.settle(2.0)
	if not moved:
		push_error("the portal never took")
		return false
	print("arrived in realm %d map %d (%s), corrections %d" % [
		state.tiles.realm_id, state.tiles.map_id, state.transition.zone, state.movement.corrections])
	return true


static func _a_portal_out(state: RealmState) -> Dictionary:
	for id in state.entities.portals:
		var portal: Dictionary = state.entities.portals[id]
		if int(portal.get("portal_id", -1)) != PortalInput.VAULT_PORTAL:
			return portal
	return {}
