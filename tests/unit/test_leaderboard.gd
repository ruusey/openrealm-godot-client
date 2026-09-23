extends GutTest

## The leaderboard: the service's /data/stats/top, its rows, its card, and
## the panel beside the sign-in screen.

## Holds its reply until released, as a real request does.
class HeldBackend extends FakeHttpBackend:
	signal release

	func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
		await release
		return super(method, url, headers, body)


var service: DataService
var backend: FakeHttpBackend
var data: GameData
var panel: LeaderboardPanel


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	service.token = "tok"
	service.account_guid = "g"
	add_child_autofree(service)
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	panel = LeaderboardPanel.new()
	panel.game_data = data
	add_child_autofree(panel)


func _entry(name: String, level: int, fame: int, extra := {}) -> Dictionary:
	var entry := {"accountName": name, "characterUuid": "c-" + name, "characterClass": 2,
		"className": "Wizard", "level": level, "fame": fame, "equipment": [],
		"stats": {"hp": 100, "mp": 100, "str": 10, "def": 0, "spd": 10, "dex": 10, "vit": 10, "wis": 10}}
	entry.merge(extra, true)
	return entry


# --- DataService -----------------------------------------------------------

func test_fetch_asks_for_the_count_with_the_session_token():
	backend.push_json(200, [_entry("a", 5, 0)])
	var got: Dictionary = await LeaderboardRequest.top(service, 25)
	assert_true(got["success"])
	assert_eq(got["entries"].size(), 1)
	assert_eq(backend.requests[0]["url"], "http://data.test/data/stats/top?count=25")
	assert_eq(backend.requests[0]["method"], HTTPClient.METHOD_GET)
	assert_true("Authorization: tok" in backend.requests[0]["headers"], "the endpoint refuses a request without it")


func test_fetch_failure_carries_the_reason():
	backend.push_json(401, {"message": "Unauthorized"})
	var got: Dictionary = await LeaderboardRequest.top(service, 25)
	assert_false(got["success"])
	assert_string_contains(got["result"], "401")


func test_fetch_rejects_a_body_that_is_not_a_list():
	backend.push_json(200, {"entries": []})
	var got: Dictionary = await LeaderboardRequest.top(service, 25)
	assert_false(got["success"])
	assert_string_contains(got["result"], "unexpected")


# --- the row ---------------------------------------------------------------

func test_a_character_before_level_twenty_shows_its_level_and_no_fame():
	var entry := _entry("Ruu", 7, 0)
	assert_eq(LeaderboardRow.info_text(entry), "Ruu - Wizard Lv. 7")
	assert_eq(LeaderboardRow.fame_text(entry), "Fame: 0")


func test_a_character_with_fame_shows_level_twenty_and_the_fame_grouped():
	var entry := _entry("Ruu", 1, 12345)
	assert_eq(LeaderboardRow.info_text(entry), "Ruu - Wizard Lv. 20", "the web's fame mode")
	assert_eq(LeaderboardRow.fame_text(entry), "Fame: 12,345")


func test_absent_or_null_fields_do_not_break_the_row():
	assert_eq(LeaderboardRow.info_text({"fame": null, "level": null}), "Unknown - Unknown Lv. 1")
	assert_eq(LeaderboardRow.fame_text({}), "Fame: 0")
	assert_eq(LeaderboardRow.rank_text(3), "#3")


func test_the_dye_is_read_off_the_stats_or_the_entry():
	assert_eq(LeaderboardRow.dye_of({"stats": {"dyeId": 4}}), 4)
	assert_eq(LeaderboardRow.dye_of({"dyeId": 6, "stats": {"dyeId": 4}}), 6)
	assert_eq(LeaderboardRow.dye_of({"stats": null}), 0)


func test_the_row_draws_the_class_frame():
	var barbarian := _entry("a", 1, 0, {"characterClass": 0, "className": "Barbarian"})
	assert_not_null(LeaderboardRow.class_frame(barbarian, data), "the fixture barbarian has an idle frame")
	assert_null(LeaderboardRow.class_frame(barbarian, null))


func test_only_a_character_wearing_something_opens_a_card():
	var bare := LeaderboardRow.new(_entry("a", 1, 0), data)
	var geared := LeaderboardRow.new(_entry("b", 1, 0, {"equipment": [{"itemId": 100, "slotIdx": 0}]}), data)
	assert_eq(bare.tooltip_text, "")
	assert_ne(geared.tooltip_text, "")
	var card = geared._make_custom_tooltip("")
	assert_true(card is PanelContainer)
	bare.free()
	geared.free()
	card.free()


# --- the card --------------------------------------------------------------

func test_the_card_names_each_slot_from_the_catalog():
	var entry := _entry("Ruu", 3, 0, {"equipment": [
		{"itemId": 104, "slotIdx": 4}, {"itemId": 100, "slotIdx": 0}, {"itemId": 101, "slotIdx": 1},
		{"itemId": 999, "slotIdx": 2}]})
	var said := LeaderboardCard.describe(entry, data)
	assert_eq(said["title"], "Ruu's Wizard")
	assert_eq(said["sub"], "Lv 3 - Fame 0")
	assert_eq(said["gear"][0], ["Weapon", "Short Bow", "T1"])
	assert_eq(said["gear"][1], ["Armor", "Scattergun", ""], "no tier, no tag")
	assert_eq(said["gear"][2], ["Gauntlets", "Item 999", ""], "unknown to the catalog")
	assert_eq(said["gear"][3], ["Boots", "", ""], "empty")
	assert_eq(said["gear"][4], ["Ring", "Plain Ring", "T0"], "tier 0 is still a tier")


func test_the_card_builds_its_gear_and_stats():
	var entry := _entry("Ruu", 3, 250, {"equipment": [{"itemId": 100, "slotIdx": 0}]})
	var card := LeaderboardCard.build(entry, data)
	var column: VBoxContainer = card.get_child(0)
	assert_eq(column.get_child_count(), 2 + 5 + 2, "title, sub, five slots, rule, stats")
	var weapon: HBoxContainer = column.get_child(2)
	assert_not_null((weapon.get_child(0) as TextureRect).texture, "the worn item's sprite")
	var boots: HBoxContainer = column.get_child(5)
	assert_null((boots.get_child(0) as TextureRect).texture, "an empty slot has none")
	assert_eq((boots.get_child(2) as Label).text, "Empty")
	var grid: GridContainer = column.get_child(8)
	assert_eq(grid.get_child_count(), 16)
	assert_eq((grid.get_child(0) as Label).text, "HP")
	assert_eq((grid.get_child(1) as Label).text, "100")
	card.free()


# --- the panel -------------------------------------------------------------

func test_hidden_until_loaded():
	assert_false(panel.visible)


func test_refresh_lists_the_entries_in_the_order_the_service_ranks_them():
	backend.push_json(200, [_entry("first", 1, 900), _entry("second", 15, 0), _entry("third", 2, 0)])
	await panel.refresh(service)
	assert_true(panel.visible)
	assert_false(panel.message.visible)
	assert_eq(panel.rows.get_child_count(), 3)
	var second: LeaderboardRow = panel.rows.get_child(1)
	assert_eq(second.entry["accountName"], "second")
	var line: HBoxContainer = second.get_child(0)
	assert_eq((line.get_child(0) as Label).text, "#2")
	assert_eq((line.get_child(2) as Label).text, "second - Wizard Lv. 15")


func test_an_empty_board_says_so():
	backend.push_json(200, [])
	await panel.refresh(service)
	assert_eq(panel.rows.get_child_count(), 0)
	assert_eq(panel.message.text, "No characters yet.")


func test_a_failure_shows_the_reason_in_red():
	backend.push_json(500, {"message": "down"})
	await panel.refresh(service)
	assert_string_contains(panel.message.text, "down")
	assert_eq(panel.message.get_theme_color("font_color"), LeaderboardPanel.ERROR)


func test_a_reply_after_forget_is_dropped():
	var held := HeldBackend.new()
	service.backend = held
	held.push_json(200, [_entry("late", 1, 0)])
	panel.refresh(service)
	assert_eq(panel.message.text, "Loading...")
	panel.forget()
	held.release.emit()
	assert_eq(held.requests.size(), 1, "the reply did arrive")
	assert_false(panel.visible)
	assert_eq(panel.rows.get_child_count(), 0)


func test_an_older_reply_does_not_overwrite_a_newer_one():
	var held := HeldBackend.new()
	service.backend = held
	held.push_json(200, [_entry("old", 1, 0)])
	held.push_json(200, [_entry("new", 1, 0), _entry("newer", 1, 0)])
	panel.refresh(service)
	panel.refresh(service)
	held.release.emit()
	assert_eq(panel.rows.get_child_count(), 2)


func test_a_second_load_replaces_the_first():
	panel.show_entries([_entry("old", 1, 0), _entry("older", 1, 0)])
	await get_tree().process_frame
	panel.show_entries([_entry("new", 1, 0)])
	assert_eq(panel.rows.get_child_count(), 1)


func test_nothing_is_asked_without_a_session_or_a_service():
	var before := backend.requests.size()
	var bare := DataService.new()
	autofree(bare)
	assert_eq(await LeaderboardRequest.top(bare, 25), {"success": false, "result": "not signed in"})
	assert_eq(await LeaderboardRequest.top(null, 25), {"success": false, "result": "not signed in"})
	assert_eq(backend.requests.size(), before, "nothing sent")
	var panel := LeaderboardPanel.new()
	add_child_autofree(panel)
	await panel.refresh(null)
	assert_false(panel.visible, "no service, no panel")
