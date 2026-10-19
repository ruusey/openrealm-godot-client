class_name DeathScreen
extends CanvasLayer

## What the server says when a character is gone for good.
##
## Death here is permanent: by the time this packet arrives the server has
## already deleted the character against the data service, so there is nothing
## to return to except the character picker. Both references say as much on
## the screen -- "your character has been lost" -- rather than offering a
## respawn that does not exist. Select Character goes back to the account's
## characters; Quit, as the web client's does, goes back to signing in.

signal dismissed
signal quit

const TITLE := "GAME OVER"


var _panel: ColorRect
var _title: Label
var _detail: Label
var _button: Button
var _quit: Button


func _ready() -> void:
	# Above the transition cover: dying during a realm change is reachable,
	# and the cover must not be what the player is left looking at.
	layer = 18
	visible = false

	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.0, 0.02, 0.94)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(column)

	_title = _line(column, TITLE, 34, Color(0.9, 0.2, 0.2))
	_detail = _line(column, "", 16, Color(0.85, 0.8, 0.8))
	_line(column, "Your character has been lost to the realm.", 13,
		Color(0.6, 0.55, 0.55))

	_button = Button.new()
	_button.text = "Select character"
	_button.custom_minimum_size = Vector2(160, 0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_pressed)
	column.add_child(_button)

	_quit = Button.new()
	_quit.text = "Quit"
	_quit.flat = true
	_quit.custom_minimum_size = Vector2(160, 0)
	_quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit.pressed.connect(func() -> void:
		visible = false
		quit.emit())
	column.add_child(_quit)


## Shows the screen for a named character.
func fell(player_name: String) -> void:
	_detail.text = "%s has fallen." % (player_name if player_name != "" else "Your character")
	visible = true


func _on_pressed() -> void:
	visible = false
	dismissed.emit()


func _line(column: VBoxContainer, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	column.add_child(label)
	return label
