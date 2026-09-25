class_name PanelFold
extends RefCounted

## A chip that folds a panel down to its name and opens it again.
##
## The always-on panels -- the map, the stats, the chat, the nearby and
## party lists -- were laid out for 720 rows and eat a phone's 400. Each
## takes one of these: a small button at its corner reading "- Map" open
## and "+ Map" folded, a tap either way. What folding hides is the panel's
## to say (`apply`), since the chat keeps its input line and the stats
## keep their bars. The choice is kept in the settings file under the
## panel's key; with none kept, a short screen starts folded and a tall
## one open. Short is under SHORT_PX rows of the screen's own -- CSS px
## on the web, the window's pixels on a desktop -- which Main works out
## once (`short_screen`): the canvas's rows say nothing, since on the web
## the scale is chosen to give it 720 whatever the phone.
##
## The chip is the panel's to place, from its own _process, because the
## panels move: the party list sits under the diagnostics, the nearby
## list under the party. A RefCounted, not a node: nothing here may run
## under a hidden layer.

const SHORT_PX := 500.0
const CHIP_HEIGHT := 22.0
const FONT_SIZE := 12

## Whether panels start folded, absent a kept choice; set by Main.
static var short_screen := false

var key: String
var label: String
var folded := false
var chip: Button

var _settings: GameSettings
var _apply: Callable


func _init(layer: CanvasLayer, name: String, settings_key: String, settings: GameSettings,
		apply: Callable) -> void:
	label = name
	key = settings_key
	_settings = settings if settings != null else GameSettings.new()
	_apply = apply
	chip = Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", FONT_SIZE)
	chip.custom_minimum_size.y = CHIP_HEIGHT
	chip.pressed.connect(toggle)
	layer.add_child(chip)
	folded = _settings.panel_folded(key, short_screen)
	_show()


## Under SHORT_PX rows of the screen's own there is no room for everything open.
static func default_folded(screen_rows: float) -> bool:
	return screen_rows > 0.0 and screen_rows < SHORT_PX


func toggle() -> void:
	set_folded(not folded)


func set_folded(on: bool) -> void:
	folded = on
	_settings.set_panel_folded(key, on)
	_show()


## The chip's top-left corner, on whole pixels.
func place(top_left: Vector2) -> void:
	chip.position = top_left.round()


## The chip's top-right corner, for a panel on the right edge.
func place_right(top: float, right: float) -> void:
	place(Vector2(right - chip.size.x, top))


## Whether the mouse is on the chip: a click there is a fold, not a shot.
func under_mouse() -> bool:
	return chip.is_visible_in_tree() and chip.get_global_rect().has_point(chip.get_global_mouse_position())


func _show() -> void:
	chip.text = ("+ " if folded else "- ") + label
	_apply.call(folded)
