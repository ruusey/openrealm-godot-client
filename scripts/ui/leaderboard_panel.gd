class_name LeaderboardPanel
extends PanelContainer

## The top characters on the server, in a realm's LeaderboardWindow.
##
## The web client puts its leaderboard on the character-select screen, under
## the account's characters, and loads it every time that screen is shown:
## `GET /data/stats/top?count=25`, the service's ranking -- every account's
## living characters by XP, best first -- drawn in the order it arrives,
## "Loading..." while it is on its way, "No characters yet." for an empty
## one and the reason in red when it fails. Here it is on the in-game Menu
## instead, so the character select has the whole screen for a thumb, and
## it loads every time it opens. The endpoint wants the session's token.

const COUNT := 25
const HEADING := Color("c8a86e")
const MUTED := Color("887868")
const ERROR := Color("cc4444")
const WIDTH := 420
const LIST_HEIGHT := 360

var game_data: GameData

var head: HBoxContainer
var rows: VBoxContainer
var message: Label

## Bumped by every load and every forget, so a reply that lands after a
## newer request -- or after sign-out -- is dropped rather than drawn.
var _generation := 0


func _ready() -> void:
	visible = false
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := InventoryLayout.column(self)
	head = HBoxContainer.new()
	column.add_child(head)
	var heading := HudWidgets.label("Leaderboard", 18, HEADING)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	message = HudWidgets.label("", 13, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = WIDTH - 24
	column.add_child(message)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = LIST_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 1)
	scroll.add_child(rows)


## Shows the panel and fills it from the service; returns once it is filled.
## With no service at all -- a scripted render -- it stays shut.
func refresh(service: DataService) -> void:
	if service == null:
		return
	_generation += 1
	var mine := _generation
	visible = true
	_clear()
	say("Loading...", MUTED)
	var got: Dictionary = await LeaderboardRequest.top(service, COUNT)
	if mine != _generation:
		return
	if got["success"]:
		show_entries(got["entries"])
	else:
		say(str(got["result"]), ERROR)


func show_entries(entries: Array) -> void:
	visible = true
	_clear()
	say("No characters yet." if entries.is_empty() else "", MUTED)
	for index in entries.size():
		if entries[index] is Dictionary:
			rows.add_child(LeaderboardRow.new(entries[index], game_data, index + 1))


## Signed out: nothing shown, and any load still in flight is ignored.
func forget() -> void:
	_generation += 1
	visible = false
	_clear()


func say(text: String, colour: Color) -> void:
	message.text = text
	message.visible = text != ""
	message.add_theme_color_override("font_color", colour)


func _clear() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
