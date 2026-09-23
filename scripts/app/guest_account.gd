class_name GuestAccount
extends RefCounted

## "Play as Guest": the web client's guest account, and where it is kept.
##
## A guest is an ordinary account made on the spot -- guest_<8 hex>@openrealm.net,
## a sixteen-hex password, a name off the web client's list -- registered
## with `guest: true`, which the data service answers with the DEMO
## provision and an empty account. The credentials are kept so the next
## press is the same guest, as the web keeps them in localStorage: here in
## a ConfigFile under user://, which on the desktop is the user data folder
## and in a browser is the page's IndexedDB. Saved credentials that no
## longer sign in are dropped and a fresh guest is made.

const DEFAULT_PATH := "user://guest.cfg"
const SECTION := "guest"
## main.js GUEST_NAMES.
const NAMES := ["Utanu", "Gharr", "Yimi", "Idrae", "Odaru", "Scheev", "Zhiar", "Itani",
	"Serl", "Oeti", "Tiar", "Issz", "Oshyu", "Deyst", "Oalei", "Vorv",
	"Iatho", "Uoro", "Urake", "Eashy", "Queq", "Rayr", "Tal", "Drac",
	"Yangu", "Eango", "Rilr", "Ehoni", "Risrr", "Sek", "Eati", "Laen",
	"Eendi", "Ril", "Darq", "Seus", "Radph", "Orothi", "Vorck", "Saylt",
	"Iawa", "Iri", "Lauk", "Lorz"]

var path := DEFAULT_PATH
var rng := RandomNumberGenerator.new()


## A fresh set: {email, password, name}.
func make() -> Dictionary:
	return {"email": "guest_%s@openrealm.net" % _hex(), "password": _hex() + _hex(),
		"name": NAMES[rng.randi_range(0, NAMES.size() - 1)]}


## What was kept, or {} when nothing usable was.
func saved() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {}
	var email := str(file.get_value(SECTION, "email", ""))
	var password := str(file.get_value(SECTION, "password", ""))
	return {} if email == "" or password == "" else {"email": email, "password": password}


func save(credentials: Dictionary) -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "email", credentials["email"])
	file.set_value(SECTION, "password", credentials["password"])
	file.save(path)


func forget() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The guest to sign in as: the kept one if it still signs in, otherwise a
## new one registered and kept. Returns {success, email, password, created},
## or {success: false, result: reason}.
func obtain(service: DataService) -> Dictionary:
	var kept := saved()
	if not kept.is_empty():
		var login: Dictionary = await service.login(kept["email"], kept["password"])
		if login["success"]:
			return {"success": true, "email": kept["email"], "password": kept["password"], "created": false}
		forget()
	var fresh := make()
	var registered: Dictionary = await service.register(fresh["email"], fresh["password"], fresh["name"], true)
	if not registered["success"]:
		return {"success": false, "result": registered["result"]}
	save(fresh)
	return {"success": true, "email": fresh["email"], "password": fresh["password"], "created": true}


## Eight lowercase hex digits, as the web's Math.random().toString(16).slice(2, 10).
func _hex() -> String:
	return "%08x" % rng.randi()
