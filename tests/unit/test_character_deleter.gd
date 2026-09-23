extends GutTest

## Deleting a living character from the sign-in panel: the question first,
## one DELETE on yes, and the account listed again.

var screen: LoginScreen
var service: DataService
var backend: FakeHttpBackend
var data: GameData

const LIVING := [
	{"characterUuid": "c1", "characterClass": 0, "stats": {"hp": 200, "spd": 15}},
	{"characterUuid": "c2", "characterClass": 2, "stats": {"hp": 300, "spd": 20}},
]


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	add_child_autofree(service)
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	screen = LoginScreen.new()
	screen.data_service = service
	screen.game_data = data
	add_child_autofree(screen)


func _sign_in(characters: Array) -> CharacterStage:
	backend.push_json(200, {"accountGuid": "g", "token": "t"})
	# The Terms of Use check between the login and the list: already accepted.
	backend.push_json(200, {"currentVersion": 1, "acceptedVersion": 1, "needsAcceptance": false})
	backend.push_json(200, {"characters": characters})
	screen.prefill("me@example.com", "pw")
	await screen._on_login_pressed()
	return screen._stage


func _requests_since(before: int) -> Array:
	return backend.requests.slice(before)


func test_delete_is_offered_for_a_living_pick_only():
	var stage := await _sign_in(LIVING + [
		{"characterUuid": "c3", "characterClass": 0, "stats": {}, "deleted": "2026-01-01T00:00:00Z"}])
	assert_true(stage.deleter.visible)
	stage.picker.tabs.current_tab = CharacterPicker.GRAVEYARD
	assert_false(stage.deleter.visible, "the graveyard's are deleted already")
	stage.picker.tabs.current_tab = CharacterPicker.ALIVE
	assert_true(stage.deleter.visible)


func test_an_account_with_no_one_living_has_no_delete():
	var stage := await _sign_in([])
	assert_false(stage.deleter.visible)


func test_delete_asks_first_and_sends_nothing():
	var stage := await _sign_in(LIVING)
	var before := backend.requests.size()
	stage.picker.list.select(1)
	stage.deleter.delete_button.pressed.emit()
	assert_true(stage.deleter.is_asking())
	assert_false(stage.deleter.delete_button.visible)
	assert_eq(stage.deleter.prompt.text, "Delete Wizard? This is permanent!")
	assert_eq(_requests_since(before).size(), 0, "nothing is sent on the first press")


func test_keep_puts_the_question_away():
	var stage := await _sign_in(LIVING)
	var before := backend.requests.size()
	stage.ask_delete()
	stage.deleter.cancel()
	assert_false(stage.deleter.is_asking())
	assert_true(stage.deleter.delete_button.visible)
	await stage.deleter.confirm()
	assert_eq(_requests_since(before).size(), 0, "a confirm with no question sends nothing")


func test_moving_the_pick_puts_the_question_away():
	var stage := await _sign_in(LIVING)
	stage.ask_delete()
	stage.picker.list.select(1)
	stage.picker.list.item_selected.emit(1)
	assert_false(stage.deleter.is_asking())
	stage.ask_delete()
	stage.picker.tabs.current_tab = CharacterPicker.GRAVEYARD
	assert_false(stage.deleter.is_asking())


func test_confirming_deletes_that_character_and_lists_the_account_again():
	var stage := await _sign_in(LIVING)
	stage.picker.list.select(1)
	stage.ask_delete()
	var before := backend.requests.size()
	backend.push_json(200, {"message": "successfully deleted character c2", "reason": "Character deleted"})
	backend.push_json(200, {"characters": [LIVING[0],
		{"characterUuid": "c2", "characterClass": 2, "stats": {}, "deleted": "2026-09-23T10:00:00"}]})
	await stage.deleter.confirm()
	var sent := _requests_since(before)
	assert_eq(sent.size(), 2, "the delete, then the account")
	assert_eq(sent[0]["method"], HTTPClient.METHOD_DELETE)
	assert_eq(sent[0]["url"], "http://data.test/data/account/character/c2")
	assert_true(sent[0]["headers"].has("Authorization: t"), "the raw token, as every call")
	assert_eq(sent[1]["method"], HTTPClient.METHOD_GET)
	assert_eq(sent[1]["url"], "http://data.test/data/account/g")
	assert_eq(stage.picker.alive_count(), 1)
	assert_eq(stage.picker.dead_count(), 1, "the service keeps it, in the graveyard")
	assert_false(stage.deleter.is_asking())
	assert_eq(screen._status.text, "Character deleted.")


func test_a_refused_delete_says_why_and_keeps_the_list():
	var stage := await _sign_in(LIVING)
	stage.ask_delete()
	backend.push_json(400, {"message": "Failed to save character stats", "reason": "Invalid token"})
	await stage.deleter.confirm()
	assert_string_contains(screen._status.text, "Could not delete the character")
	assert_string_contains(screen._status.text, "Invalid token")
	assert_eq(stage.picker.alive_count(), 2)
	assert_false(stage.deleter.confirm_button.disabled, "usable again")


func test_a_delete_whose_relist_fails_says_so():
	var stage := await _sign_in(LIVING)
	stage.ask_delete()
	backend.push_json(200, {"reason": "Character deleted"})
	backend.push_json(500, {"reason": "down"})
	await stage.deleter.confirm()
	assert_string_contains(screen._status.text, "Deleted, but the character list could not be loaded")


func test_nothing_is_sent_without_a_session():
	var result: Dictionary = await CharacterDeletion.run(service, "c1")
	assert_false(result["success"])
	assert_eq(result["result"], "not signed in")
	assert_eq(backend.requests.size(), 0)


func test_without_content_the_question_names_the_class_id():
	var deleter := CharacterDeleter.new()
	add_child_autofree(deleter)
	deleter.ask({"characterUuid": "c9", "characterClass": 7})
	assert_eq(deleter.prompt.text, "Delete class 7? This is permanent!")
	deleter.ask({})
	assert_eq(deleter.prompt.text, "Delete class 7? This is permanent!", "an empty pick asks nothing new")
