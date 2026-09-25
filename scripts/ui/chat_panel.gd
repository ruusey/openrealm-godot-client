class_name ChatPanel
extends CanvasLayer

## The last few lines the server and the other players have said.
##
## Enter opens a line to type into, under the log; while it is open the
## panel captures the keyboard, and Screens tells every polled input so --
## the web client gates movement, shooting and its portal keys on the same
## `chatMode`, because without the gate typing walks the player.
##
## One row per line (ChatRow) rather than one label for all of them, because
## a SYSTEM line and a player line are different colours, and a player's name
## is coloured by their chat role within the line.

## The native client shows three lines collapsed; the web client scrolls a
## panel. Six is a compromise that fits the capture resolution.
const VISIBLE_LINES := 6
const FONT_SIZE := 12
const MARGIN := 12
const WIDTH := 420
const INPUT_ROW := 28

var state: RealmState
var actions: ChatActions

var _box: VBoxContainer
var _labels: Array = []
var _input: ChatInput
var _shown := 0
## The chip that folds the log to its name; the input line stays.
var fold: PanelFold


func setup(realm_state: RealmState, chat_actions: ChatActions = null) -> void:
	state = realm_state
	actions = chat_actions


func _ready() -> void:
	# Over the world and the debug overlay, under the transition cover: a
	# realm change is not the moment to read chat.
	layer = 12
	_box = VBoxContainer.new()
	# Pinned by its bottom edge and sized by what is in it, growing upward:
	# the lines sit on the margin, and the input row, when it shows, takes
	# the bottom and lifts them by exactly its own height. A fixed height
	# here was wrong twice over -- the rows are taller than the font size
	# says, and a row that did not fit was pushed off the bottom of the
	# window rather than shown.
	_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = MARGIN
	_box.offset_right = WIDTH
	_box.offset_top = -MARGIN
	_box.offset_bottom = -MARGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	for i in VISIBLE_LINES:
		# Wrapped rather than left to run off the edge: a long line is the
		# normal case, not the exception.
		var row := ChatRow.new(WIDTH - MARGIN)
		_box.add_child(row)
		_labels.append(row)

	_input = ChatInput.new()
	_input.add_theme_font_size_override("font_size", FONT_SIZE)
	_input.custom_minimum_size.y = INPUT_ROW
	_input.sent.connect(_on_sent)
	_box.add_child(_input)
	fold = PanelFold.new(self, "Chat", "chat", state.settings if state != null else null,
		func(folded: bool) -> void: for row in _labels: row.visible = not folded)
	# This layer is never hidden -- the sign-in screen simply covers it --
	# so the chip, unlike the map's or the stats', hides itself until there
	# is a player to have a chat.
	fold.chip.visible = false


## The chat line, opened as Enter opens it: the phone's Chat button.
func open_line() -> void:
	if not _input.is_open():
		_input.open()


func captures_mouse() -> bool:
	return fold.under_mouse()


func is_typing() -> bool:
	return _input.is_open()


## Enter opens the line; a click anywhere it is not closes it. Both reach
## here only when no control took them, which is what a click on the world
## is -- a click on the line itself never gets this far.
func _unhandled_input(event: InputEvent) -> void:
	if state == null or not state.local.is_present():
		return
	if event is InputEventMouseButton and event.pressed and _input.is_open():
		_input.close()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) \
			and not _input.is_open():
		_input.open()
		get_viewport().set_input_as_handled()


func _on_sent(text: String) -> void:
	if actions != null:
		actions.say(text)


func _process(_delta: float) -> void:
	# Just over the lines, which sit on the bottom margin and grow upward.
	fold.chip.visible = state != null and state.local.is_present()
	fold.place(Vector2(MARGIN, _box.get_global_rect().position.y - PanelFold.CHIP_HEIGHT - 2.0))
	if state == null:
		blank()
		return
	# Rebuilt only when something was actually said.
	if state.chat.lines.size() == _shown:
		return
	_shown = state.chat.lines.size()
	refresh()


## Nothing to show without a log. Blanking rather than returning quietly is
## what makes the guard testable: an exception from a missing one leaves the
## rows exactly as they were, and GUT counts a test that errored as passing.
func blank() -> void:
	for row in _labels:
		row.blank()
	# Reset too, or a panel that is handed a log with the same number of lines
	# it blanked at never redraws them.
	_shown = 0


## Splits out so a test can drive it without waiting for a frame.
func refresh() -> void:
	var tail: Array = state.chat.last(VISIBLE_LINES)
	for i in _labels.size():
		var row: ChatRow = _labels[i]
		if i >= tail.size():
			row.blank()
		else:
			row.show_line(tail[i])
			# A line shows its row; folded, the fold has the last word.
			row.visible = not fold.folded
