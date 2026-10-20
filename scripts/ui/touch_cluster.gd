class_name TouchCluster
extends Control

## The phone's buttons: under the right thumb Attack in the corner, held
## to shoot at what AutoAim finds, and the three hotbar abilities in an arc
## over it, each a tap -- the arrangement every phone action game settles
## on -- with the HP and MP potions on the bottom row beside them, their
## counts on them, and on a phone Nexus beside those, one tap from safety.
## Without a phone layout Bag and Menu sit top-left, over where the bag
## opens; with one they are PhoneBar's. Laid out in points; the layer scales.

const ATTACK_RADIUS := 52.0
const ABILITY_RADIUS := 26.0
const POTION_RADIUS := 24.0
const POTION_FONT := 13
const GAP := 12.0
const MARGIN := 20.0
## Where the three sit around Attack: straight up, up and left, left.
const ARC := [PI * 0.5, PI * 0.75, PI]
const ATTACK_COLOUR := Color(0.75, 0.2, 0.2, 0.85)
const ABILITY_COLOUR := Color(0.15, 0.15, 0.2, 0.85)
const HP_COLOUR := Color(0.6, 0.12, 0.12, 0.9)
const MP_COLOUR := Color(0.15, 0.25, 0.65, 0.9)
const NEXUS_COLOUR := Color(0.62, 0.46, 0.08, 0.9)
const COMPANION_COLOUR := Color(0.16, 0.35, 0.40, 0.9)
const COMPANION_FONT := 11
const BUTTON_SIZE := Vector2(88.0, 40.0)

signal cast(slot: int)
signal drink(hp: bool)
signal bag
signal menu
signal chat
signal nexus
signal companion
signal buy_fame

## True while the thumb is on Attack.
var attacking := false

var _attack: Button
var _abilities: Array[Button] = []
var _sweeps: Array[CooldownSweep] = []
var _hp: Button
var _mp: Button
## The phone's escape to the nexus, on the bottom row; null elsewhere, where
## Nexus rides the top row.
var _nexus: Button
## Summon / recall, with touch controls only (the hotbar's cell otherwise).
var _companion: Button
var _companion_sweep: CooldownSweep
var _panels: BoxContainer
## On the top row only while fame packages are on sale.
var _buy_fame: Button
## A phone layout: Nexus on the bottom row and no top row (PhoneBar has it).
var _mobile: bool
var _drawn := ""
var _area := Vector2.ZERO
var _row := Vector2.ZERO


## Built when made, not when it enters the tree, so the buttons can be
## shown or hidden before then -- a scripted capture enables first.
func _init(mobile := PhoneLayout.on) -> void:
	_mobile = mobile
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack = TouchButtons.round(ATTACK_RADIUS, ATTACK_COLOUR)
	_attack.text = "Attack"
	_attack.button_down.connect(func() -> void: attacking = true)
	_attack.button_up.connect(func() -> void: attacking = false)
	add_child(_attack)
	for slot in AbilityCatalog.SLOTS:
		var button := TouchButtons.round(ABILITY_RADIUS, ABILITY_COLOUR)
		button.text = str(slot + 1)
		button.pressed.connect(func() -> void: cast.emit(slot))
		add_child(button)
		_abilities.append(button)
		var sweep := CooldownSweep.new()
		button.add_child(sweep)
		_sweeps.append(sweep)
	_hp = _potion(HP_COLOUR, true)
	_mp = _potion(MP_COLOUR, false)
	if _mobile:
		_nexus = TouchButtons.round(POTION_RADIUS, NEXUS_COLOUR)
		_nexus.text = "Nexus"
		_nexus.add_theme_font_size_override("font_size", POTION_FONT)
		_nexus.pressed.connect(func() -> void: nexus.emit())
		add_child(_nexus)
	_companion = TouchButtons.round(POTION_RADIUS, COMPANION_COLOUR)
	_companion.add_theme_font_size_override("font_size", COMPANION_FONT)
	_companion.pressed.connect(func() -> void: companion.emit())
	add_child(_companion)
	_companion_sweep = CooldownSweep.new()
	_companion.add_child(_companion_sweep)
	if not _mobile:
		_build_panels()


func _build_panels() -> void:
	_panels = HBoxContainer.new()
	_panels.add_theme_constant_override("separation", 8)
	_panels.add_child(_panel_button("Bag", bag))
	# Opens the panel list (Character/Skills/Quests/...).
	_panels.add_child(_panel_button("More", menu))
	_panels.add_child(_panel_button("Chat", chat))
	_panels.add_child(_panel_button("Nexus", nexus))
	_buy_fame = _panel_button("Buy Fame", buy_fame)
	_buy_fame.visible = false
	_panels.add_child(_buy_fame)
	add_child(_panels)


## Attack and the abilities in the bottom-right corner of `area`, Bag and
## Menu in a row at `panels_at`.
func place(area: Vector2, panels_at: Vector2) -> void:
	_area = area
	_row = panels_at
	var centre := area - Vector2.ONE * (MARGIN + ATTACK_RADIUS)
	_attack.position = centre - Vector2.ONE * ATTACK_RADIUS
	var reach := ATTACK_RADIUS + GAP + ABILITY_RADIUS
	for slot in _abilities.size():
		var angle: float = ARC[slot]
		_abilities[slot].position = centre + Vector2(cos(angle), -sin(angle)) * reach \
			- Vector2.ONE * ABILITY_RADIUS
	# The bottom row, left of the leftmost ability, nearest the thumb; in
	# the corner itself when there is no Attack beside them.
	var start := centre.x - reach - ABILITY_RADIUS - GAP - POTION_RADIUS if _attack.visible \
		else area.x - MARGIN - POTION_RADIUS
	# A row that would run off the left edge (a phone held upright) carries on
	# in a row above, from the same right end.
	var at := Vector2(start, centre.y)
	for potion in [_hp, _mp, _nexus, _companion]:
		if potion == null or not potion.visible:
			continue
		if at.x - POTION_RADIUS < MARGIN and at.x < start:
			at = Vector2(start, at.y - POTION_RADIUS * 2.0 - GAP)
		potion.position = at - Vector2.ONE * POTION_RADIUS
		at.x -= POTION_RADIUS * 2.0 + GAP
	if _panels != null:
		_panels.position = panels_at


## The potion counts and the cooldowns every frame; the slots' icons when
## the class or the bindings change.
func refresh(content: GameData, state: RealmState) -> void:
	if state != null:
		_show_count(_hp, "HP", state.local.inventory.hp_potions)
		_show_count(_mp, "MP", state.local.inventory.mp_potions)
		for slot in _sweeps.size():
			_sweeps[slot].fraction = state.abilities.cooldown_fraction(slot)
		if _nexus != null and content != null:
			_nexus.disabled = content.maps.is_nexus(state.tiles.map_id)
		if _companion.visible:
			_show_companion(state.companions)
	if content == null or content.abilities == null or state == null:
		return
	var key := "%d:%d" % [state.local.class_id, state.abilities.version]
	if key == _drawn:
		return
	_drawn = key
	for slot in _abilities.size():
		var icon := content.abilities.icon(content.abilities.hotbar_id(state.local.class_id, slot))
		_abilities[slot].icon = icon
		_abilities[slot].text = "" if icon != null else str(slot + 1)


func _potion(colour: Color, hp: bool) -> Button:
	var button := TouchButtons.round(POTION_RADIUS, colour)
	button.add_theme_font_size_override("font_size", POTION_FONT)
	button.pressed.connect(func() -> void: drink.emit(hp))
	add_child(button)
	return button


func show_buy_fame(on: bool) -> void:
	if _buy_fame != null and _buy_fame.visible != on:
		_buy_fame.visible = on


## Attack and the abilities: with touch controls only.
func show_combat(on: bool) -> void:
	_attack.visible = on
	for button in _abilities:
		button.visible = on
	_companion.visible = on and CompanionPanel.ENABLED
	place(_area, _row)


## The round buttons' extent, in the cluster's points.
func bounds() -> Rect2:
	var all := Rect2()
	for button in [_attack, _hp, _mp, _nexus, _companion] + _abilities:
		if button != null and button.visible:
			var rect := Rect2(button.position, button.size)
			all = rect if not all.has_area() else all.merge(rect)
	return all


## Whether a shown button holds the point.
func holds(point: Vector2) -> bool:
	for button in [_attack, _hp, _mp, _nexus, _companion, _panels] + _abilities:
		if button != null and button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true
	return false


func _panel_button(label: String, sig: Signal) -> Button:
	return TouchButtons.flat(label, BUTTON_SIZE, func() -> void: sig.emit())


## Ally (none owned yet: opens the panel), Recall with the time left out, the
## summon cooldown, or Summon.
func _show_companion(companions: CompanionState) -> void:
	var fraction := 0.0
	if companions == null or companions.count() == 0:
		_companion.text = "Ally"
	elif companions.is_deployed():
		if companions.deploy_never_expires():
			_companion.text = "Recall"
		else:
			_companion.text = "Recall\n" + CompanionState.clock_text(companions.deployed_remaining_ms())
	elif not companions.summon_ready():
		var remaining := companions.summon_cooldown_remaining_ms()
		_companion.text = CompanionState.clock_text(remaining)
		fraction = clampf(float(remaining) / CompanionState.SUMMON_COOLDOWN_MS, 0.0, 1.0)
	else:
		_companion.text = "Summon"
	_companion_sweep.fraction = fraction


static func _show_count(button: Button, name: String, count: int) -> void:
	button.text = "%s %d" % [name, count]
	button.disabled = count <= 0
