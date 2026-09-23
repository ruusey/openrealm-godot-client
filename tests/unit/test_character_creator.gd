extends GutTest

## CharacterCreator: the class grid, the two buttons and the one request.

var creator: CharacterCreator
var service: DataService
var backend: FakeHttpBackend
var data: GameData


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	service.token = "t"
	service.account_guid = "g"
	add_child_autofree(service)

	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))

	creator = CharacterCreator.new()
	creator.data_service = service
	creator.game_data = data
	add_child_autofree(creator)
	watch_signals(creator)


func test_lists_every_shipped_class_in_id_order_with_its_art():
	assert_eq(creator.options.keys(), [0, 2])
	assert_eq(creator.grid.get_child(0).text, "Barbarian")
	assert_eq(creator.grid.get_child(1).text, "Wizard")
	assert_not_null(creator.options[0].icon, "the idle_front frame stands beside the name")
	assert_eq(creator.options[0].icon.get_size(), Vector2(32, 32), "blown up ahead of time, not by the button")
	assert_null(creator.options[2].icon, "the fixture wizard has no frames")
	assert_eq(creator.grid.columns, 4, "the native client's four columns")


func test_a_missing_frame_has_no_icon():
	assert_null(CharacterCreator.icon_for(null))


func test_nothing_can_be_made_until_a_class_is_picked():
	assert_true(creator.play_button.disabled)
	assert_true(creator.create_button.disabled)
	assert_eq(creator.selected_class_id(), -1)
	creator.options[2].button_pressed = true
	assert_eq(creator.selected_class_id(), 2)
	assert_false(creator.play_button.disabled)
	assert_false(creator.create_button.disabled)


func test_picking_a_second_class_replaces_the_first():
	creator.options[0].button_pressed = true
	creator.options[2].button_pressed = true
	assert_false(creator.options[0].button_pressed)
	assert_eq(creator.selected_class_id(), 2)


func test_create_and_play_posts_the_pick_and_says_so():
	creator.options[2].button_pressed = true
	backend.push_json(200, {"characters": [{"characterUuid": "n", "characterClass": 2}]})
	creator.play_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(backend.requests[0]["url"], "http://data.test/data/account/g/character?classId=2")
	# 2.0: the list is parsed JSON, and JSON numbers are floats.
	assert_signal_emitted_with_parameters(creator, "created",
		[[{"characterUuid": "n", "characterClass": 2.0}], true])
	assert_eq(creator.selected_class_id(), -1, "the pick is spent")
	assert_true(creator.play_button.disabled)
	assert_eq(creator.play_button.text, "Create & play")


func test_plain_create_is_reported_as_not_playing():
	creator.options[0].button_pressed = true
	backend.push_json(200, {"characters": []})
	creator.create_button.pressed.emit()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(creator, "created", [[], false])


func test_a_failure_keeps_the_pick_and_reports_the_reason():
	creator.options[0].button_pressed = true
	backend.push_json(400, {"reason": "Character limit reached (15 max)"})
	await creator._create(true)
	assert_signal_emitted_with_parameters(creator, "failed", ["HTTP 400: Character limit reached (15 max)"])
	assert_signal_not_emitted(creator, "created")
	assert_eq(creator.selected_class_id(), 0)
	assert_false(creator.play_button.disabled, "ready for a retry")


func test_a_press_with_nothing_picked_sends_nothing():
	await creator._create(true)
	assert_eq(backend.requests.size(), 0)
	assert_signal_not_emitted(creator, "created")


func test_a_press_while_busy_is_ignored():
	creator.options[0].button_pressed = true
	creator._busy = true
	creator._refresh()
	assert_eq(creator.play_button.text, "Creating ...")
	await creator._create(true)
	assert_eq(backend.requests.size(), 0)


func test_refill_rebuilds_from_the_content_and_forgets_the_pick():
	creator.options[0].button_pressed = true
	creator.fill()
	assert_eq(creator.options.size(), 2)
	assert_eq(creator.selected_class_id(), -1)
	assert_eq(creator.grid.get_child_count(), 2, "the old buttons are gone, not stacked")


func test_without_content_the_grid_is_empty():
	creator.game_data = null
	creator.fill()
	assert_eq(creator.options.size(), 0)
	assert_true(creator.play_button.disabled)
