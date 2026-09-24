class_name ScaleRow
extends VBoxContainer

## "UI scale" and "World zoom" in the options, one row each: a slider a
## quarter at a time, what the screen is drawn at now beside the heading --
## "1.75x (auto)" until the player chooses, "2.25x" after -- and Auto to
## hand it back to DisplayScale. The two are independent: the UI scale is
## the canvas's, and the camera cancels it so the world keeps its own.
## The slider's number shows as it moves and applies when it is let go:
## applied while dragged, the options would resize under the finger and
## the slider with them.

const UI := "ui_scale"
const WORLD := "world_zoom"
const STEP := 0.25
## Setting -> [heading, least, most]. The world stops at 1x: below it a
## phone's screen shows more ground than the server streams around you.
const KINDS := {UI: ["UI scale", 1.0, 3.0], WORLD: ["World zoom", 1.0, 4.0]}

var settings: GameSettings
var setting := UI
## What the screen is drawn at now, off the window and its camera.
var current: Callable = func() -> float:
	if not is_inside_tree():
		return 1.0
	return DisplayScale.world_now(get_viewport()) if setting == WORLD else get_window().content_scale_factor

var slider: HSlider
var value_label: Label
var auto_button: Button
var _dragging := false


func _init(game_settings: GameSettings, which := UI) -> void:
	settings = game_settings
	setting = which
	var heading := HBoxContainer.new()
	add_child(heading)
	var name := HudWidgets.label(KINDS[setting][0], 13, Color(0.85, 0.85, 0.85))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	value_label = HudWidgets.label("", 13, OptionsPanel.HEADING)
	heading.add_child(value_label)
	var row := HBoxContainer.new()
	add_child(row)
	slider = HSlider.new()
	slider.min_value = KINDS[setting][1]
	slider.max_value = KINDS[setting][2]
	slider.step = STEP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The default track is a dark hairline on a dark panel: give it a body.
	slider.add_theme_stylebox_override("slider", _track(Color(0.3, 0.28, 0.36)))
	slider.add_theme_stylebox_override("grabber_area", _track(OptionsPanel.HEADING.darkened(0.3)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _track(OptionsPanel.HEADING))
	slider.value_changed.connect(_on_moved)
	slider.drag_started.connect(func() -> void: _dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		choose(slider.value))
	row.add_child(slider)
	auto_button = InventoryLayout.button(row, "Auto", func() -> void: choose(0.0))
	# Right whenever it is seen, however the options were opened.
	visibility_changed.connect(func() -> void: if is_visible_in_tree(): refresh())


func _ready() -> void:
	refresh()


## A scale, or 0 for automatic; kept, and applied by whoever listens.
func choose(scale: float) -> void:
	if settings != null:
		settings.set_scale(setting, scale)
	refresh.call_deferred()


## The slider and the number to what the screen is drawn at now.
func refresh() -> void:
	var now: float = current.call()
	slider.set_value_no_signal(clampf(now, slider.min_value, slider.max_value))
	var auto := settings == null or settings.scale_of(setting) <= 0.0
	value_label.text = "%sx%s" % [DisplayScale.label(now), " (auto)" if auto else ""]
	auto_button.disabled = auto


func _on_moved(value: float) -> void:
	value_label.text = "%sx" % DisplayScale.label(value)
	# A click or a key moves it with no drag to end: apply at once.
	if not _dragging:
		choose(value)


static func _track(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(3)
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	return box
