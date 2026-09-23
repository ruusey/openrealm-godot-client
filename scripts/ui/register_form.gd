class_name RegisterForm
extends VBoxContainer

## A new account: the web client's register form -- username, email and
## password -- in Godot's own controls.
##
## One POST, /admin/account/register with `guest: false`; the data service
## answers a normal account with the PLAYER provision and a first character
## (a Wizard), so the picker the player lands on is not empty. On success it
## hands the credentials up and the sign-in form signs in with them, as the
## web client signs in straight after registering. "Back to sign in" leaves
## it without sending anything.

signal registered(email: String, password: String)
signal status_changed(text: String, is_error: bool)
signal back()

var data_service: DataService

var account_name: LineEdit
var email: LineEdit
var password: LineEdit
var button: Button
var back_button: Button


func _init(service: DataService = null) -> void:
	data_service = service


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	account_name = _field("username", false)
	email = _field("email", false)
	password = _field("password", true)
	password.text_submitted.connect(func(_text: String) -> void: submit())
	button = Button.new()
	button.text = "Register"
	button.pressed.connect(submit)
	add_child(button)
	back_button = Button.new()
	back_button.text = "Back to sign in"
	back_button.flat = true
	back_button.pressed.connect(func() -> void: back.emit())
	add_child(back_button)


## What is wrong with the fields before anything is sent, or "".
func problem() -> String:
	if account_name.text.strip_edges() == "":
		return "Enter a username."
	if email.text.strip_edges() == "" or not "@" in email.text:
		return "Enter an email address."
	if password.text == "":
		return "Enter a password."
	return ""


func submit() -> void:
	var wrong := problem()
	if wrong != "":
		status_changed.emit(wrong, true)
		return
	set_busy(true)
	status_changed.emit("Creating the account ...", false)
	var result: Dictionary = await data_service.register(email.text.strip_edges(), password.text,
		account_name.text.strip_edges(), false)
	set_busy(false)
	if not result["success"]:
		status_changed.emit("Could not register: %s" % result["result"], true)
		return
	registered.emit(email.text.strip_edges(), password.text)


func set_busy(busy: bool) -> void:
	button.disabled = busy
	back_button.disabled = busy


func _field(hint: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.secret = secret
	add_child(field)
	return field
