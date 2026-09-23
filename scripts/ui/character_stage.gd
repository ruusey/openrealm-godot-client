class_name CharacterStage
extends VBoxContainer

## The account's side of the sign-in panel: the characters to pick from,
## "Enter realm", "Delete", and the class grid that makes a new one.
##
## Hidden until an account is signed in. Choosing -- a double-click in the
## list, Enter realm, or "Create & play" on a fresh character -- hands the
## uuid up; what it says about itself goes up as status, for the panel's one
## status line.

signal chosen(character_uuid: String)
signal status_changed(text: String, is_error: bool)

var data_service: DataService
var game_data: GameData

var picker: CharacterPicker
var play_button: Button
var deleter: CharacterDeleter
var creator: CharacterCreator
var stats_card: CharacterStatsCard


func _init(service: DataService = null, content: GameData = null) -> void:
	data_service = service
	game_data = content


func _ready() -> void:
	# Hidden as a whole until there is an account, so an empty stage takes
	# no room in the panel.
	visible = false
	picker = CharacterPicker.new()
	picker.game_data = game_data
	picker.visible = false
	picker.activated.connect(play)
	add_child(picker)
	stats_card = CharacterStatsCard.new()
	stats_card.data_service = data_service
	add_child(stats_card)
	picker.stats_requested.connect(func(character: Dictionary) -> void:
		stats_card.open(character, CharacterPicker.class_label(character, game_data)))

	play_button = Button.new()
	play_button.text = "Enter realm"
	play_button.visible = false
	play_button.pressed.connect(play)
	add_child(play_button)

	deleter = CharacterDeleter.new()
	deleter.data_service = data_service
	deleter.visible = false
	deleter.deleted.connect(_on_deleted)
	deleter.failed.connect(func(reason: String) -> void:
		status_changed.emit("Could not delete the character: %s" % reason, true))
	add_child(deleter)
	deleter.delete_button.pressed.connect(ask_delete)
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
	add_child(creator)


func show_account(characters: Array) -> void:
	visible = true
	picker.game_data = game_data
	picker.show_characters(characters)
	creator.game_data = game_data
	creator.fill()
	creator.visible = true
	# Nothing to play, but a graveyard is still worth a look.
	picker.visible = picker.alive_count() > 0 or picker.dead_count() > 0
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
