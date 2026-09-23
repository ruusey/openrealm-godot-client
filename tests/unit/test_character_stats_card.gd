extends GutTest

## Right-click a character in the picker: its lifetime stats, on a card.

var screen: LoginScreen
var service: DataService
var backend: FakeHttpBackend
var data: GameData

const ACCOUNT := [
	{"characterUuid": "c1", "characterClass": 0, "stats": {"hp": 200, "spd": 15}},
	{"characterUuid": "c2", "characterClass": 2, "stats": {"hp": 300, "spd": 20}},
	{"characterUuid": "c3", "characterClass": 2, "stats": {}, "deleted": "2026-01-01T00:00:00Z"},
]


## Holds every reply until released, so a report can still be on its way.
class HeldBackend extends FakeHttpBackend:
	signal released

	func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
		await released
		return super.perform(method, url, headers, body)


func _hold() -> HeldBackend:
	var held := HeldBackend.new()
	held.responses = backend.responses
	service.backend = held
	return held


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


func _sign_in() -> CharacterStage:
	backend.push_json(200, {"accountGuid": "g", "token": "t"})
	# The Terms of Use check between the login and the list: already accepted.
	backend.push_json(200, {"currentVersion": 1, "acceptedVersion": 1, "needsAcceptance": false})
	backend.push_json(200, {"characters": ACCOUNT})
	screen.prefill("me@example.com", "pw")
	await screen._on_login_pressed()
	return screen._stage


func _right_click(stage: CharacterStage, index: int) -> void:
	stage.picker.list.item_clicked.emit(index, Vector2.ZERO, MOUSE_BUTTON_RIGHT)


func _texts(node: Node) -> Array:
	var out: Array = []
	for child in node.find_children("*", "Label", true, false):
		out.append(child.text)
	return out


func test_right_click_asks_for_that_characters_report_and_shows_it():
	var stage := await _sign_in()
	var before := backend.requests.size()
	backend.push_json(200, {"killsTotal": 1234.0, "projectilesHit": 3.0, "projectilesMissed": 1.0})
	_right_click(stage, 1)
	await wait_process_frames(2)
	var card := stage.stats_card
	var sent: Array = backend.requests.slice(before)
	assert_eq(sent.size(), 1)
	assert_eq(sent[0]["method"], HTTPClient.METHOD_GET)
	assert_eq(sent[0]["url"], "http://data.test/data/account/character/c2/metrics")
	assert_true(sent[0]["headers"].has("Authorization: t"))
	assert_true(card.visible)
	assert_eq(card.title.text, "Wizard - Lifetime Stats")
	assert_false(card.message.visible)
	var texts := _texts(card.columns)
	assert_has(texts, "COMBAT")
	assert_has(texts, "1,234")
	assert_has(texts, "75%")
	assert_has(texts, LifetimeStats.NONE_YET, "no dungeons yet")


func test_a_left_click_opens_nothing():
	var stage := await _sign_in()
	var before := backend.requests.size()
	stage.picker.list.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_false(stage.stats_card.visible)
	assert_eq(backend.requests.size(), before)


func test_the_fallen_have_stats_too():
	var stage := await _sign_in()
	stage.picker.tabs.current_tab = CharacterPicker.GRAVEYARD
	var before := backend.requests.size()
	backend.push_json(200, {"deaths": 1.0})
	_right_click(stage, 0)
	await wait_process_frames(2)
	assert_string_ends_with(backend.requests.slice(before)[0]["url"], "/character/c3/metrics")


func test_it_says_loading_until_the_report_lands():
	var stage := await _sign_in()
	var card := stage.stats_card
	var held := _hold()
	backend.push_json(200, {"killsTotal": 5.0})
	card.open(ACCOUNT[0], "Barbarian")
	assert_true(card.message.visible)
	assert_eq(card.message.text, "Loading...")
	assert_false(card.columns.visible)
	held.released.emit()
	await wait_process_frames(2)
	assert_false(card.message.visible, "and the report once it has")
	assert_true(card.columns.visible)


func test_a_failure_says_why():
	var stage := await _sign_in()
	backend.push_json(400, {"message": "no", "reason": "Not authorized to view this character's metrics"})
	await stage.stats_card.open(ACCOUNT[0], "Barbarian")
	assert_true(stage.stats_card.message.visible)
	assert_string_contains(stage.stats_card.message.text, "Could not load stats")
	assert_string_contains(stage.stats_card.message.text, "Not authorized")


func test_closing_it_drops_a_report_still_on_its_way():
	var stage := await _sign_in()
	var card := stage.stats_card
	var held := _hold()
	backend.push_json(200, {"killsTotal": 5.0})
	card.open(ACCOUNT[0], "Barbarian")
	card.close()
	held.released.emit()
	await wait_process_frames(2)
	assert_false(card.visible)
	assert_true(card.message.visible, "the late report was not drawn")


func test_a_second_open_wins_over_the_first():
	var stage := await _sign_in()
	var card := stage.stats_card
	var held := _hold()
	backend.push_json(200, {"killsTotal": 111.0})
	backend.push_json(200, {"killsTotal": 222.0})
	card.open(ACCOUNT[0], "Barbarian")
	card.open(ACCOUNT[1], "Wizard")
	held.released.emit()
	await wait_process_frames(2)
	assert_eq(card.title.text, "Wizard - Lifetime Stats")
	assert_has(_texts(card.columns), "222")
	assert_does_not_have(_texts(card.columns), "111")


func test_the_x_escape_and_the_dim_all_close_it():
	var stage := await _sign_in()
	var card := stage.stats_card
	card.visible = true
	card.close_button.pressed.emit()
	assert_false(card.visible)
	card.visible = true
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	card._unhandled_input(escape)
	assert_false(card.visible)
	card.visible = true
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	card.get_child(0).gui_input.emit(click)
	assert_false(card.visible)


func test_dungeons_are_listed_when_there_are_some():
	var stage := await _sign_in()
	stage.stats_card.show_report({"dungeonCompletionsByDungeonId": {"5": 3.0}})
	var texts := _texts(stage.stats_card.columns)
	assert_has(texts, "Dungeon 5")
	assert_does_not_have(texts, LifetimeStats.NONE_YET)


func test_nothing_is_fetched_without_a_session():
	var got: Dictionary = await CharacterMetrics.fetch(service, "c1")
	assert_false(got["success"])
	assert_eq(backend.requests.size(), 0)


func test_a_body_that_is_not_a_report_reads_as_empty():
	service.token = "t"
	backend.push_raw(HTTPRequest.RESULT_SUCCESS, 200, "[]")
	var got: Dictionary = await CharacterMetrics.fetch(service, "c1")
	assert_true(got["success"])
	assert_eq(got["metrics"], {})


func test_entering_the_realm_or_signing_out_puts_it_away():
	var stage := await _sign_in()
	stage.stats_card.visible = true
	stage.play()
	assert_false(stage.stats_card.visible, "entering the realm")
	stage.stats_card.visible = true
	stage.forget()
	assert_false(stage.stats_card.visible, "signing out")


func test_a_second_report_replaces_the_first():
	var stage := await _sign_in()
	var card := stage.stats_card
	card.show_report({"killsTotal": 111.0})
	card.show_report({"killsTotal": 222.0})
	await wait_process_frames(1)
	var texts := _texts(card.columns)
	assert_does_not_have(texts, "111")
	assert_eq(texts.count("COMBAT"), 1, "one card's worth of rows")
