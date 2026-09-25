class_name CharacterDeleter
extends VBoxContainer

## "Delete", and the question it asks before anything is sent.
##
## The web client's Delete button asks `Delete <class>? This is permanent!`
## through the browser's confirm() and, on yes, deletes and re-fetches the
## account. Here the question is a row of Controls under the button, with
## the character it is about pinned when it was asked: a confirmation
## answers for that one character, whatever the list has moved to since,
## and anything that changes the pick puts the question away (`cancel`).

signal deleted(characters: Array)
signal failed(reason: String)

const DANGER := Color(1.0, 0.45, 0.4)

var data_service: DataService
var game_data: GameData

var delete_button: Button
var question: VBoxContainer
var prompt: Label
var confirm_button: Button

var _asked_for := {}
var _busy := false


func _ready() -> void:
	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.add_theme_color_override("font_color", DANGER)
	add_child(TouchSize.grow(delete_button))

	# The question over its two answers, which share the row between them.
	question = VBoxContainer.new()
	question.visible = false
	add_child(question)
	prompt = Label.new()
	prompt.add_theme_color_override("font_color", DANGER)
	question.add_child(prompt)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 8)
	question.add_child(answers)
	confirm_button = TouchSize.grow(InventoryLayout.button(answers, "Delete forever", confirm))
	confirm_button.add_theme_color_override("font_color", DANGER)
	var keep := TouchSize.grow(InventoryLayout.button(answers, "Keep", cancel))
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Asks about `character`; nothing is sent until the answer is yes.
func ask(character: Dictionary) -> void:
	if character.is_empty() or _busy:
		return
	_asked_for = character
	prompt.text = "Delete %s? This is permanent!" % label_for(character)
	question.visible = true
	delete_button.visible = false


func cancel() -> void:
	if _busy:
		return
	_asked_for = {}
	question.visible = false
	delete_button.visible = true


func is_asking() -> bool:
	return question.visible


func confirm() -> void:
	if _asked_for.is_empty() or _busy:
		return
	_busy = true
	confirm_button.disabled = true
	confirm_button.text = "Deleting ..."
	var result: Dictionary = await CharacterDeletion.run(
		data_service, str(_asked_for.get("characterUuid", "")))
	_busy = false
	confirm_button.disabled = false
	confirm_button.text = "Delete forever"
	cancel()
	if result["success"]:
		deleted.emit(result["characters"])
	else:
		failed.emit(str(result["result"]))


func label_for(character: Dictionary) -> String:
	var class_id := int(character.get("characterClass", 0))
	return game_data.classes_art.display_name(class_id) if game_data else "class %d" % class_id
