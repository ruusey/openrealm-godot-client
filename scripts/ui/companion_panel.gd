class_name CompanionPanel
extends CanvasLayer

## Manage your AI party: the companions that fight alongside you when you are
## not in a live player party. Opened from the top-left Party menu button.
##
## One card per owned companion (up to three): rename, deploy/recall, delete,
## five equipment cells you drag bag items onto (double-click to unequip), and
## a skill-point row per class ability. Every change is one CompanionActionPacket
## to the server, which answers with a fresh roster (CompanionRosterPacket) — so
## the panel only ever rebuilds from state.companions, never from local guesses.

# Master client kill switch for the AI companion UI. Defaults ON; set to false
# to hide it (the Companions menu button is never added, so the panel becomes
# unreachable).
const ENABLED := true

const MAX_OWNED := 3
const MAX_ACTIVE := 3
const TITLE_COLOUR := Color(1.0, 0.85, 0.42)
const MUTED := Color(0.6, 0.6, 0.65)
const CAPTIONS := ["Wpn", "Arm", "Gnt", "Bts", "Rng"]

var state: RealmState
var content: GameData
var actions: CompanionActions
var shown := false

var _root: PanelContainer
var _title: Label
var _new_row: HBoxContainer
var _picker: OptionButton
var _cards_box: VBoxContainer
var _drawn := -1
var _typing := false


func setup(realm_state: RealmState, game_data: GameData, companion_actions: CompanionActions) -> void:
	state = realm_state
	content = game_data
	actions = companion_actions


func _ready() -> void:
	layer = 13
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(340, 0)
	centre.add_child(_root)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _line(header, "Companions", 16, TITLE_COLOUR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Last-resort unstick: yank every deployed companion to your side.
	InventoryLayout.button(header, "Summon All", func() -> void: if actions != null: actions.summon_all())
	InventoryLayout.button(header, "Close", close)

	_new_row = HBoxContainer.new()
	_new_row.add_theme_constant_override("separation", 6)
	column.add_child(_new_row)
	_line(_new_row, "New:", 12, MUTED)
	# Filled lazily in _process once shown — the class catalog loads from the data
	# service after login, so it is empty here at build time.
	_picker = OptionButton.new()
	_new_row.add_child(_picker)
	InventoryLayout.button(_new_row, "Create", _on_create)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 10)
	column.add_child(_cards_box)


func _process(_delta: float) -> void:
	visible = state != null and content != null and shown and state.local.is_present()
	if not visible:
		return
	PanelFit.shrink(_root)
	if state.companions.version != _drawn:
		_rebuild()


## Fill the class dropdown from the content catalog, excluding classes already on
## the team (your own class + each companion's) so no two members share a class.
## Called lazily (character-classes.json loads from the data service after login)
## and again on every roster change, since the taken-class set shifts.
func _populate_picker() -> void:
	if content == null:
		return
	var taken := {}
	taken[int(state.local.class_id)] = true
	for c in state.companions.roster:
		taken[int(c.get("characterClass", -1))] = true
	var prev := _picker.get_selected_id()
	_picker.clear()
	# Show every class; grey out (disable) the ones already on the team so the
	# player can see what's unavailable rather than wondering where it went.
	var first_available := -1
	for class_id in content.classes_art.class_ids():
		var cid := int(class_id)
		var idx := _picker.item_count
		_picker.add_item(content.classes_art.display_name(cid))
		_picker.set_item_id(idx, cid)
		if taken.has(cid):
			_picker.set_item_disabled(idx, true)
		elif first_available < 0:
			first_available = idx
	# Keep the prior pick if it's still selectable, else the first available class.
	var prev_idx := _picker.get_item_index(prev) if prev >= 0 else -1
	if prev_idx >= 0 and not _picker.is_item_disabled(prev_idx):
		_picker.select(prev_idx)
	elif first_available >= 0:
		_picker.select(first_available)


func toggle() -> void:
	shown = not shown
	# Force a rebuild on open so the picker reflects the current taken-class set
	# even if the roster version hasn't changed since last time.
	if shown:
		_drawn = -1


func close() -> void:
	shown = false


func is_typing() -> bool:
	return visible and _typing


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())


func _on_create() -> void:
	if state.companions.count() >= MAX_OWNED:
		return
	var cid := _picker.get_selected_id()
	# -1 when every class is taken (nothing selectable); server also rejects dupes.
	if cid < 0:
		return
	actions.create(cid)


func _rebuild() -> void:
	_drawn = state.companions.version
	var roster := state.companions.roster
	var active := state.companions.active_count()
	_title.text = "Companions %d/%d  (deployed %d/%d)" % [roster.size(), MAX_OWNED, active, MAX_ACTIVE]
	# Taken-class set changes with the roster, so refresh the picker here.
	_populate_picker()
	_new_row.visible = roster.size() < MAX_OWNED
	for child in _cards_box.get_children():
		child.queue_free()
	for companion in roster:
		_cards_box.add_child(_card(companion))


func _card(companion: Dictionary) -> Control:
	var uuid := str(companion.get("companionUuid", ""))
	var class_id := int(companion.get("characterClass", 0))
	var is_active := bool(companion.get("active", false))
	var frame := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var name_edit := LineEdit.new()
	name_edit.text = str(companion.get("companionName", "Companion"))
	name_edit.max_length = 16
	name_edit.custom_minimum_size.x = 120
	name_edit.focus_entered.connect(func() -> void: _typing = true)
	name_edit.focus_exited.connect(func() -> void: _typing = false)
	name_edit.text_submitted.connect(func(text: String) -> void: actions.rename(uuid, text))
	head.add_child(name_edit)
	InventoryLayout.button(head, "Rename", func() -> void: actions.rename(uuid, name_edit.text))
	var class_label := _line(head, content.classes_art.display_name(class_id), 12, MUTED)
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var deploy_text := "Recall" if is_active else "Deploy"
	var deploy := InventoryLayout.button(head, deploy_text,
		func() -> void:
			if is_active: actions.recall(uuid)
			else: actions.deploy(uuid))
	deploy.disabled = not is_active and state.companions.active_count() >= MAX_ACTIVE
	InventoryLayout.button(head, "X", func() -> void: actions.delete(uuid))

	_gear_row(box, companion, uuid)
	_skills(box, companion, uuid, class_id)
	return frame


## Five equipment cells. A bag item dropped on one equips it; double-click unequips.
func _gear_row(into: Container, companion: Dictionary, uuid: String) -> void:
	var by_slot := {}
	for item in companion.get("items", []):
		by_slot[int(item.get("slotIdx", -1))] = item
	var row := HBoxContainer.new()
	into.add_child(row)
	for i in 5:
		var cell := VBoxContainer.new()
		var slot := CompanionEquipSlot.new(i, true)
		slot.show_from(by_slot.get(i, {}), content)
		slot.dropped.connect(func(from_index: int, _to: int) -> void: actions.equip(uuid, from_index, i))
		slot.activated.connect(func(_index: int) -> void: actions.unequip(uuid, i))
		cell.add_child(slot)
		InventoryLayout.heading(cell, CAPTIONS[i]).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cell)


## Skill-point rows, one per class ability slot — mirrors SkillsPanel but invests
## into THIS companion (by ability id, resolved client-side from the hotbar slot).
func _skills(into: Container, companion: Dictionary, uuid: String, class_id: int) -> void:
	var stats: Dictionary = companion.get("stats", {})
	var points := int(stats.get("availableSkillPoints", 0))
	var invested: Dictionary = stats.get("abilitySkillPoints", {})
	_line(into, "Skill points: %d" % points, 12, Color.WHITE)
	for slot in AbilityCatalog.SLOTS:
		var ability_id := content.abilities.hotbar_id(class_id, slot)
		var definition := content.abilities.ability(ability_id)
		if definition.is_empty():
			continue
		var level := int(invested.get(str(ability_id), 0))
		var cap := content.abilities.cap(ability_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		into.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = content.abilities.icon(ability_id)
		row.add_child(icon)
		var name_label := _line(row, str(definition.get("name", "")), 12, Color.WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_line(row, "%d/%d" % [level, cap], 12, MUTED)
		var invest := InventoryLayout.button(row, "+", func() -> void: actions.invest(uuid, ability_id))
		invest.disabled = not (points > 0 and level < cap)


func _line(into: Container, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	into.add_child(label)
	return label
