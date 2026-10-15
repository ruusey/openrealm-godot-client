class_name ChatPanel
extends CanvasLayer

## The chat log the server and other players produce.
##
## Shows a compact tail by default (the last few lines, sitting on the bottom
## margin), and EXPANDS into a scrollback of the whole 50-line ring when the
## mouse is over it or the input line is open. The ring itself lives in ChatLog
## (newest in, oldest out, capped at 50); this panel only renders it.
##
## Enter opens a line to type into, under the log; while it is open the panel
## captures the keyboard, and Screens tells every polled input so -- without the
## gate, typing walks the player and fires.
##
## One row per line (ChatRow) rather than one label for all of them: a SYSTEM
## line and a player line are different colours, and a long line wraps.

## Tail height (rows) when collapsed, and the viewport height when expanded. The
## expanded viewport is also capped to a fraction of the screen so it never runs
## off the top on a short (phone) display.
const COMPACT_LINES := 6
const EXPANDED_LINES := 14
const ROW_HEIGHT := 18
const EXPANDED_SCREEN_FRACTION := 0.45
const FONT_SIZE := 12
const MARGIN := 12
const WIDTH := 420
const INPUT_ROW := 28

var state: RealmState
var actions: ChatActions

var _box: VBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array = []
var _input: ChatInput
var _shown := -1
var _hovering := false
## Stick to the newest line unless the user has scrolled up in the expanded view.
var _follow := true
## The chip that folds the log to its name; the input line stays.
var fold: PanelFold


func setup(realm_state: RealmState, chat_actions: ChatActions = null) -> void:
	state = realm_state
	actions = chat_actions


func _ready() -> void:
	# Over the world and the debug overlay, under the transition cover.
	layer = 12
	_box = VBoxContainer.new()
	# Pinned by its bottom edge, growing upward: the log sits on the margin and
	# the input row, when shown, lifts it by its own height.
	_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = MARGIN
	_box.offset_right = WIDTH
	_box.offset_top = -MARGIN
	_box.offset_bottom = -MARGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	# The scrollback. Vertical-only; its height is driven each frame (compact vs
	# expanded). mouse_filter is flipped in _process: PASS while collapsed so a
	# click on the tail still reaches the world, STOP while expanded so the wheel/
	# drag scrolls the log instead of acting on the world underneath.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.custom_minimum_size = Vector2(WIDTH - MARGIN, COMPACT_LINES * ROW_HEIGHT)
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.mouse_entered.connect(func() -> void: _hovering = true)
	_scroll.mouse_exited.connect(func() -> void: _hovering = false)
	_box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)

	_input = ChatInput.new()
	_input.add_theme_font_size_override("font_size", FONT_SIZE)
	_input.custom_minimum_size.y = INPUT_ROW
	_input.sent.connect(_on_sent)
	_box.add_child(_input)

	fold = PanelFold.new(self, "Chat", "chat", state.settings if state != null else null,
		func(folded: bool) -> void: _scroll.visible = not folded)
	# Never hidden as a layer (the sign-in screen just covers it), so the chip
	# hides itself until there is a player to have a chat.
	fold.chip.visible = false


## The chat line, opened as Enter opens it: the phone's Chat button.
func open_line() -> void:
	if not _input.is_open():
		_input.open()


func captures_mouse() -> bool:
	return _is_expanded() or fold.under_mouse()


func is_typing() -> bool:
	return _input.is_open()


## Expanded while the mouse is over the log or the input line is open. Collapsing
## back to the tail the instant the mouse leaves is deliberate: the log is an
## overlay on the world, not a window to park open.
func _is_expanded() -> bool:
	return _hovering or _input.is_open()


## Enter opens the line; a click anywhere it is not closes it.
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
	fold.chip.visible = state != null and state.local.is_present()
	fold.place(Vector2(MARGIN, _box.get_global_rect().position.y - PanelFold.CHIP_HEIGHT - 2.0))
	if state == null:
		blank()
		return

	var expanded := _is_expanded()
	# Height: compact tail, or expanded viewport capped to a slice of the screen.
	var want_h := float(COMPACT_LINES * ROW_HEIGHT)
	if expanded:
		var cap := get_viewport().get_visible_rect().size.y * EXPANDED_SCREEN_FRACTION
		want_h = minf(EXPANDED_LINES * ROW_HEIGHT, cap)
	if not is_equal_approx(_scroll.custom_minimum_size.y, want_h):
		_scroll.custom_minimum_size.y = want_h
	# Capture scroll only when expanded; otherwise let clicks fall through to the world.
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_PASS

	# Follow the newest line unless the user has scrolled up in the expanded view.
	# Collapsed always follows -- the tail shows the newest.
	var bar := _scroll.get_v_scroll_bar()
	if not expanded:
		_follow = true
	elif bar != null:
		_follow = bar.value >= bar.max_value - bar.page - 1.0

	# Rebuild only when something was said -- watches the ring's revision, not its
	# size (size saturates at 50 once full, so newer lines would stop redrawing).
	if state.chat.revision != _shown:
		_shown = state.chat.revision
		refresh()
	elif _follow:
		_stick_bottom()


## Nothing to show without a log. Blanking rather than returning keeps the guard
## testable (an exception leaves the rows as-is and GUT scores that as passing).
func blank() -> void:
	for row in _rows:
		row.blank()
	_shown = -1


## Renders the whole ring (not just the tail) into the scrollback; the viewport
## height is what decides how many are visible at once. Splits out so a test can
## drive it without waiting for a frame.
func refresh() -> void:
	var lines: Array = state.chat.lines
	while _rows.size() < lines.size():
		# Wrapped rather than run off the edge: a long line is the normal case.
		var row := ChatRow.new(WIDTH - MARGIN)
		_list.add_child(row)
		_rows.append(row)
	for i in _rows.size():
		var row: ChatRow = _rows[i]
		if i < lines.size() and not fold.folded:
			row.show_line(lines[i])
		else:
			row.blank()
	if _follow:
		_stick_bottom()


## Pin to the newest line. Deferred so the row layout has settled first; the
## ScrollContainer clamps an over-large value to its real maximum.
func _stick_bottom() -> void:
	_scroll.set_deferred("scroll_vertical", 1_000_000)
