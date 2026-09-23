class_name LoginScreen
extends CanvasLayer

## Minimal account/character picker.
##
## The game server's login handshake needs a characterUuid, which only the data
## service knows, so the flow is: authenticate against the data service, list
## the account's characters, then hand the chosen uuid to the game server.
## The sign-in side is AccountForm (and a guest, and registering); the
## account's side -- the characters, Enter realm, the class grid -- is
## CharacterStage, and beside it, once signed in, the LeaderboardPanel.
## Between the two, an account that has not accepted the
## current Terms of Use is shown them (TermsGate) over the whole screen. The
## "?" beside the title opens the web client's How to Play (HowToPanel), on
## both sides, as the web puts one on each screen.

signal character_chosen(email: String, password: String, character_uuid: String)

const HOW_TO_BUTTON := 28

var data_service: DataService
var game_data: GameData

var _backdrop: LoginBackdrop
var _form: AccountForm
var _status: Label
var _stage: CharacterStage
var _board: LeaderboardPanel
var _how_to: HowToPanel
var _how_to_button: Button
var _terms: TermsGate


func _ready() -> void:
	layer = 20
	_backdrop = LoginBackdrop.attach(self, game_data)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var side_by_side := HBoxContainer.new()
	side_by_side.add_theme_constant_override("separation", 16)
	centre.add_child(side_by_side)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side_by_side.add_child(panel)

	var column := InventoryLayout.column(panel)

	# The title centred between the "?" and a spacer of its width.
	var header := HBoxContainer.new()
	column.add_child(header)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(HOW_TO_BUTTON, 0)
	header.add_child(spacer)
	var title := Label.new()
	title.text = "OpenRealm"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_how_to_button = HowToPanel.badge(header, HOW_TO_BUTTON, func() -> void: _how_to.open())

	_form = AccountForm.new(data_service)
	_form.submitted.connect(_on_login_pressed)
	_form.status_changed.connect(set_status)
	column.add_child(_form)

	_stage = CharacterStage.new(data_service, game_data)
	_stage.status_changed.connect(set_status)
	_stage.chosen.connect(func(uuid: String) -> void:
		character_chosen.emit(_form.email_text(), _form.password_text(), uuid))
	column.add_child(_stage)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	column.add_child(_status)

	_board = LeaderboardPanel.new()
	_board.game_data = game_data
	side_by_side.add_child(_board)
	_how_to = HowToPanel.new()
	add_child(_how_to)
	_terms = TermsGate.new()
	add_child(_terms)


func prefill(email: String, password: String) -> void:
	_form.prefill(email, password)


## Drops the character list and asks for a fresh sign-in.
func forget_characters(status: String) -> void:
	_stage.forget()
	_board.forget()
	visible = true
	set_status(status)


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


## Select Character on the death screen: the account again, with the session
## still held -- the fallen one now in the graveyard -- as the web client
## does; asking to sign in only if that fails.
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
		_stage.game_data = game_data
		_stage.show_account(got["characters"])
		# Loaded every time the characters are, as the web client does; not
		# awaited, so the characters never wait on it.
		_board.game_data = game_data
		_board.refresh(data_service)
	else:
		set_status(got["result"], true)
