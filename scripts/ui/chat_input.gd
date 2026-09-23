class_name ChatInput
extends LineEdit

## The line the player types into, shown only while they are typing.
##
## The web client's gestures: Enter sends what is there and closes, Enter on
## an empty line just closes, Escape discards and closes, and losing focus
## -- a click on the world -- closes too. While it is open every polled key
## belongs to it; Screens.captures_keyboard is how the input tickers know.

signal sent(text: String)

const PLACEHOLDER := "say something -- Enter sends, Esc closes"


func _ready() -> void:
	visible = false
	placeholder_text = PLACEHOLDER
	text_submitted.connect(_on_submitted)
	gui_input.connect(_on_gui_input)
	focus_exited.connect(close)


func open() -> void:
	visible = true
	grab_focus()


## Hiding releases focus, which calls back in here; the guard makes that a
## no-op rather than a loop.
func close() -> void:
	if not visible:
		return
	text = ""
	visible = false


func is_open() -> bool:
	return visible


func _on_submitted(line: String) -> void:
	if line.strip_edges() != "":
		sent.emit(line)
	close()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		accept_event()
		close()
