class_name NearbyPlayers
extends RefCounted

## Who else is in view: the web client's nearby list and its tooltip.
##
## "Nearby" is everyone the server has loaded into the roster -- it only
## streams what is in view -- but yourself and, as the web client has it,
## anyone already in your party, who has a row of their own; at most
## sixteen, in the roster's order. A name is coloured by chat role, the
## web's getNameColorCSS, and the tooltip is its header: the name and a
## role badge, the level worked out from the experience every UpdatePacket
## carries, the class, HP and MP.

const MAX := 16
const BOLD_ROLES := ["sysadmin", "admin"]


static func list(entities: EntityRegistry, local_id: int, party_ids: Array = []) -> Array:
	var out: Array = []
	for id in entities.players:
		if id == local_id or id in party_ids:
			continue
		out.append(entities.players[id])
		if out.size() >= MAX:
			break
	return out


static func role_colour(role: String) -> Color:
	return NameColours.role(role)


static func bold(role: String) -> bool:
	return role in BOLD_ROLES


static func tooltip(player: Dictionary, content: GameData) -> String:
	var role := String(player.get("chat_role", ""))
	var cls := content.classes_art.display_name(int(player.get("class_id", 0)))
	var level := "?"
	if player.has("experience") and content.levels.loaded():
		level = str(content.levels.level_for(int(player["experience"])))
	var name := String(player.get("name", ""))
	return "\n".join([
		(name if name != "" else cls) + ("  [%s]" % role if role != "" else ""),
		"Lv %s %s" % [level, cls],
		"HP: %d/%d" % [int(player.get("health", 0)), int(player.get("max_health", 0))],
		"MP: %d/%d" % [int(player.get("mana", 0)), int(player.get("max_mana", 0))],
	])
