class_name AbilityBar
extends CanvasLayer

## The hotbar: the class passive, then the three abilities and their keys.
##
## Godot's own controls, like the bag. The cells are built once and repainted
## when the class, the points or the levels change; the cooldown shades are
## driven every frame off AbilityState, which is where a cast puts them, so
## a cast from a key and a cast from a click drain the same cell.

const MARGIN := 8
const KEYS := ["", "1", "2", "3"]
const NAME_COLOUR := Color(1.0, 0.85, 0.42)
const MUTED := Color(0.6, 0.6, 0.65)
const BODY := Color(0.85, 0.85, 0.88)
const DAMAGE_COLOUR := Color(0.9, 0.66, 0.4)
const PIERCE_COLOUR := Color(0.4, 0.66, 1.0)
const EFFECT_COLOUR := Color(0.56, 0.82, 0.56)

var state: RealmState
var content: GameData
var caster: AbilityCaster
## Opened by a right-click on a cell, where the web client invests a point.
var skills: SkillsPanel
var shown := true

var _root: PanelContainer
var _cells: Array = []
var _tooltip: ItemTooltip
var _drawn := ""


func setup(realm_state: RealmState, game_data: GameData, ability_caster: AbilityCaster,
		skills_panel: SkillsPanel = null) -> void:
	state = realm_state
	content = game_data
	caster = ability_caster
	skills = skills_panel


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.offset_bottom = -MARGIN
	add_child(_root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_root.add_child(row)
	for i in KEYS.size():
		var cell := AbilityCell.new(i, KEYS[i])
		cell.pressed.connect(_on_pressed)
		cell.secondary.connect(_on_secondary)
		cell.hovered.connect(_on_hover)
		row.add_child(cell)
		_cells.append(cell)
	_tooltip = ItemTooltip.new()
	add_child(_tooltip)


func _process(_delta: float) -> void:
	visible = state != null and content != null and shown and state.local.is_present()
	if not visible:
		_tooltip.hide_card()
		return
	var key := "%d:%d" % [state.local.class_id, state.abilities.version]
	if key != _drawn:
		refresh()
	for slot in AbilityCatalog.SLOTS:
		_cells[slot + 1].set_cooldown(state.abilities.cooldown_fraction(slot))
	if _tooltip.visible:
		_tooltip.follow(_root.get_global_mouse_position())


func refresh() -> void:
	var class_id := state.local.class_id
	_drawn = "%d:%d" % [class_id, state.abilities.version]
	var passive := content.abilities.passive(class_id)
	if passive.is_empty():
		_cells[0].show_empty()
	else:
		_cells[0].show_ability(null, str(passive.get("name", "?")), 0, 0, 0)
	for slot in AbilityCatalog.SLOTS:
		var id := content.abilities.hotbar_id(class_id, slot)
		var definition := content.abilities.ability(id)
		if definition.is_empty():
			_cells[slot + 1].show_empty()
			continue
		_cells[slot + 1].show_ability(content.abilities.icon(id), str(definition.get("name", "")),
			int(definition.get("mpCost", 0)), state.abilities.invested[slot],
			content.abilities.cap(id))


func toggle() -> void:
	shown = not shown


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


## What the card over a cell says.
func describe(index: int) -> Array:
	var class_id := state.local.class_id
	if index == 0:
		var passive := content.abilities.passive(class_id)
		if passive.is_empty():
			return []
		return [[str(passive.get("name", "")), NAME_COLOUR], ["Class passive - always on", MUTED],
			[str(passive.get("description", "")), BODY]]
	var slot := index - 1
	var id := content.abilities.hotbar_id(class_id, slot)
	var definition := content.abilities.ability(id)
	if definition.is_empty():
		return []
	var invested: int = state.abilities.invested[slot]
	var lines: Array = [[str(definition.get("name", "")), NAME_COLOUR]]
	var subtitle := "Active - Key %s" % KEYS[index]
	var tags := _tags_text(definition)
	if tags != "":
		subtitle += " - " + tags
	lines.append([subtitle, MUTED])
	var description := str(definition.get("description", ""))
	if description != "":
		lines.append([description, BODY])
	lines.append_array(_damage_lines(definition, invested))
	lines.append([_facts_text(definition, id, invested), MUTED])
	for effect in definition.get("effects", []):
		var effect_text := _effect_text(effect, definition, invested)
		if effect_text != "":
			lines.append([effect_text, EFFECT_COLOUR])
	for scaling in definition.get("scalings", []):
		if str(scaling.get("target", "")).to_upper() == "DAMAGE":
			continue
		lines.append([_scaling_text(scaling, invested), MUTED])
	lines.append(["Level %d/%d" % [invested, content.abilities.cap(id)], MUTED])
	return lines


## Damage total plus the per-stat breakdown that builds it, like the web client:
## "Damage 162" then "= 90 base +48 (STR) +24 (SPx3)". Empty for a non-damage ability.
func _damage_lines(definition: Dictionary, invested: int) -> Array:
	var base := int(definition.get("baseDamage", 0))
	var total := float(base)
	var parts := PackedStringArray()
	if base > 0:
		parts.append("%d base" % base)
	for scaling in definition.get("scalings", []):
		if str(scaling.get("target", "")).to_upper() != "DAMAGE":
			continue
		var contribution := _scaling_contribution(scaling, invested)
		if contribution > 0:
			total += contribution
			parts.append("+%d (%s)" % [int(contribution), _stat_label(scaling, invested)])
	if total <= 0:
		return []
	var pierces := _has_tag(definition, "armor_pierce")
	var header := ("Armor-pierce damage %d" if pierces else "Damage %d") % int(total)
	var out: Array = [[header, PIERCE_COLOUR if pierces else DAMAGE_COLOUR]]
	if not parts.is_empty():
		out.append(["= " + " ".join(parts), MUTED])
	return out


## MP, cooldown, cast time and reach on one line, all point-adjusted.
func _facts_text(definition: Dictionary, id: int, invested: int) -> String:
	var facts := PackedStringArray()
	var mp := int(definition.get("mpCost", 0))
	if mp > 0:
		facts.append("MP %d" % mp)
	facts.append("Cooldown %.1fs" % (content.abilities.cooldown_ms(id, invested) / 1000.0))
	var cast := content.abilities.cast_ms(id, invested)
	facts.append("Instant" if cast <= 0 else "Cast %.1fs" % (cast / 1000.0))
	var reach := int(definition.get("maxCastRange", -1))
	facts.append("Self" if reach == 0 else ("Range %d" % reach if reach > 0 else "Ranged"))
	return " - ".join(facts)


## One effect in words: a status and its duration, a heal, a shield, and so on.
func _effect_text(effect: Dictionary, definition: Dictionary, invested: int) -> String:
	var kind := str(effect.get("type", "")).to_upper()
	var target := _target_text(str(effect.get("target", "")))
	match kind:
		"STATUS_APPLY":
			# Total duration at the current rank (base + per-point/per-stat scaling),
			# so the shown duration equals the real one -- base alone was wrong for
			# every scaling self-buff and HoT.
			var duration := (float(effect.get("baseDurationMs", 0))
				+ _status_duration_bonus(effect, definition, invested)) / 1000.0
			var status := _status_name(effect.get("statusId", ""))
			return "Apply %s%s%s" % [status, (" %.1fs" % duration) if duration > 0 else "", target]
		"HEAL":
			# Show the total at the current rank (base + per-point scaling), like damage,
			# so the number matches what the ability actually heals in game.
			return "Heal %d HP%s" % [_effect_total(effect, definition, invested, "HEAL"), target]
		"SHIELD":
			return "Shield %d HP%s" % [_effect_total(effect, definition, invested, "SHIELD"), target]
		"CLEANSE":
			var count := int(effect.get("baseMagnitude", 0))
			return "Cleanse " + ("all effects" if count <= 0 else "%d effects" % count)
		"TELEPORT":
			return "Teleport to target"
		"REFLECT_PROJECTILE":
			return "Reflect projectiles x%s" % _number(effect.get("damageMul", 1))
		"EMPOWER_NEXT_BASIC":
			return "Empower next basic +%d%%" % int(effect.get("baseMagnitude", 0))
		"SPAWN_POTIONS":
			return "Drop %d potions" % int(effect.get("baseMagnitude", 0))
		_:
			return ""


## A non-damage scaling: "DEX x1.5 -> Radius (+3)".
func _scaling_text(scaling: Dictionary, invested: int) -> String:
	var target := _prettify(str(scaling.get("target", "")))
	var contribution := _scaling_contribution(scaling, invested)
	var current := " (+%d)" % int(contribution) if contribution > 0 else ""
	return "%s x%s -> %s%s" % [_stat_label(scaling, invested), _number(scaling.get("coeff", 0)), target, current]


## An effect's magnitude at the current rank: its base plus every scaling that
## targets it (HEAL/SHIELD). Mirrors the server's base + scaling sum so the shown
## number equals the real effect.
func _effect_total(effect: Dictionary, definition: Dictionary, invested: int, target_kind: String) -> int:
	var total := int(effect.get("baseMagnitude", 0))
	for scaling in definition.get("scalings", []):
		if str(scaling.get("target", "")).to_upper() == target_kind:
			total += int(_scaling_contribution(scaling, invested))
	return total


## Extra duration (ms) a status gains at the current rank. Mirrors the server: a
## SELF status takes every "DURATION" scaling (selfDurationBonusMs); a targeted
## status (allies/enemies) takes the "STATUS_DURATION_MS" scalings keyed to its
## own effect index (statusDurationBonusMs).
func _status_duration_bonus(effect: Dictionary, definition: Dictionary, invested: int) -> float:
	var is_self := str(effect.get("target", "")).to_upper() == "SELF"
	var index: int = definition.get("effects", []).find(effect)
	var bonus := 0.0
	for scaling in definition.get("scalings", []):
		var target := str(scaling.get("target", "")).to_upper()
		if is_self and target == "DURATION":
			bonus += _scaling_contribution(scaling, invested)
		elif target == "STATUS_DURATION_MS" and int(scaling.get("effectIndex", -1)) == index:
			bonus += _scaling_contribution(scaling, invested)
	return bonus


## How much a scaling adds right now: the stat (or invested points) times the
## coefficient. Linear only -- the server's other curves aren't previewed.
func _scaling_contribution(scaling: Dictionary, invested: int) -> float:
	return _stat_value(str(scaling.get("stat", "")), invested) * float(scaling.get("coeff", 0))


func _stat_value(stat: String, invested: int) -> float:
	if _is_skill_point_stat(stat):
		return float(invested)
	return float(state.local.stats.get(stat.to_lower(), 0))


func _stat_label(scaling: Dictionary, invested: int) -> String:
	var stat := str(scaling.get("stat", ""))
	return "SPx%d" % invested if _is_skill_point_stat(stat) else stat.to_upper()


func _is_skill_point_stat(stat: String) -> bool:
	var upper := stat.to_upper()
	return upper == "SKILL_POINTS" or upper == "SKILLPOINTS" or upper == "SP" or upper == "POINTS"


func _has_tag(definition: Dictionary, tag: String) -> bool:
	for entry in definition.get("tags", []):
		if str(entry) == tag:
			return true
	return false


func _tags_text(definition: Dictionary) -> String:
	var tags := PackedStringArray()
	for entry in definition.get("tags", []):
		tags.append(str(entry))
	return ", ".join(tags)


func _target_text(target: String) -> String:
	return "" if target == "" else " to " + _prettify(target).to_lower()


## A status id (as it arrives in ability JSON, a numeric string) to its name, so the
## info card reads "Apply Slow" / "Apply Dome", never "Apply 21". Falls back to
## prettifying whatever was there for any id the chip table doesn't know.
func _status_name(raw: Variant) -> String:
	var text := str(raw)
	if text.is_valid_int():
		var label := StatusChips.label_for(int(text))
		if label != "":
			return label
	return _prettify(text)


## A JSON enum to words: "ENEMIES_HIT" -> "Enemies hit".
func _prettify(raw: String) -> String:
	if raw == "":
		return ""
	var words := raw.to_lower().replace("_", " ")
	return words.substr(0, 1).to_upper() + words.substr(1)


func _number(value) -> String:
	var number := float(value)
	return str(int(number)) if is_equal_approx(number, round(number)) else "%.1f" % number


func _on_pressed(index: int) -> void:
	if index > 0 and caster != null:
		caster.cast_at_cursor(index - 1)


func _on_secondary(index: int) -> void:
	if index > 0 and skills != null:
		skills.toggle()


func _on_hover(index: int, over: bool) -> void:
	var lines := describe(index) if over and visible else []
	if lines.is_empty():
		_tooltip.hide_card()
	else:
		_tooltip.show_lines(lines, _root.get_global_mouse_position())
