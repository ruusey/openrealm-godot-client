class_name PartyPanel
extends CanvasLayer

## The party you are in: the web client's party section, in Godot's own
## controls, down the left side: at the top, or under the diagnostics
## while /debug has them up.
##
## A heading with the count out of four and a Leave button, then a row
## per teammate (PartyRow) -- never yourself, as neither reference lists
## you. Rows are rebuilt only when the roster's shape changes (who, what
## class, what is on the hotbar, which realm), the web client's shape key;
## between rosters only the bars and the cooldown shades are patched, and
## the shades every frame, so a cooldown drains smoothly between the
## server's half-second updates. Gone the moment the server says partyId 0.

const MARGIN := 10
## From the top of the screen when the diagnostics are off.
const TOP := 8
const WIDTH := 236
const HEADING_COLOUR := Color("fff0a0")

var state: RealmState
var content: GameData
var actions: PartyActions
## The diagnostics, which the panel moves down to clear while they show.
var hud: DebugHud
## Off for a scripted render that is about something else.
var shown := true

var _root: PanelContainer
var _count: Label
var _rows_box: VBoxContainer
var _rows: Array = []
var _shape := ""
var fold: PanelFold


func setup(realm_state: RealmState, game_data: GameData, party_actions: PartyActions,
		debug_hud: DebugHud = null) -> void:
	state = realm_state
	content = game_data
	actions = party_actions
	hud = debug_hud


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.offset_left = MARGIN
	_root.offset_right = MARGIN + WIDTH
	_root.offset_top = TOP
	add_child(_root)
	var column := InventoryLayout.column(_root)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	_count = HudWidgets.label("Party", 13, HEADING_COLOUR)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_count)
	InventoryLayout.button(heading, "Leave", func() -> void: if actions != null: actions.leave())
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	column.add_child(_rows_box)
	fold = PanelFold.new(self, "Party", "party", state.settings if state != null else null,
		func(folded: bool) -> void: _root.visible = not folded)


func _process(_delta: float) -> void:
	visible = shown and state != null and content != null and state.local.is_present() and state.party.in_party()
	if not visible:
		_shape = ""
		return
	_root.offset_top = top()
	fold.place(Vector2(MARGIN + WIDTH - fold.chip.size.x - 2.0, top() + 2.0))
	var party := state.party
	var others := party.others(state.local.id)
	var shape := shape_key(party, others)
	if shape != _shape:
		_shape = shape
		_rebuild(others)
	for i in others.size():
		_rows[i].patch(others[i], party, content, state.tiles.realm_id)


## How much of the column this takes: the chip alone, folded.
func height() -> float:
	return PanelFold.CHIP_HEIGHT if fold.folded else _root.size.y


## Where the row of Bag, Menu and Chat ends; the column starts under it.
var buttons_bottom: Callable = func() -> float: return 0.0


## Where the left column starts: under the buttons, or under the diagnostics.
func top() -> float:
	var under := hud.bottom() if hud != null else 0.0
	var buttons: float = buttons_bottom.call()
	return maxf(under + MARGIN if under > 0.0 else float(TOP), buttons + MARGIN if buttons > 0.0 else 0.0)


## The web client's key: everything that changes which rows exist and
## what is drawn on them, and none of the values that move every update.
static func shape_key(party: PartyState, others: Array) -> String:
	var bits: Array = [str(party.party_id), "ldr:%d" % party.leader_id]
	for m in others:
		bits.append("%d:%d:%s:%s:%d" % [int(m.get("playerId", 0)), int(m.get("classId", 0)),
			str(m.get("hotbarBindings", [])), str(m.get("hotbarInvested", [])), int(m.get("realmId", 0))])
	return "|".join(bits)


func _rebuild(others: Array) -> void:
	for row in _rows:
		row.queue_free()
	_rows = []
	var party := state.party
	_count.text = "Party %d/%d" % [party.members.size(), PartyState.MAX_SIZE]
	var leader := party.is_leader(state.local.id)
	for member in others:
		var row := PartyRow.new(func(name: String) -> void: if actions != null: actions.kick(name))
		row.show_member(member, content, int(member.get("playerId", 0)) == party.leader_id, leader)
		_rows_box.add_child(row)
		_rows.append(row)


func captures_mouse() -> bool:
	return fold.under_mouse() or visible and _root.visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
