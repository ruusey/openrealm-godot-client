class_name AccountTerms
extends RefCounted

## The Terms of Use gate's two calls on the data service, for the account
## signed in on it:
##
##   GET  /admin/account/terms        -> {currentVersion, acceptedVersion, needsAcceptance}
##   POST /admin/account/terms/accept -> {ok, acceptedVersion}
##
## The service compares the account's accepted version with its own
## CURRENT_TERMS_VERSION, so a new version of the terms asks everyone again.
## Nothing on the service enforces the gate -- the game server lets an
## account in either way -- so it is the client's to keep, and like both
## references it fails closed: a reply that does not say "no need" is a
## failure, not a pass.


## {success: true, needs} or {success: false, result: reason}.
static func status(service: DataService) -> Dictionary:
	if service.token == "":
		return {"success": false, "result": "not signed in"}
	var response: Dictionary = await service.send(HTTPClient.METHOD_GET, "/admin/account/terms", "", true)
	if not response["ok"]:
		return {"success": false, "result": response["error"]}
	var body = response["body"]
	if not body is Dictionary or not body.get("needsAcceptance") is bool:
		return {"success": false, "result": "unexpected terms response: %s" % str(body)}
	return {"success": true, "needs": body["needsAcceptance"]}


## Records that the account accepts the service's current version.
## {success, result}: the reply, or the reason it was refused.
static func accept(service: DataService) -> Dictionary:
	if service.token == "":
		return {"success": false, "result": "not signed in"}
	var response: Dictionary = await service.send(HTTPClient.METHOD_POST, "/admin/account/terms/accept", "{}", true)
	if not response["ok"]:
		return {"success": false, "result": response["error"]}
	return {"success": true, "result": response["body"]}
