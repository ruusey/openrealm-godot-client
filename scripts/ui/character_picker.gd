class_name CharacterPicker
extends VBoxContainer

## The account's characters on two pages: the living, and the graveyard.
##
## The data service returns every character the account ever had, the dead
## ones with a `deleted` timestamp. Both references split them the same way
## -- the web client's Characters / Graveyard tabs, the native's greyed
## rows with "Died:" -- and neither lets a dead one be played, since the
## login rejects it.

signal activated()
## A right-click on a character, either page: the web client's stats card.
signal stats_requested(character: Dictionary)

const PAGES := ["Characters", "Graveyard"]
const ALIVE := 0
const GRAVEYARD := 1

var game_data: GameData
var tabs: TabBar
var list: ItemList

var _pages: Array = [[], []]


func _ready() -> void:
	tabs = TabBar.new()
	for page in PAGES:
		tabs.add_tab(page)
	tabs.tab_changed.connect(func(_index: int) -> void: _fill())
	add_child(tabs)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 140)
	list.item_activated.connect(func(_index: int) -> void: activated.emit())
	list.allow_rmb_select = true
	list.item_clicked.connect(_on_clicked)
	add_child(list)


static func is_dead(character: Dictionary) -> bool:
	return character.get("deleted") != null


func show_characters(characters: Array) -> void:
	_pages = [[], []]
	for character in characters:
		_pages[GRAVEYARD if is_dead(character) else ALIVE].append(character)
	for page in PAGES.size():
		tabs.set_tab_title(page, "%s (%d)" % [PAGES[page], _pages[page].size()])
	# Opens on the living, unless there are none left to open on.
	var wanted := ALIVE if not _pages[ALIVE].is_empty() or _pages[GRAVEYARD].is_empty() else GRAVEYARD
	if tabs.current_tab == wanted:
		_fill()
	else:
		tabs.current_tab = wanted


func clear() -> void:
	_pages = [[], []]
	list.clear()


## The character under the cursor, or nothing; a dead one is never chosen.
func selected() -> Dictionary:
	var picked := list.get_selected_items()
	if picked.is_empty() or tabs.current_tab != ALIVE:
		return {}
	return _pages[ALIVE][picked[0]]


## Puts the cursor on the last living character: the data service appends
## a new one to the account, so after a create that is the one just made.
func select_newest() -> void:
	tabs.current_tab = ALIVE
	if list.item_count > 0:
		list.select(list.item_count - 1)


func _on_clicked(index: int, _at: Vector2, button: int) -> void:
	var page: Array = _pages[tabs.current_tab]
	if button == MOUSE_BUTTON_RIGHT and index < page.size():
		stats_requested.emit(page[index])


func alive_count() -> int:
	return _pages[ALIVE].size()


func dead_count() -> int:
	return _pages[GRAVEYARD].size()


func _fill() -> void:
	list.clear()
	for character in _pages[tabs.current_tab]:
		list.add_item(describe(character, game_data))
	if list.item_count > 0:
		list.select(0)


## One line per character: class, the two stats that matter at the door,
## and for the fallen the day they fell -- the native client's "Died:".
static func describe(character: Dictionary, content: GameData) -> String:
	var stats: Dictionary = character.get("stats", {})
	var line := "%s   hp %s  spd %s" % [class_label(character, content),
		stat_text(stats.get("hp")), stat_text(stats.get("spd"))]
	if is_dead(character):
		line += "   died %s" % String(character.get("deleted", "")).substr(0, 10)
	return line


## A stat as a whole number. The service's JSON reaches us as floats --
## JSON.parse_string makes every number one -- so a bare str() read
## "hp 130.0"; a stat the service left out is "?".
static func stat_text(value: Variant) -> String:
	return str(roundi(value)) if value is float or value is int else "?"


static func class_label(character: Dictionary, content: GameData) -> String:
	var class_id := int(character.get("characterClass", 0))
	return content.classes_art.display_name(class_id) if content else "class %d" % class_id
