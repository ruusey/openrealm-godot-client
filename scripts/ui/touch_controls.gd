class_name TouchControls
extends CanvasLayer

## The on-screen buttons: Bag, Menu (TouchMenu), Chat and the potions on
## every screen. Touch controls add a move stick under the left thumb and
## Attack with the three abilities, and put away the hotbar they duplicate
## (points are spent on Menu's Character sheet): on a touchscreen or with
## --touch (the mouse a finger), in points scaled by the pixel ratio.
## aim_point() is INF without touch, ZERO with Attack up, else TouchAim's.

const AIM_REACH_PX := TouchAim.REACH_PX
## Where a touch raises the move stick: the left side, below the top panels.
const MOVE_ZONE := Rect2(0.0, 0.2, 0.45, 0.8)
const STICK_SIZE := 110.0
const PANELS_TOP := 8.0   # Bag, Menu and Chat's row
const TIP_SIZE := 44.0

var state: RealmState
var caster: AbilityCaster
var content: GameData
var inventory: InventoryPanel
var options: OptionsPanel
var bar: AbilityBar
var enabled := false
var shown := true   # asked for by name in a scripted capture; otherwise always
## The device's pixel ratio; points times this are the screen's pixels.
var pixel_ratio := 1.0:
	set(value):
		pixel_ratio = value
		if is_inside_tree():
			_layout()

var _move := TouchButtons.stick(STICK_SIZE, TIP_SIZE)
var _cluster := TouchCluster.new()
var _menu := TouchMenu.new()
var _open_chat := Callable()   # the Chat button's; wired by `link`
var _aim := TouchAim.new()


## Whether to show them: asked for, a touchscreen present, or a phone's
## browser -- the web client's user-agent test, in the engine's terms.
static func wanted(flag: bool, touchscreen: bool, has_feature: Callable) -> bool:
	return flag or touchscreen or has_feature.call("web_android") or has_feature.call("web_ios")


func setup(realm_state: RealmState, ability_caster: AbilityCaster, game_data: GameData,
		bag: InventoryPanel, options_panel: OptionsPanel, hotbar: AbilityBar = null) -> void:
	state = realm_state
	caster = ability_caster
	content = game_data
	inventory = bag
	options = options_panel
	bar = hotbar


func _ready() -> void:
	# Under every panel (11 and up), so a tap on one is the panel's (AGENTS.md).
	layer = 10
	add_child(_move)
	_cluster.cast.connect(func(slot: int) -> void: if caster != null: caster.cast(slot, cast_point()))
	_cluster.drink.connect(func(hp: bool) -> void:
		if inventory != null and inventory.actions != null:
			inventory.actions.drink(hp))
	_cluster.bag.connect(func() -> void: inventory.toggle())
	_cluster.menu.connect(_menu.toggle)
	_cluster.chat.connect(func() -> void: if _open_chat.is_valid(): _open_chat.call())
	add_child(_cluster)
	add_child(_menu)
	# Deferred: DisplayScale answers the same resize, and the canvas's own
	# scale has to be settled before the layer's is worked out against it.
	get_viewport().size_changed.connect(_layout.call_deferred)
	_layout()
	_cluster.show_combat(enabled)
	visible = false


## Touch controls on, and whether the mouse should stand in for a finger (a
## desktop with --touch); off leaves the buttons every screen has.
func enable(on: bool, emulate_with_mouse := false) -> void:
	enabled = on
	_move.visible = on
	_cluster.show_combat(on)
	if bar != null:
		bar.shown = not on
	if on:
		Input.set_emulate_touch_from_mouse(emulate_with_mouse)
		# Put away until asked for: open, it takes the stick's left side.
		if inventory != null:
			inventory.shown = false
		if is_inside_tree():
			_layout()


## Up in a realm; the lock-on ring is the touch layer's to place only with
## touch controls -- on a desktop the cursor's (PlayerInput).
func _process(_delta: float) -> void:
	visible = shown and state != null and state.local.is_present()
	if not visible:
		_menu.visible = false
		return
	_cluster.refresh(content, state)
	if enabled:
		TouchAim.lock(state)


## Points, then the layer scales them to the screen.
func _layout() -> void:
	var canvas: float = get_window().content_scale_factor if get_window() != null else 1.0
	# A thumb's size only with touch controls; a desktop's UI size otherwise.
	scale = Vector2.ONE * maxf(1.0, (pixel_ratio if enabled else 1.0) / canvas)
	var area := get_viewport().get_visible_rect().size / scale.x
	_move.position = area * MOVE_ZONE.position
	_move.size = area * MOVE_ZONE.size
	var row := Vector2(TouchCluster.MARGIN, PANELS_TOP)
	_cluster.place(area, row)
	_menu.place(row + Vector2(0.0, TouchCluster.BUTTON_SIZE.y + 8.0), scale)
	# The bag opens under Bag and Menu, on the left, in the canvas's pixels.
	if enabled and inventory != null:
		inventory.floor_top = (row.y + TouchCluster.BUTTON_SIZE.y + 8.0) * scale.x


## Where the row of Bag, Menu and Chat ends, in the canvas's pixels: the
## left column of panels starts under it.
func row_bottom() -> float:
	return (PANELS_TOP + TouchCluster.BUTTON_SIZE.y) * scale.x


## A click on a button is not a shot at the world.
func captures_mouse() -> bool:
	return visible and (_cluster.holds(_cluster.get_global_mouse_position())
		or _menu.holds(_menu._list.get_global_mouse_position()))


## The panels Menu lists, as [label, Callable], and what the Chat button opens.
func link(panels: Array, open_chat: Callable) -> void:
	_menu.set_items(panels)
	_open_chat = open_chat


## Where a basic shot goes: see the header.
func aim_point() -> Vector2:
	if not enabled:
		return Vector2.INF
	var at := _aim.target(state)
	return at if _cluster.attacking else Vector2.ZERO


## Where an ability goes: the same target, held or not.
func cast_point() -> Vector2:
	return _aim.target(state) if enabled else Vector2.INF
