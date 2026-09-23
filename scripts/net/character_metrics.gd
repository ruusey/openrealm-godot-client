class_name CharacterMetrics
extends RefCounted

## A character's lifetime metrics, as the web client's stats card reads them:
##
##   GET /data/account/character/{characterUuid}/metrics  Authorization: <token>
##
## The service lets an account read its own characters, the fallen too, and
## answers a character that has never played with an all-zero report rather
## than an error.


## {success, metrics} or {success: false, result: reason}.
static func fetch(service: DataService, character_uuid: String) -> Dictionary:
	if service.token == "" or character_uuid == "":
		return {"success": false, "result": "not signed in"}
	var response: Dictionary = await service.send(HTTPClient.METHOD_GET,
		"/data/account/character/%s/metrics" % character_uuid, "", true)
	if not response["ok"]:
		return {"success": false, "result": response["error"]}
	var body = response["body"]
	return {"success": true, "metrics": body if body is Dictionary else {}}
