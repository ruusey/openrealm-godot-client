class_name AccountForm
extends VBoxContainer

## The email and password fields, the sign-in button -- Enter in the
## password field standing in for it -- "Play as Guest" under it, and a link
## that swaps them for the register form (RegisterForm).
## Reads its own fields back for whoever signs in, so the screen holds no
## copy of the credentials. "Play as Guest" fills the fields with a guest
## account (GuestAccount: the kept one, or a new one) and presses Sign in;
## a new guest's credentials are shown once, in a field that can be
## selected and copied, as the web's popup shows them.

signal submitted()
signal status_changed(text: String, is_error: bool)

var data_service: DataService
var guest := GuestAccount.new()

var email: LineEdit
var password: LineEdit
var button: Button
var guest_button: Button
var guest_notice: VBoxContainer
var guest_details: LineEdit
var register_link: Button
## The sign-in fields and buttons, hidden while the register form is up.
var sign_in: VBoxContainer
var register: RegisterForm


func _init(service: DataService = null) -> void:
	data_service = service


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	sign_in = VBoxContainer.new()
	sign_in.add_theme_constant_override("separation", 8)
	add_child(sign_in)
	email = LineEdit.new()
	email.placeholder_text = "email"
	sign_in.add_child(email)

	password = LineEdit.new()
	password.placeholder_text = "password"
	password.secret = true
	password.text_submitted.connect(func(_text: String) -> void: submitted.emit())
	sign_in.add_child(password)

	button = Button.new()
	button.text = "Sign in"
	button.pressed.connect(func() -> void: submitted.emit())
	sign_in.add_child(button)

	guest_button = Button.new()
	guest_button.text = "Play as Guest"
	guest_button.pressed.connect(play_as_guest)
	sign_in.add_child(guest_button)

	guest_notice = VBoxContainer.new()
	guest_notice.visible = false
	add_child(guest_notice)
	guest_notice.add_child(HudWidgets.label("Guest account created -- save these to sign in again:",
		12, PlayerHud.GOLD))
	guest_details = LineEdit.new()
	guest_details.editable = false
	guest_details.select_all_on_focus = true
	guest_notice.add_child(guest_details)

	register_link = Button.new()
	register_link.text = "No account? Register"
	register_link.flat = true
	register_link.pressed.connect(show_register)
	sign_in.add_child(register_link)
	register = RegisterForm.new(data_service)
	register.visible = false
	register.status_changed.connect(func(text: String, error: bool) -> void: status_changed.emit(text, error))
	register.back.connect(show_sign_in)
	register.registered.connect(_on_registered)
	add_child(register)


func show_register() -> void:
	sign_in.visible = false
	register.visible = true


func show_sign_in() -> void:
	register.visible = false
	sign_in.visible = true


## A new account signs straight in, as the web client does after registering.
func _on_registered(new_email: String, new_password: String) -> void:
	show_sign_in()
	prefill(new_email, new_password)
	submitted.emit()


func prefill(email_text: String, password_text: String) -> void:
	email.text = email_text
	password.text = password_text


func email_text() -> String:
	return email.text.strip_edges()


func password_text() -> String:
	return password.text


func play_as_guest() -> void:
	set_busy(true)
	status_changed.emit("Getting a guest account ...", false)
	var got: Dictionary = await guest.obtain(data_service)
	set_busy(false)
	if not got["success"]:
		status_changed.emit("Could not make a guest account: %s" % got["result"], true)
		return
	prefill(got["email"], got["password"])
	if got["created"]:
		show_guest_credentials(got["email"], got["password"])
	submitted.emit()


func show_guest_credentials(guest_email: String, guest_password: String) -> void:
	guest_details.text = "%s  /  %s" % [guest_email, guest_password]
	guest_notice.visible = true


## Dead while a sign-in is in flight, so a second press cannot start another.
func set_busy(busy: bool) -> void:
	button.disabled = busy
	guest_button.disabled = busy
