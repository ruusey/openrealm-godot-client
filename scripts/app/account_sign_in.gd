class_name AccountSignIn
extends RefCounted

## From credentials, or a session already held, to the account's characters.
##
## Both come back the same way: {success, characters} once listed, or
## {success: false, result: reason}. The second is what the death screen's
## Select Character uses: the web client re-fetches the account with the
## token it still holds rather than asking the player to sign in again.
##
## Between signing in and the list is the Terms of Use gate, where both
## references put it: an account that has not accepted the current version
## is asked -- `agree`, awaited, true for "I Agree" -- and goes no further
## on a refusal. Every way it can fail signs the session out again, so
## nothing half signed in is left for the death screen's path to reuse.

const UNVERIFIED := "Could not verify Terms of Use acceptance. Please try again."
const DECLINED := "The Terms of Use were declined -- signed out."
const UNRECORDED := "Could not record your acceptance. Please sign in and try again."


static func sign_in(service: DataService, email: String, password: String,
		agree: Callable = Callable()) -> Dictionary:
	var login: Dictionary = await service.login(email, password)
	if not login["success"]:
		return {"success": false, "result": str(login["result"])}
	var terms: Dictionary = await accept_terms(service, agree)
	if not terms["success"]:
		service.sign_out()
		return terms
	return await characters(service)


## {success} once the account has accepted the current terms, now or
## before; otherwise the reason, for the status line.
static func accept_terms(service: DataService, agree: Callable) -> Dictionary:
	var status: Dictionary = await AccountTerms.status(service)
	if not status["success"]:
		push_warning("[terms] status check failed, blocking: %s" % status["result"])
		return {"success": false, "result": UNVERIFIED}
	if not status["needs"]:
		return {"success": true}
	var agreed: bool = false
	if agree.is_valid():
		agreed = await agree.call()
	if not agreed:
		return {"success": false, "result": DECLINED}
	var accepted: Dictionary = await AccountTerms.accept(service)
	if not accepted["success"]:
		push_warning("[terms] accept failed, blocking: %s" % accepted["result"])
		return {"success": false, "result": UNRECORDED}
	return {"success": true}


static func characters(service: DataService) -> Dictionary:
	var listed: Dictionary = await service.fetch_characters()
	if not listed["success"]:
		return {"success": false, "result": "Signed in, but the character list could not be loaded."}
	return {"success": true, "characters": listed["characters"]}
