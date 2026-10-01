class_name SavedSession
extends RefCounted

## The last successful sign-in's session token, kept on DESKTOP only so the next
## launch signs in without the password. Not the password -- the data service's
## session token, which expires in ~2 days; a stale one simply falls back to the
## sign-in form. Never enabled on web (a shared browser): Main leaves the path
## empty there, and an empty path reads and writes nothing, as LastEmail does.
## Kept in a ConfigFile under user:// beside the guest account and last email.

const DEFAULT_PATH := "user://session.cfg"
const SECTION := "session"

var path := ""


func _init(file_path := "") -> void:
	path = file_path


## {email, account_guid, token} of the kept session, or {} when none is kept
## (or the path is empty, which is every test's and every web build's).
func read() -> Dictionary:
	var file := ConfigFile.new()
	if path == "" or file.load(path) != OK:
		return {}
	var email := str(file.get_value(SECTION, "email", ""))
	var guid := str(file.get_value(SECTION, "account_guid", ""))
	var token := str(file.get_value(SECTION, "token", ""))
	if email == "" or guid == "" or token == "":
		return {}
	return {"email": email, "account_guid": guid, "token": token}


func save(email: String, account_guid: String, token: String) -> void:
	if path == "" or email == "" or account_guid == "" or token == "":
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "email", email)
	file.set_value(SECTION, "account_guid", account_guid)
	file.set_value(SECTION, "token", token)
	file.save(path)


func forget() -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
