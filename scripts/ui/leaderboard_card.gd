class_name LeaderboardCard
extends RefCounted

## The card over a leaderboard row: the web client's `#lb-tooltip` --
## "account's Class", the level and fame, the five equipment slots with each
## item's sprite, name and tier, and the eight stats two to a line.
##
## The entry carries only itemIds for the gear (slots 0-4, the service
## drops the rest), so the names, tiers and sprites come from the content.

const SLOTS := ["Weapon", "Armor", "Gauntlets", "Boots", "Ring"]
const STATS := [["HP", "hp"], ["MP", "mp"], ["STR", "str"], ["DEF", "def"],
	["SPD", "spd"], ["DEX", "dex"], ["VIT", "vit"], ["WIS", "wis"]]
const TITLE := Color("c8a86e")
const SUB := Color("aa8844")
const ITEM := Color("b8b0a0")
const EMPTY := Color("665848")
const CAPTION := Color("887868")
const HP := Color("e06060")
const MP := Color("6090e0")
const SPRITE_PX := 24
const BACKGROUND := Color("1a1620")
const EDGE := Color("554840")


## What the card says, without the controls: the title, the level line, and
## one [slot, item name, tier] per slot -- the name "" for an empty one.
static func describe(entry: Dictionary, content: GameData) -> Dictionary:
	var fame := LeaderboardRow.fame(entry)
	var gear: Array = []
	for slot in SLOTS.size():
		var item := worn(entry, slot)
		var item_id := int(item.get("itemId", -1)) if not item.is_empty() else -1
		var definition := content.item_definition(item_id) if content != null and item_id >= 0 else {}
		var tier := int(definition.get("tier", -1)) if definition.get("tier") != null else -1
		gear.append([SLOTS[slot], "" if item_id < 0 else str(definition.get("name", "Item %d" % item_id)),
			"T%d" % tier if tier >= 0 else ""])
	return {"title": "%s's %s" % [str(entry.get("accountName", "Unknown")), str(entry.get("className", "Unknown"))],
		"sub": "Lv %d - Fame %s" % [LeaderboardRow.shown_level(entry), Mastery.thousands(fame)],
		"gear": gear}


## The item in an equipment slot, or {}.
static func worn(entry: Dictionary, slot: int) -> Dictionary:
	var equipment = entry.get("equipment")
	for item in (equipment if equipment is Array else []):
		if item is Dictionary and item.get("slotIdx") != null and int(item["slotIdx"]) == slot:
			return item
	return {}


static func build(entry: Dictionary, content: GameData) -> PanelContainer:
	var said := describe(entry, content)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size.x = 240
	column.add_child(HudWidgets.label(said["title"], 13, TITLE))
	column.add_child(HudWidgets.label(said["sub"], 11, SUB))
	for slot in SLOTS.size():
		column.add_child(_gear_line(said["gear"][slot], worn(entry, slot), content))
	var stats = entry.get("stats")
	if stats is Dictionary:
		column.add_child(HSeparator.new())
		column.add_child(_stat_grid(stats))
	return card


static func _gear_line(said: Array, item: Dictionary, content: GameData) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(SPRITE_PX, SPRITE_PX)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if content != null and said[1] != "":
		sprite.texture = content.item_texture(int(item.get("itemId", -1)))
	line.add_child(sprite)
	var caption := HudWidgets.label("%s:" % said[0], 11, CAPTION)
	caption.custom_minimum_size.x = 64
	line.add_child(caption)
	line.add_child(HudWidgets.label(said[1] if said[1] != "" else "Empty", 12, ITEM if said[1] != "" else EMPTY))
	if said[2] != "":
		line.add_child(HudWidgets.label(said[2], 10, TITLE))
	return line


static func _stat_grid(stats: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	for stat in STATS:
		grid.add_child(HudWidgets.label(stat[0], 11, CAPTION))
		var value = stats.get(stat[1])
		var colour := HP if stat[1] == "hp" else MP if stat[1] == "mp" else ITEM
		var shown := HudWidgets.label(str(int(value)) if value != null else "0", 11, colour)
		shown.custom_minimum_size.x = 40
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(shown)
	return grid
