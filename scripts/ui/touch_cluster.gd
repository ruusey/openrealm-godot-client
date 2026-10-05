class_name TouchCluster
extends Control

## The phone's buttons: under the right thumb Attack in the corner, held
## to shoot at what AutoAim finds, and the three hotbar abilities in an arc
## over it, each a tap -- the arrangement every phone action game settles
## on -- with the HP and MP potions on the bottom row beside them, their
## counts on them; Bag and Menu top-left, over where the bag opens, so
## nothing on the right is ever covered by a panel. Laid out in points;
## the layer scales.

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
const BUTTON_SIZE := Vector2(88.0, 40.0)

signal cast(slot: int)
signal drink(hp: bool)
signal bag
signal menu
signal chat
signal nexus
signal add_fame
signal economy

## True while the thumb is on Attack.
var attacking := false

var _attack: Button
var _abilities: Array[Button] = []
var _sweeps: Array[CooldownSweep] = []
var _hp: Button
var _mp: Button
var _panels: BoxContainer
## On a phone the top row collapses into a hamburger with a tap-to-close dim.
var _mobile := OS.has_feature("web_android") or OS.has_feature("web_ios") \
	or OS.has_feature("android") or OS.has_feature("ios")
var _hamburger: Button
var _backdrop: ColorRect
var _drawn := ""
var _area := Vector2.ZERO
var _row := Vector2.ZERO


## Built when made, not when it enters the tree, so the buttons can be
## shown or hidden before then -- a scripted capture enables first.
func _init() -> void:
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
	# Horizontal on desktop; a vertical dropdown on a phone, where the full row
	# won't fit across the screen.
	_panels = VBoxContainer.new() if _mobile else HBoxContainer.new()
	_panels.add_theme_constant_override("separation", 8)
	_panels.add_child(_panel_button("Bag", bag))
	_panels.add_child(_panel_button("Menu", menu))
	_panels.add_child(_panel_button("Chat", chat))
	# Escape to safety: no portal to stand on on a phone, so it rides the top row.
	_panels.add_child(_panel_button("Nexus", nexus))
	# Buy fame with SOL via Phantom -- web build only (Phantom is a browser wallet).
	if OS.has_feature("web"):
		_panels.add_child(_panel_button("Add Fame", add_fame))
		_panels.add_child(_panel_button("Economy", economy))
	add_child(_panels)
	# On a phone the row hides behind a hamburger, with a tap-anywhere dim behind
	# the open menu that darkens the game and closes on a tap.
	if _mobile:
		_backdrop = ColorRect.new()
		_backdrop.color = Color(0, 0, 0, 0.6)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.visible = false
		_backdrop.gui_input.connect(_on_backdrop_input)
		add_child(_backdrop)
		move_child(_backdrop, 0)   # behind the buttons, over the game
		_panels.visible = false
		_hamburger = TouchButtons.flat("☰", BUTTON_SIZE, _toggle_menu)
		add_child(_hamburger)


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
	var x := centre.x - reach - ABILITY_RADIUS - GAP - POTION_RADIUS if _attack.visible \
		else area.x - MARGIN - POTION_RADIUS
	for potion in [_hp, _mp]:
		potion.position = Vector2(x, centre.y) - Vector2.ONE * POTION_RADIUS
		x -= POTION_RADIUS * 2.0 + GAP
	if _mobile:
		_hamburger.position = panels_at
		_panels.position = panels_at + Vector2(0.0, BUTTON_SIZE.y + GAP)
		_backdrop.position = Vector2.ZERO
		_backdrop.size = area
	else:
		_panels.position = panels_at


## The potion counts and the cooldowns every frame; the slots' icons when
## the class or the bindings change.
func refresh(content: GameData, state: RealmState) -> void:
	if state != null:
		_show_count(_hp, "HP", state.local.inventory.hp_potions)
		_show_count(_mp, "MP", state.local.inventory.mp_potions)
		for slot in _sweeps.size():
			_sweeps[slot].fraction = state.abilities.cooldown_fraction(slot)
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


## Attack and the abilities: with touch controls only.
func show_combat(on: bool) -> void:
	_attack.visible = on
	for button in _abilities:
		button.visible = on
	place(_area, _row)


## Whether a shown button holds the point.
func holds(point: Vector2) -> bool:
	for button in [_attack, _hp, _mp, _panels] + _abilities:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true
	if _hamburger != null and _hamburger.is_visible_in_tree() and _hamburger.get_global_rect().has_point(point):
		return true
	# While the menu is open the dim covers the screen: a tap anywhere is the
	# menu's (to close it), never a shot at the world.
	if _backdrop != null and _backdrop.visible and _backdrop.get_global_rect().has_point(point):
		return true
	return false


func _panel_button(label: String, sig: Signal) -> Button:
	return TouchButtons.flat(label, BUTTON_SIZE, _on_panel_pressed.bind(sig))


func _on_panel_pressed(sig: Signal) -> void:
	sig.emit()
	if _mobile:
		_collapse_menu()


func _toggle_menu() -> void:
	var show_menu := not _panels.visible
	_panels.visible = show_menu
	_backdrop.visible = show_menu


func _collapse_menu() -> void:
	_panels.visible = false
	if _backdrop != null:
		_backdrop.visible = false


func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_collapse_menu()


static func _show_count(button: Button, name: String, count: int) -> void:
	button.text = "%s %d" % [name, count]
	button.disabled = count <= 0
