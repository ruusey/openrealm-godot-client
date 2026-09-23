class_name QuestLogPanel
extends CanvasLayer

## The quest log: the web client's Quests panel and its star chip.
##
## The chip ("★ N Stars") is up whenever we are in a realm, just left of the
## minimap -- the web's sits top right, where our minimap is -- and a click
## opens the log, as the toggle_quests key does (L by default, as the
## web's). The log is a card a quest (QuestCard), active first, then
## available, then complete, rebuilt only when the server's snapshot
## changes; Accept and Abandon go as the server's `/quest accept|abandon
## <id>`, the same command a chat line would send.

const HEIGHT_SHARE := 0.8

var state: RealmState
var content: GameData
var client: OpenRealmClient
var shown := false

var chip: Button
var _dialog: PanelContainer
var _stars: Label
var _cards: VBoxContainer
var _drawn := -1


func setup(realm_state: RealmState, game_data: GameData, net_client: OpenRealmClient) -> void:
	state = realm_state
	content = game_data
	client = net_client


func _ready() -> void:
	layer = 13
	visible = false
	chip = Button.new()
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.offset_right = -(MinimapPanel.MARGIN + MinimapPanel.SIDE + 8)
	chip.offset_top = 32
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.add_theme_color_override("font_color", TagStyles.STAR_GOLD)
	chip.add_theme_font_size_override("font_size", 12)
	chip.tooltip_text = "Open the quest log (L)"
	chip.pressed.connect(toggle)
	add_child(chip)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_dialog = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171f")
	style.border_color = Color("3a4152")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_dialog.add_theme_stylebox_override("panel", style)
	centre.add_child(_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_dialog.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := HudWidgets.label("QUEST LOG", 16, Color("dfe4ee"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_stars = HudWidgets.label("", 14, TagStyles.STAR_GOLD)
	head.add_child(_stars)
	InventoryLayout.button(head, "Close", close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(QuestCard.WIDTH + 16, 0)
	column.add_child(scroll)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards)


func _process(_delta: float) -> void:
	visible = state != null and state.local.is_present()
	_dialog.visible = visible and shown
	if not visible:
		return
	chip.text = "★ %d Stars" % state.progress.stars
	if _dialog.visible and state.progress.version != _drawn:
		refresh()


## Every card to the server's last snapshot.
func refresh() -> void:
	_drawn = state.progress.version
	_stars.text = "★ %d Stars" % state.progress.stars
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	var quests := state.progress.sorted_quests()
	if quests.is_empty():
		_cards.add_child(HudWidgets.label("No quests available yet.", 13, QuestCard.MUTED))
	for quest in quests:
		_cards.add_child(QuestCard.new(quest, content, act))
	var scroll := _cards.get_parent() as ScrollContainer
	scroll.custom_minimum_size.y = minf(_cards.get_combined_minimum_size().y,
		get_viewport().get_visible_rect().size.y * HEIGHT_SHARE - 60.0)


## Accept or abandon, as the server's command.
func act(verb: String, quest_id: int) -> bool:
	if client == null or not client.is_in_game():
		return false
	client.send_server_command("/quest %s %d" % [verb, quest_id])
	return true


func toggle() -> void:
	shown = not shown
	_drawn = -1


func close() -> void:
	shown = false


func captures_mouse() -> bool:
	if not visible:
		return false
	var at := chip.get_global_mouse_position()
	return chip.get_global_rect().has_point(at) or (_dialog.visible and _dialog.get_global_rect().has_point(at))


## A key the chat line or the Controls tab consumed never arrives here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.is_action_pressed("toggle_quests") and state != null and state.local.is_present():
		toggle()
