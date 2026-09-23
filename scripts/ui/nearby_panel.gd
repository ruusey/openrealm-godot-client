class_name NearbyPanel
extends CanvasLayer

## Who else is in view: the web client's nearby-players list, in Godot's
## own controls, on the left under the party panel.
##
## A row per player -- the class's idle frame and the name in its chat
## role's colour, bold for an admin -- with the web's tooltip on hover
## (NearbyPlayers.tooltip) and, on a click, the PlayerMenu beside it:
## trade, teleport, invite to party, each the command the chat could send.
## Rows are rebuilt when who is listed changes, which the web checks every
## half second; the list itself is the roster, so nothing polls the
## server. Sits under the party panel and moves down when that one shows.

const MARGIN := PartyPanel.MARGIN
const WIDTH := PartyPanel.WIDTH
const GAP := 8
const EMPTY_COLOUR := Color("665848")
const ICON := 24

var state: RealmState
var content: GameData
var trade: TradeActions
var party: PartyActions
var chat: ChatActions
## The panel above, whose height decides where this one starts.
var above: PartyPanel
## Off for a scripted render that is about something else.
var shown := true
var menu: PlayerMenu

var _root: PanelContainer
var _rows_box: VBoxContainer
var _empty: Label
var _listed := ""


func setup(realm_state: RealmState, game_data: GameData, trade_actions: TradeActions,
		party_actions: PartyActions, chat_actions: ChatActions, party_panel: PartyPanel = null) -> void:
	state = realm_state
	content = game_data
	trade = trade_actions
	party = party_actions
	chat = chat_actions
	above = party_panel


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.offset_left = MARGIN
	_root.offset_right = MARGIN + WIDTH
	_root.offset_top = PartyPanel.TOP
	add_child(_root)
	var column := InventoryLayout.column(_root)
	InventoryLayout.heading(column, "Nearby")
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	column.add_child(_rows_box)
	_empty = HudWidgets.label("No players nearby", 10, EMPTY_COLOUR)
	column.add_child(_empty)
	menu = PlayerMenu.new(
		func(name: String) -> bool: return trade != null and trade.request(name),
		func(name: String) -> bool: return chat != null and chat.say("/tp %s" % name),
		func(name: String) -> bool: return party != null and party.invite(name))
	add_child(menu)


func _process(_delta: float) -> void:
	visible = shown and state != null and content != null and state.local.is_present()
	if not visible:
		menu.close()
		_listed = ""
		return
	var top := above.top() if above != null else float(PartyPanel.TOP)
	_root.offset_top = top + (above._root.size.y + GAP if above != null and above.visible else 0.0)
	var players := NearbyPlayers.list(state.entities, state.local.id, state.party.member_ids())
	var listed := ",".join(players.map(func(p: Dictionary) -> String:
		return "%d:%s:%d:%s" % [int(p["id"]), p.get("name", ""), int(p.get("class_id", 0)), p.get("chat_role", "")]))
	if listed != _listed:
		_listed = listed
		_rebuild(players)
	if menu.visible and not players.any(func(p: Dictionary) -> bool: return p.get("name", "") == menu.player_name):
		menu.close()


func _rebuild(players: Array) -> void:
	for row in _rows_box.get_children():
		row.queue_free()
	_empty.visible = players.is_empty()
	for player in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = NearbyPlayers.tooltip(player, content)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = content.classes_art.frame(int(player.get("class_id", 0)), "idle", "front", 0,
			int(player.get("dye_id", 0)))
		row.add_child(icon)
		var role := String(player.get("chat_role", ""))
		var name := HudWidgets.label(String(player.get("name", "")).left(14), 12, NearbyPlayers.role_colour(role))
		if NearbyPlayers.bold(role):
			name.add_theme_font_override("font", TagStyles.bold())
		row.add_child(name)
		row.gui_input.connect(_on_row_input.bind(player))
		_rows_box.add_child(row)


## A click on a row opens the menu beside it; a click on the panel's
## background, on nothing, closes it.
func _on_row_input(event: InputEvent, player: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_menu(player)


func open_menu(player: Dictionary) -> void:
	var name := String(player.get("name", ""))
	menu.open_for(name, NearbyPlayers.role_colour(String(player.get("chat_role", ""))),
		Vector2(_root.offset_right + GAP, _root.offset_top))


func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event is InputEventMouseButton and event.pressed \
			and not menu.get_global_rect().has_point(event.position):
		menu.close()


## Whether a point on the screen is on the list or on its open menu.
func owns(point: Vector2) -> bool:
	return _root.get_global_rect().has_point(point) or (menu.visible and menu.get_global_rect().has_point(point))


func captures_mouse() -> bool:
	return visible and owns(_root.get_global_mouse_position())
