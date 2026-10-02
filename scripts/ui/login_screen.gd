class_name LoginScreen
extends CanvasLayer

## The account/character picker: sign in to the data service, list the
## characters, hand the chosen uuid to the game server. AccountForm is the
## sign-in side, CharacterStage the account's -- the whole panel, sized for
## a thumb; the leaderboard is on the in-game Menu. Signed in, the form
## gives way to a SignedInRow and the email is kept (LastEmail). TermsGate covers an account yet to accept the
## Terms of Use; the "?" opens How to Play (HowToPanel).

signal character_chosen(email: String, password: String, character_uuid: String)

const HOW_TO_BUTTON := int(TouchSize.ROW)
## The game's logo (the executable icon), shown in place of a plain "OpenRealm" title.
## Loaded at runtime, not preloaded: a bad/unimported icon must not fail the whole
## script compile (that took the client down when the icon import went stale).
const LOGO_PATH := "res://icon.png"

var data_service: DataService
var game_data: GameData
## Set by Main after build so the server picker can retarget the connection.
var client_config: ClientConfig
var last_email := LastEmail.new()
## Desktop auto-login: the session token of the last sign-in, reused on launch so
## the password is not retyped. Path is left empty (a no-op) on web and in tests;
## Main sets it only on desktop. See resume().
var saved_session := SavedSession.new()

var _backdrop: LoginBackdrop
var _server_select: ServerSelect
var _form: AccountForm
var _account: SignedInRow
var _panel: PanelContainer
var _status: Label
var _stage: CharacterStage
var _how_to: HowToPanel
var _how_to_button: Button
var _terms: TermsGate


func _init(service: DataService = null, content: GameData = null) -> void:
	data_service = service
	game_data = content


func _ready() -> void:
	layer = 20
	_backdrop = LoginBackdrop.attach(self, game_data)
	# A ScrollContainer so a phone can reach the whole panel when it is taller
	# than a short landscape screen; the panel still centres across the width.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(holder)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(_panel)

	var column := InventoryLayout.column(_panel)

	var header := HBoxContainer.new()
	column.add_child(header)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(HOW_TO_BUTTON, 0)
	header.add_child(spacer)
	var title := TextureRect.new()
	var logo_texture := load(LOGO_PATH) as Texture2D
	if logo_texture != null:
		title.texture = logo_texture
	title.custom_minimum_size = Vector2(0, 52)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_how_to_button = HowToPanel.badge(header, HOW_TO_BUTTON, func() -> void: _how_to.open())

	# Server picker above the sign-in fields; applies the choice to the config
	# the connection reads. Hides itself when /servers is empty/unreachable.
	_server_select = ServerSelect.new(data_service, _apply_server)
	column.add_child(_server_select)

	_form = AccountForm.new(data_service)
	_form.submitted.connect(_on_login_pressed)
	_form.status_changed.connect(set_status)
	column.add_child(_form)
	_account = SignedInRow.new(func() -> void:
		data_service.sign_out()
		saved_session.forget()
		forget_characters("Signed out."))
	column.add_child(_account)

	_stage = CharacterStage.new(data_service, game_data)
	_stage.status_changed.connect(set_status)
	_stage.chosen.connect(func(uuid: String) -> void:
		character_chosen.emit(_form.email_text(), _form.password_text(), uuid))
	column.add_child(_stage)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	column.add_child(_status)

	_how_to = HowToPanel.new()
	add_child(_how_to)
	_terms = TermsGate.new()
	add_child(_terms)
	# Every field and button a thumb's height: a phone signs in here too.
	for part in [_form, _account, _how_to, _terms]:
		TouchSize.grow_all(part)


func _process(_delta: float) -> void:
	if visible:
		PanelFit.shrink(_panel)   # a short window shrinks it rather than losing the bottom


func prefill(email: String, password: String) -> void:
	_form.prefill(email, password)


func forget_characters(status: String) -> void:
	_stage.forget()
	_form.visible = true
	_account.visible = false
	visible = true
	set_status(status)


## Point the connection at the picked server. On TLS web that means swapping the
## nginx wss route; on native it's the node's own host:port. Mirrors ServerAddress.
func _apply_server(server: Dictionary) -> void:
	if client_config == null:
		return
	client_config.websocket = true
	if client_config.secure:
		client_config.socket_path = str(server.get("route", client_config.socket_path))
	else:
		client_config.host = str(server.get("host", client_config.host))
		client_config.port = int(server.get("webSocketPort", client_config.port))
		client_config.socket_path = ""


func set_status(text: String, is_error := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1, 0.5, 0.5) if is_error else Color(0.8, 0.8, 0.8))


func _on_login_pressed() -> void:
	if _form.email_text() == "":
		set_status("Enter an email address.", true)
		return
	_form.set_busy(true)
	set_status("Signing in to %s ..." % data_service.base_url)
	_listed(await AccountSignIn.sign_in(data_service, _form.email_text(), _form.password_text(),
		_terms.ask))


## Desktop auto-login: list the account's characters with the saved session token,
## no password. The data service and game server both accept the session token, so
## on success the picker opens signed in; on an expired/invalid token the saved
## session is dropped and the ordinary sign-in form is shown (prefilled email).
func resume(email: String) -> void:
	_form.prefill(email, "")
	_form.set_busy(true)
	set_status("Signing in as %s ..." % email)
	var got: Dictionary = await AccountSignIn.characters(data_service)
	if got["success"]:
		last_email.save(email)
		_listed(got)
	else:
		saved_session.forget()
		data_service.sign_out()
		_form.set_busy(false)
		_form.visible = true
		set_status("Saved sign-in expired -- please sign in.")


## Select Character on the death screen: the account again, the session
## still held, the fallen one now in the graveyard; sign in only if that fails.
func return_after_death() -> void:
	visible = true
	_form.set_busy(true)
	set_status("Loading characters ...")
	var got: Dictionary = await AccountSignIn.characters(data_service)
	if not got["success"]:
		_form.set_busy(false)
		forget_characters("Your character was lost. Sign in to choose another.")
		return
	_listed(got)


func _listed(got: Dictionary) -> void:
	_form.set_busy(false)
	if got["success"]:
		last_email.save(_form.email_text())
		# Desktop only (path is empty elsewhere): keep the token, not the password,
		# so the next launch can resume() without a sign-in.
		saved_session.save(_form.email_text(), data_service.account_guid, data_service.token)
		_form.visible = false
		_account.show_for(_form.email_text())
		_stage.game_data = game_data
		_stage.show_account(got["characters"])
	else:
		set_status(got["result"], true)
