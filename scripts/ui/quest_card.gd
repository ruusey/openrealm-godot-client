class_name QuestCard
extends PanelContainer

## One quest in the log: the web client's `_questCard`, in Controls.
##
## A left accent and a badge in the status's colour (active blue, available
## amber, complete green and dimmed), the name with CHARACTER / REPEATABLE
## tags, the category and the stars the quest is worth, the description, a
## bar a objective, the rewards as chips, and Accept on an available quest
## or Abandon on an active one that did not start itself. `act` is called
## with "accept" or "abandon" and the quest's id.

const WIDTH := 560
const MUTED := Color("7a8398")
const LOOKS := {
	AccountProgress.ACTIVE: [Color("4d8bff"), Color("1d356b"), Color("9dc0ff"), "IN PROGRESS"],
	AccountProgress.AVAILABLE: [Color("ffb84d"), Color("4a3410"), Color("ffcf87"), "AVAILABLE"],
	AccountProgress.COMPLETE: [Color("4dd07a"), Color("12401f"), Color("93e6b0"), "COMPLETED"],
}

var accept_button: Button
var abandon_button: Button


func _init(quest: Dictionary, content: GameData, act: Callable) -> void:
	var status := AccountProgress.status_of(quest)
	var look: Array = LOOKS.get(status, LOOKS[AccountProgress.AVAILABLE])
	add_theme_stylebox_override("panel", _box(Color("1b1f2a"), look[0]))
	custom_minimum_size.x = WIDTH
	if status == AccountProgress.COMPLETE:
		modulate.a = 0.82
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	var title := String(quest.get("name", "Quest"))
	if quest.get("scoped", false):
		title += "  [CHARACTER]"
	if quest.get("repeatable", false):
		title += "  [REPEATABLE]"
	var name := HudWidgets.label(title, 15, Color("dfe4ee"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var badge := HudWidgets.label(look[3], 11, look[2])
	badge.add_theme_stylebox_override("normal", _box(look[1]))
	head.add_child(badge)

	var line := HBoxContainer.new()
	column.add_child(line)
	var category := HudWidgets.label(String(quest.get("cat", "")), 11, MUTED)
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(category)
	if int(quest.get("stars", 0)) > 0:
		line.add_child(HudWidgets.label("★ %d" % int(quest.get("stars", 0)), 11, TagStyles.STAR_GOLD))
	column.add_child(_wrapped(String(quest.get("desc", "")), 13, Color("b9c2d4")))

	for objective in quest.get("objectives", []):
		QuestObjectiveRow.add(column, objective, WIDTH - 24)
	var rewards: Array = quest.get("rewards", [])
	if not rewards.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		chips.add_child(HudWidgets.label("Rewards:", 12, MUTED))
		for reward in rewards:
			var chip := HudWidgets.label(reward_text(reward, content), 12, Color("cfe0ff"))
			chip.add_theme_stylebox_override("normal", _box(Color("20283a")))
			chips.add_child(chip)
		column.add_child(chips)

	var id := int(quest.get("id", 0))
	if status == AccountProgress.AVAILABLE:
		accept_button = InventoryLayout.button(column, "Accept", func() -> void: act.call("accept", id))
		accept_button.add_theme_color_override("font_color", Color("7be39b"))
	elif status == AccountProgress.ACTIVE and not quest.get("auto", false):
		abandon_button = InventoryLayout.button(column, "Abandon", func() -> void: act.call("abandon", id))
		abandon_button.add_theme_color_override("font_color", Color("ff8a8a"))


## A reward as the web words it (`_questRewardText`).
static func reward_text(reward: Dictionary, content: GameData) -> String:
	var amount := int(reward.get("amount", 0))
	var many := "s" if amount > 1 else ""
	match String(reward.get("type", "")).to_upper():
		"FAME": return "%s Fame" % Mastery.thousands(amount)
		"ITEM", "POTION":
			var id := int(reward.get("targetId", 0))
			var item: Dictionary = content.items.get(id, {}) if content != null else {}
			return String(item.get("name", "Item #%d" % id)) + (" x%d" % amount if amount > 1 else "")
		"SKILL_XP":
			var skill := int(reward.get("skillId", -1))
			var skill_name: String = Mastery.SKILLS[skill][0] if skill >= 0 and skill < Mastery.SKILLS.size() \
				else "Skill %d" % skill
			return "%s %s XP" % [Mastery.thousands(amount), skill_name]
		"STAT_POINT": return "+%d %s" % [amount, String(reward.get("stat", "Stat Point" + many))]
		"UNLOCK_VAULT_CHEST": return "%d Vault Chest%s" % [amount, many]
		"UNLOCK_CHARACTER_SLOT": return "%d Character Slot%s" % [amount, many]
	return String(reward.get("type", ""))


func _wrapped(text: String, size: int, colour: Color) -> Label:
	var label := HudWidgets.label(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Its width before it measures, or it wraps a character a line.
	label.custom_minimum_size.x = WIDTH - 24
	label.size.x = WIDTH - 24
	return label


static func _box(fill: Color, accent := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(4)
	box.set_content_margin_all(3 if accent == Color.TRANSPARENT else 10)
	if accent != Color.TRANSPARENT:
		box.border_color = accent
		box.border_width_left = 4
	return box
