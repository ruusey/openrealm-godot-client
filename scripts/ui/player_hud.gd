class_name PlayerHud
extends CanvasLayer

## Who you are and how you are doing: the web client's HUD column under
## the minimap, in Godot's own controls.
##
## The identity line -- name, level, class -- then HP, MP and XP bars with
## their numbers on them, then the six stats in a grid of three by two,
## each with the equipment's part beside it in green or red. The numbers
## are the wire's computed stats; the bonus is EquipmentBonus taken back
## off them, and a stat whose BASE is at the class cap reads gold, which is
## the server's own isStatMaxed. The XP bar counts within the level and,
## past the last level, turns gold and counts fame.

const MARGIN := 8
const WIDTH := MinimapPanel.SIDE
const HEIGHT := 158
## Where the column ends, for whatever is pinned beneath it.
const BOTTOM := MinimapPanel.MARGIN + MinimapPanel.SIDE + MARGIN + HEIGHT
const STATS := ["str", "def", "spd", "dex", "vit", "wis"]
const GOLD := Color("c8a86e")
const HP_FILL := Color("c03030")
const MP_FILL := Color("3060c0")
const XP_FILL := Color("40a040")
const BONUS_UP := Color("40c040")
const BONUS_DOWN := Color("e85050")

var state: RealmState
var content: GameData
## Off for a scripted render that is about something else.
var shown := true
## Where the top edge sits: under the map, or under its chip when folded.
var below: Callable = func() -> float: return float(MinimapPanel.MARGIN + MinimapPanel.SIDE)
var fold: PanelFold

var _root: PanelContainer
var _identity: Label
var _bars := {}   # "hp" / "mp" / "xp" -> [ProgressBar, Label]
var _cells := {}  # stat -> [value Label, bonus Label]
var _grid: GridContainer
var _drawn := ""


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_left = -WIDTH - MinimapPanel.MARGIN
	_root.offset_right = -MinimapPanel.MARGIN
	_root.offset_top = MinimapPanel.MARGIN + MinimapPanel.SIDE + MARGIN
	_root.offset_bottom = BOTTOM
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_identity = HudWidgets.label("", 13, GOLD)
	column.add_child(_identity)
	_bars["hp"] = HudWidgets.bar(column, HP_FILL)
	_bars["mp"] = HudWidgets.bar(column, MP_FILL)
	_bars["xp"] = HudWidgets.bar(column, XP_FILL)
	_grid = GridContainer.new()
	_grid.columns = 3
	column.add_child(_grid)
	for stat in STATS:
		_cells[stat] = HudWidgets.stat_cell(_grid, stat.to_upper())
	fold = PanelFold.new(self, "Stats", "stats", state.settings if state != null else null,
		func(folded: bool) -> void: _grid.visible = not folded)


func _process(_delta: float) -> void:
	visible = shown and state != null and content != null and state.local.is_present()
	if not visible:
		return
	_root.offset_top = below.call() + MARGIN
	_root.offset_bottom = _root.offset_top + (_root.get_combined_minimum_size().y if fold.folded else float(HEIGHT))
	fold.place_right(_root.offset_top + 2.0, get_viewport().get_visible_rect().size.x - MinimapPanel.MARGIN - 2.0)
	var key := "%s|%d|%d|%d|%d|%d" % [state.local.stats, state.local.health, state.local.mana,
		state.local.inventory.experience, state.local.inventory.version, state.local.class_id]
	if key != _drawn:
		_drawn = key
		refresh()


func captures_mouse() -> bool:
	return visible and fold.under_mouse()


func refresh() -> void:
	var local := state.local
	var computed: Dictionary = local.stats
	var bonus := EquipmentBonus.of(local.inventory)
	var base := EquipmentBonus.base(computed, bonus)
	var caps: Dictionary = content.library.classes.get(local.class_id, {}).get("maxStats", {})
	var level := content.levels.level_for(local.inventory.experience)
	_identity.text = "%s  Lv. %d  %s" % [local.name, level, content.classes_art.display_name(local.class_id)]
	_fill("hp", local.health, int(computed.get("hp", 0)), maxed(base, caps, "hp"))
	_fill("mp", local.mana, int(computed.get("mp", 0)), maxed(base, caps, "mp"))
	var xp := xp_line(content.levels, local.inventory.experience)
	_bars["xp"][0].value = xp[1]
	_bars["xp"][1].text = xp[0]
	HudWidgets.refill(_bars["xp"][0], GOLD if xp[2] else XP_FILL)
	for stat in STATS:
		_cells[stat][0].text = str(int(computed.get(stat, 0)))
		_cells[stat][0].add_theme_color_override("font_color", GOLD if maxed(base, caps, stat) else Color.WHITE)
		_cells[stat][1].text = bonus_text(int(bonus[stat]))
		_cells[stat][1].add_theme_color_override("font_color", BONUS_UP if bonus[stat] > 0 else BONUS_DOWN)


func _fill(which: String, current: int, maximum: int, gold: bool) -> void:
	_bars[which][0].value = clampf(float(current) / maximum, 0.0, 1.0) if maximum > 0 else 1.0
	_bars[which][1].text = "%d/%d" % [current, maximum]
	_bars[which][1].add_theme_color_override("font_color", GOLD if gold else Color.WHITE)


## The XP bar's [text, fill 0..1, is_fame]: the web client's
## getExpDisplayInfo, which is the native's FillBars.
static func xp_line(levels: ExperienceLevels, experience: int) -> Array:
	var fame := levels.fame_for(experience)
	if fame > 0:
		return ["Lv %d  Fame: %d" % [levels.level_for(experience), fame], 1.0, true]
	var level := levels.level_for(experience)
	var progress := levels.progress_for(experience)
	if progress[1] <= 0:
		return ["Lv %d" % level, 0.0, false]
	return ["Lv %d  %d / %d" % [level, progress[0], progress[1]], minf(1.0, float(progress[0]) / progress[1]), false]


## Judged on the base, never on the equipment-boosted value.
static func maxed(base: Dictionary, caps: Dictionary, stat: String) -> bool:
	return caps.has(stat) and int(base.get(stat, 0)) >= int(caps[stat])


static func bonus_text(bonus: int) -> String:
	if bonus == 0:
		return ""
	return "+%d" % bonus if bonus > 0 else str(bonus)
