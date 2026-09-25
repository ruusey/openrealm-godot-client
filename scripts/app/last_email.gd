class_name LastEmail
extends RefCounted

## The email the last successful sign-in used, so the form is filled in
## next time. Kept in a ConfigFile under user:// -- on the desktop the user
## data folder, in a browser the page's IndexedDB -- beside the guest
## account. Only the email: a password is never written down here. An
## empty path, which is every test's, reads and writes nothing.

const DEFAULT_PATH := "user://last_email.cfg"
const SECTION := "sign_in"

var path := ""


func _init(file_path := "") -> void:
	path = file_path


func read() -> String:
	var file := ConfigFile.new()
	if path == "" or file.load(path) != OK:
		return ""
	return str(file.get_value(SECTION, "email", ""))


func save(email: String) -> void:
	if path == "" or email == "":
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "email", email)
	file.save(path)
