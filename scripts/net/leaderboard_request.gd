class_name LeaderboardRequest
extends RefCounted

## The leaderboard's one call on the data service: every account's living
## characters, best XP first, as the service ranks them.
##
##   GET /data/stats/top?count=N  Authorization: <token>  -> [LeaderboardEntryDto]
##
## The token is needed -- the service answers 401 without one.


## {success: true, entries} or {success: false, result: reason}.
static func top(service: DataService, count: int) -> Dictionary:
	if service == null or service.token == "":
		return {"success": false, "result": "not signed in"}
	var response: Dictionary = await service.send(HTTPClient.METHOD_GET, "/data/stats/top?count=%d" % count, "", true)
	if not response["ok"]:
		return {"success": false, "result": response["error"]}
	if not response["body"] is Array:
		return {"success": false, "result": "unexpected leaderboard response"}
	return {"success": true, "entries": response["body"]}
