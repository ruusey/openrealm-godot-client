class_name LeaderboardRow
extends PanelContainer

## One line of the leaderboard: the web client's `.leaderboard-row` -- the
## rank, the class's idle frame in its dye, "account - Class Lv. N", and the
## fame -- with the character's gear and stats on a card under the cursor.
##
## The fame is the service's base fame, which is zero until level 20; a
## character with any shows as level 20 and its fame, one without as its
## level and "Fame: 0" -- raw XP is too noisy to show, the web's comment says.

const ICON_PX := 24
const RANK := Color("c8a86e")
const INFO := Color("e0d8c8")
const FAME := Color("aa8844")
const HOVER := Color("2a2530")
const FAME_LEVEL := 20

var entry: Dictionary
var content: GameData


func _init(from: Dictionary = {}, game_data: GameData = null, rank := 1) -> void:
	entry = from
	content = game_data
	mouse_filter = Control.MOUSE_FILTER_PASS
	_hover(false)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var place := HudWidgets.label(rank_text(rank), 13, RANK)
	place.custom_minimum_size.x = 32
	line.add_child(place)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = class_frame(entry, content)
	line.add_child(icon)
	var info := HudWidgets.label(info_text(entry), 13, INFO)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.clip_text = true
	line.add_child(info)
	line.add_child(HudWidgets.label(fame_text(entry), 12, FAME))
	# The web opens its card only for a character wearing something.
	if not (entry.get("equipment", []) as Array).is_empty():
		tooltip_text = info_text(entry)
	mouse_entered.connect(func() -> void: _hover(true))
	mouse_exited.connect(func() -> void: _hover(false))


func _make_custom_tooltip(_for_text: String) -> Object:
	return LeaderboardCard.build(entry, content)


static func rank_text(rank: int) -> String:
	return "#%d" % rank


static func info_text(from: Dictionary) -> String:
	return "%s - %s Lv. %d" % [str(from.get("accountName", "Unknown")),
		str(from.get("className", "Unknown")), shown_level(from)]


static func fame_text(from: Dictionary) -> String:
	return "Fame: %s" % Mastery.thousands(fame(from))


## Base fame, 0 while it is absent or null.
static func fame(from: Dictionary) -> int:
	var value = from.get("fame")
	return int(value) if value != null else 0


static func shown_level(from: Dictionary) -> int:
	if fame(from) > 0:
		return FAME_LEVEL
	var value = from.get("level")
	return int(value) if value != null else 1


## The dye rides on the stats; the web also reads a top-level dyeId first.
static func dye_of(from: Dictionary) -> int:
	var stats = from.get("stats")
	var dye = from.get("dyeId", stats.get("dyeId") if stats is Dictionary else null)
	return int(dye) if dye != null else 0


static func class_frame(from: Dictionary, game_data: GameData) -> Texture2D:
	if game_data == null:
		return null
	var class_id = from.get("characterClass")
	return game_data.classes_art.frame(int(class_id) if class_id != null else 0,
		"idle", "front", 0, dye_of(from))


## `.leaderboard-row:hover`: the row lights under the cursor.
func _hover(on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HOVER if on else Color(0, 0, 0, 0)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	add_theme_stylebox_override("panel", box)
