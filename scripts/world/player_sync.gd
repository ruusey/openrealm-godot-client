class_name PlayerSync
extends RefCounted

## Keeps the local player and its roster entry agreeing.
##
## The local player is drawn from the roster like everyone else, and the
## roster is what the overlay reads for bars and chips, so what the server
## says about us has to land in both places. Split from RealmState so the
## router stays a router.


## The roster is authoritative for our own class, which otherwise only
## arrives once in the login response.
static func local_class(state: RealmState) -> void:
	var own: Dictionary = state.entities.players.get(state.local.id, {})
	if not own.is_empty():
		state.local.class_id = int(own.get("class_id", state.local.class_id))


## The heavy update reaches every player in view -- the server strips the
## backpack, not the numbers -- so a remote's bars learn their maxima here.
static func update(state: RealmState, data: Dictionary) -> void:
	state.local.apply_update(data)
	state.abilities.apply_update(data, state.local.id)
	var entity := state.entities.find(GameConstants.ENTITY_PLAYER, int(data.get("playerId", 0)))
	if entity.is_empty():
		return
	var stats: Dictionary = data.get("stats", {})
	entity["max_health"] = int(stats.get("hp", 0))
	entity["max_mana"] = int(stats.get("mp", 0))
	entity["health"] = int(data.get("health", 0))
	entity["mana"] = int(data.get("mana", 0))
	# The nearby list's tooltip works the level out from this.
	entity["experience"] = int(data.get("experience", 0))
	# A dye drunk mid-session arrives here, for us and for everyone watching.
	entity["dye_id"] = int(data.get("dyeId", 0))
	# The account's quest score, under the name for everyone watching.
	entity["stars"] = int(data.get("stars", 0))


## HP/MP and statuses apply to the local player and the roster entry alike.
static func player_state(state: RealmState, data: Dictionary) -> void:
	state.local.apply_player_state(data)
	var entity := state.entities.find(GameConstants.ENTITY_PLAYER, int(data.get("playerId", 0)))
	if not entity.is_empty():
		entity["health"] = int(data.get("health", 0))
		entity["mana"] = int(data.get("mana", 0))
		entity["effects"] = data.get("effectIds", [])
		entity["effect_stacks"] = data.get("effectStacks", [])
