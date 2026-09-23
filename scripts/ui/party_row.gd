class_name PartyRow
extends PanelContainer

## One teammate in the party panel: the web client's party-player row in
## Godot's own controls.
##
## The class's idle frame, the name (starred for the leader), HP and MP
## bars a few pixels tall, and under them the cooldown strip -- the class
## passive's cell, then the four hotbar slots with their icons, each
## darkened from the top by what is left of its cooldown. A red cross on
## the right kicks, and is only there for the leader. The row dims when
## the teammate is in another realm, and hovering it shows the inspect
## card as a tooltip: level and class, HP, MP and the six stats.

const ICON := 32
const CELL := 22
const NAME_COLOUR := Color("fff0a0")
const KICK_COLOUR := Color("e05050")
const HP_FILL := Color("c81030")
const MP_FILL := Color("5070ff")
const SHADE := Color(0.0, 0.0, 0.0, 0.65)
const OTHER_REALM_ALPHA := 0.55

var player_id := 0
var member_name := ""

var _icon: TextureRect
var _name: Label
var _hp: ProgressBar
var _mp: ProgressBar
var _cells: Array = []    # 4 x [TextureRect, ColorRect shade]
var _kick: Button


func _init(on_kick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_icon = _picture(row, ICON)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name = HudWidgets.label("", 12, NAME_COLOUR)
	column.add_child(_name)
	_hp = HudWidgets.bar(column, HP_FILL, 5)[0]
	_mp = HudWidgets.bar(column, MP_FILL, 4)[0]
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	column.add_child(strip)
	for i in 4:
		var cell := _picture(strip, CELL)
		var shade := ColorRect.new()
		shade.color = SHADE
		shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(shade)
		_cells.append([cell, shade])
	_kick = Button.new()
	_kick.text = "x"
	_kick.tooltip_text = "Kick from party"
	_kick.add_theme_color_override("font_color", KICK_COLOUR)
	_kick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_kick.pressed.connect(func() -> void: on_kick.call(member_name))
	row.add_child(_kick)


## The parts that only change with the roster: who, what class, what is
## on the hotbar, and whether the kick is offered.
func show_member(member: Dictionary, content: GameData, leader: bool, can_kick: bool) -> void:
	player_id = int(member.get("playerId", 0))
	member_name = String(member.get("name", ""))
	var class_id := int(member.get("classId", 0))
	_icon.texture = content.classes_art.frame(class_id, "idle", "front", 0)
	_name.text = ("* " if leader else "") + member_name.left(14)
	var bindings: Array = member.get("hotbarBindings", [])
	for i in 4:
		var id := int(bindings[i]) if i < bindings.size() else 0
		_cells[i][0].texture = content.abilities.icon(id) if id > 0 else null
	_kick.visible = can_kick
	tooltip_text = inspect_text(member, content)


## The parts that move between rosters: bars, cooldowns, which realm.
func patch(member: Dictionary, party: PartyState, content: GameData, realm_id: int) -> void:
	_hp.value = fraction(int(member.get("health", 0)), int(member.get("maxHealth", 0)))
	_mp.value = fraction(int(member.get("mana", 0)), int(member.get("maxMana", 0)))
	var bindings: Array = member.get("hotbarBindings", [])
	var invested: Array = member.get("hotbarInvested", [])
	for i in 4:
		var id := int(bindings[i]) if i < bindings.size() else 0
		var level := int(invested[i]) if i < invested.size() else 0
		var total := content.abilities.cooldown_ms(id, level) if id > 0 else 0
		_cells[i][1].size = Vector2(CELL, CELL * party.cooldown_fraction(member, i, total))
	var member_realm := int(member.get("realmId", 0))
	modulate.a = 1.0 if realm_id == 0 or member_realm == 0 or member_realm == realm_id else OTHER_REALM_ALPHA


static func fraction(value: int, maximum: int) -> float:
	return clampf(float(value) / maximum, 0.0, 1.0) if maximum > 0 else 0.0


## The web client's inspect card, as lines.
static func inspect_text(member: Dictionary, content: GameData) -> String:
	var stats: Dictionary = member.get("stats", {})
	return "\n".join([
		String(member.get("name", "?")),
		"Lv %d %s" % [int(member.get("level", 0)), content.classes_art.display_name(int(member.get("classId", 0)))],
		"HP %d/%d" % [int(member.get("health", 0)), int(member.get("maxHealth", 0))],
		"MP %d/%d" % [int(member.get("mana", 0)), int(member.get("maxMana", 0))],
		"STR %d  DEF %d  SPD %d  DEX %d" % [int(stats.get("str", 0)), int(stats.get("def", 0)),
			int(stats.get("spd", 0)), int(stats.get("dex", 0))],
		"VIT %d  WIS %d" % [int(stats.get("vit", 0)), int(stats.get("wis", 0))],
	])


static func _picture(into: Container, side: int) -> TextureRect:
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(side, side)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(picture)
	return picture
