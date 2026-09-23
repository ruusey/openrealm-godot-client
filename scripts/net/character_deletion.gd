class_name CharacterDeletion
extends RefCounted

## Deleting a living character, as the web client's Delete button does:
##
##   DELETE /data/account/character/{characterUuid}  Authorization: <token>
##
## The service does not remove it. It stamps `deleted` on the character,
## which puts it in the graveyard, and banks no fame for it -- only the game
## server's delete on a death does that. The reply is a message, not the
## account, so the list is fetched again afterwards, as the web client does.


## Deletes the character and lists the account again. {success, characters}
## on success; {success: false, result: reason} when either step fails.
static func run(service: DataService, character_uuid: String) -> Dictionary:
	if service.token == "" or character_uuid == "":
		return {"success": false, "result": "not signed in"}
	var response: Dictionary = await service.send(HTTPClient.METHOD_DELETE,
		"/data/account/character/%s" % character_uuid, "", true)
	if not response["ok"]:
		return {"success": false, "result": response["error"]}
	var listed: Dictionary = await service.fetch_characters()
	if not listed["success"]:
		return {"success": false, "result": "Deleted, but the character list could not be loaded."}
	return {"success": true, "characters": listed["characters"]}
