class_name RealmBanner
extends CanvasLayer

## The realm's name and difficulty along the top of the screen, and, while
## a corrupted realm is being cleansed, how far that has come.
##
## The web client's realm-info line and its purification bar in one place:
## the name from the map (or what the server called the realm, which is
## all a dungeon has), the difficulty in the colour both references use,
## green through yellow and orange to red; and under it, only while the
## realm has a purification goal, the tier and the percentage and the
## modifiers -- what RealmPurificationPacket carries.

const MARGIN_TOP := 8.0
const NAME_SIZE := 16
const DETAIL_SIZE := 13

var state: RealmState
var content: GameData
## Off for a scripted render that is about something else.
var shown := true

var _column: VBoxContainer
var _name: Label
var _detail: Label


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	layer = 11
	visible = false
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_column.offset_top = MARGIN_TOP
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_name = _line(NAME_SIZE)
	_detail = _line(DETAIL_SIZE)
	_detail.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))


func _line(size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(label)
	return label


func _process(_delta: float) -> void:
	var name := realm_name()
	visible = shown and state != null and state.local.is_present() and not state.transition_pending and name != ""
	if not visible:
		return
	var realm: Dictionary = state.minimap.realm
	var difficulty := float(realm.get("difficulty", 0.0))
	_name.text = name if difficulty <= 0.0 else "%s   %s" % [name, PortalCard.number(difficulty)]
	_name.add_theme_color_override("font_color", difficulty_colour(difficulty) if difficulty > 0.0 else Color.WHITE)
	_detail.text = purification(realm)
	_detail.visible = _detail.text != ""


## The server's own name for the realm if it sent one, the map's otherwise.
func realm_name() -> String:
	if state == null:
		return ""
	if state.transition.zone != "":
		return state.transition.zone
	return "" if content == null else content.maps.name(state.tiles.map_id).replace("_", " ")


## The web client's line, only while there is a goal.
static func purification(realm: Dictionary) -> String:
	var goal := int(realm.get("goal", 0))
	if goal <= 0:
		return ""
	var percent := clampi(roundi(int(realm.get("progress", 0)) * 100.0 / goal), 0, 100)
	var tier := int(realm.get("tier", 0))
	var line := ("Tier %d - Purification %d%%" % [tier, percent]) if tier > 1 else "Realm Purification - %d%%" % percent
	var modifiers := String(realm.get("modifiers", ""))
	return line + ("  -  " + modifiers if modifiers != "" else "")


## Green through yellow and orange to red as difficulty rises: the web
## client's realm-info colour, which it says matches the native's.
static func difficulty_colour(difficulty: float) -> Color:
	if difficulty <= 2.0:
		return Color8(60, 180, 60)
	if difficulty <= 4.0:
		return Color8(180, 160, 40)
	if difficulty <= 6.0:
		return Color8(220, 80, 40)
	return Color8(255, 40, 40)
