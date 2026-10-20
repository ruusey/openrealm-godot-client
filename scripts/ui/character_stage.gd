class_name CharacterStage
extends VBoxContainer

## The account's side of the sign-in panel: the characters to pick from,
## "Enter realm", "Delete", and the class grid that makes a new one.
##
## Two columns, the characters left and the class grid right, every row a
## thumb's height (TouchSize): at a mouse's size they were hard to hit.
##
## Hidden until an account is signed in. Choosing -- a double-click in the
## list, Enter realm, or "Create & play" on a fresh character -- hands the
## uuid up; what it says about itself goes up as status, for the panel's one
## status line.

signal chosen(character_uuid: String)
signal status_changed(text: String, is_error: bool)

var data_service: DataService
var game_data: GameData

## Narrower than this (in canvas rows/cols, the space the columns are sized in)
## the two columns cannot sit side by side, so they stack instead of running
## the class grid off the right on a phone.
const STACK_BELOW_PX := 720.0

var picker: CharacterPicker
var play_button: Button
var deleter: CharacterDeleter
var creator: CharacterCreator
var stats_card: CharacterStatsCard

var _characters: VBoxContainer
var _columns: BoxContainer
var _fame_label: Label
var _vault_label: Label
var _add_chest_button: Button
## One add at a time -- rapid clicks each read a stale count, all pass the cap and
## fire concurrent creates, inflating the display past the cap (the web client's bug).
var _adding_chest := false
var _chest_confirm: ConfirmPopup


func _init(service: DataService = null, content: GameData = null) -> void:
	data_service = service
	game_data = content


func _ready() -> void:
	# Hidden as a whole until there is an account, so an empty stage takes
	# no room in the panel.
	visible = false
	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", 16)
	add_child(_columns)
	_characters = VBoxContainer.new()
	_characters.custom_minimum_size.x = 300 if PhoneLayout.on else 340
	_characters.add_theme_constant_override("separation", 8)
	_columns.add_child(_characters)
	picker = CharacterPicker.new()
	picker.game_data = game_data
	picker.visible = false
	picker.activated.connect(play)
	_characters.add_child(picker)
	stats_card = CharacterStatsCard.new()
	stats_card.data_service = data_service
	add_child(stats_card)
	picker.stats_requested.connect(func(character: Dictionary) -> void:
		stats_card.open(character, CharacterPicker.class_label(character, game_data)))

	play_button = Button.new()
	play_button.text = "Enter realm"
	play_button.visible = false
	play_button.pressed.connect(play)
	# Enter realm and Delete share a row on a phone, Delete's question taking it
	# over while it is asked.
	var actions: BoxContainer = HBoxContainer.new() if PhoneLayout.on else _characters
	if PhoneLayout.on:
		actions.add_theme_constant_override("separation", 8)
		_characters.add_child(actions)
		play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(TouchSize.grow(play_button, 20))

	deleter = CharacterDeleter.new()
	deleter.data_service = data_service
	deleter.visible = false
	deleter.deleted.connect(_on_deleted)
	deleter.failed.connect(func(reason: String) -> void:
		status_changed.emit("Could not delete the character: %s" % reason, true))
	actions.add_child(deleter)
	deleter.delete_button.pressed.connect(ask_delete)
	if PhoneLayout.on:
		deleter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deleter.question.visibility_changed.connect(func() -> void:
			play_button.visible = not deleter.is_asking() and picker.alive_count() > 0)
	# A question asked about one character is put away when the pick moves.
	picker.tabs.tab_changed.connect(func(_page: int) -> void: _offer_delete())
	picker.list.item_selected.connect(func(_index: int) -> void: _offer_delete())

	creator = CharacterCreator.new()
	creator.data_service = data_service
	creator.game_data = game_data
	creator.visible = false
	creator.created.connect(_on_created)
	creator.failed.connect(func(reason: String) -> void:
		status_changed.emit("Could not create the character: %s" % reason, true))
	_columns.add_child(creator)

	# Account-wide vault chest control (shown whenever signed in, even with no
	# characters): a count readout and an add button, capped server-side. Under
	# the characters on a phone, where a row of its own would run off the bottom.
	var vault_row := HBoxContainer.new()
	vault_row.add_theme_constant_override("separation", 12)
	(_characters if PhoneLayout.on else self).add_child(vault_row)
	_fame_label = Label.new()
	_fame_label.add_theme_color_override("font_color", PlayerHud.GOLD)
	vault_row.add_child(_fame_label)
	_vault_label = Label.new()
	_vault_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vault_row.add_child(_vault_label)
	_add_chest_button = Button.new()
	_add_chest_button.text = VaultChestPurchase.button_text("Add Chest")
	_add_chest_button.pressed.connect(func() -> void:
		if not _adding_chest and data_service != null:
			VaultChestPurchase.confirm(_chest_confirm, data_service, _on_add_chest))
	vault_row.add_child(_add_chest_button)
	_chest_confirm = ConfirmPopup.new()
	add_child(_chest_confirm)
	if PhoneLayout.on:
		TouchSize.tighten(self)

	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()


## The account's fame; LoginScreen re-reads it every frame it is up, so a
## purchase made from the home screen lands while it is open.
func refresh_fame() -> void:
	if visible and _fame_label != null and data_service != null:
		_fame_label.text = "Fame: %s" % Mastery.thousands(int(data_service.account.get("accountFame", 0)))


func _refresh_vault() -> void:
	if _vault_label == null:
		return
	_vault_label.text = "Vault Chests: %d" % data_service.chest_count()
	_add_chest_button.disabled = _adding_chest


## Adds a chest through the data service; the server enforces the cap and the new
## chest appears on the next vault entry. Re-reads the count from the reply.
func _on_add_chest() -> void:
	if _adding_chest or data_service == null:
		return
	_adding_chest = true
	_refresh_vault()
	var result := await data_service.create_chest()
	_adding_chest = false
	_refresh_vault()
	if result["success"]:
		status_changed.emit("Vault chest added (now %d). Enter your vault to use it."
			% data_service.chest_count(), false)
	else:
		status_changed.emit(str(result["result"]), true)


## Side by side where there is room, stacked on a phone so the class grid
## stays on screen instead of running off the right.
func _fit() -> void:
	if _columns != null:
		var view := TouchScale.panel_view(self)
		# A landscape phone keeps them side by side, shrunk a little to fit,
		# rather than stacked and shrunk by half.
		_columns.vertical = view.y > view.x if PhoneLayout.on else view.x < STACK_BELOW_PX


func show_account(characters: Array) -> void:
	visible = true
	_refresh_vault()
	_fit()
	picker.game_data = game_data
	picker.show_characters(characters)
	creator.game_data = game_data
	creator.fill()
	if PhoneLayout.on:
		TouchSize.tighten(creator)
	creator.visible = true
	# Nothing to play, but a graveyard is still worth a look.
	picker.visible = picker.alive_count() > 0 or picker.dead_count() > 0
	_characters.visible = picker.visible or PhoneLayout.on
	play_button.visible = picker.alive_count() > 0
	deleter.game_data = game_data
	_offer_delete()
	if picker.alive_count() == 0:
		status_changed.emit("No characters yet -- pick a class below to create one.", false)
	else:
		status_changed.emit("Pick a character.", false)


## Nothing listed: after a death that character is deleted, and picking it
## off a stale list is rejected at login.
func forget() -> void:
	visible = false
	picker.clear()
	picker.visible = false
	creator.visible = false
	play_button.visible = false
	stats_card.close()
	deleter.visible = false


func play() -> void:
	var character := picker.selected()
	if character.is_empty():
		status_changed.emit("Pick a living character first.", true)
		return
	stats_card.close()
	status_changed.emit("Connecting to the game server ...", false)
	chosen.emit(str(character.get("characterUuid", "")))


## Delete only where there is a living character picked; never in the
## graveyard, whose characters are already deleted.
func _offer_delete() -> void:
	deleter.cancel()
	deleter.visible = not picker.selected().is_empty()


func ask_delete() -> void:
	deleter.ask(picker.selected())


func _on_deleted(characters: Array) -> void:
	show_account(characters)
	status_changed.emit("Character deleted.", false)


## The account as the data service returned it after the create, with the
## new character last; "Create & play" goes straight in on it.
func _on_created(characters: Array, and_play: bool) -> void:
	show_account(characters)
	picker.select_newest()
	if and_play:
		play()
	else:
		status_changed.emit("Character created.", false)
