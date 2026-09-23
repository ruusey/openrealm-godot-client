class_name LoadingScreen
extends CanvasLayer

## Covers everything until the content and every sprite sheet it names are
## in: the one place the game waits for its assets.
##
## On the desktop the content is read off disk before the first frame, so
## this never shows. In a browser the sheets are fetched one request at a
## time while the login screen is already built underneath, and anything
## that drew before they landed asked the cache for a sheet it did not
## have yet -- which is recorded as a content warning. So the wait is
## shown, with the count, and nothing under it draws stone until it lifts.

## The engine's boot splash is set to this same colour, with a picture of
## this screen, so the boot flows into the load with no visible seam.
const BACKGROUND := Color(0.02, 0.02, 0.04)

var game_data: GameData

var _dim: ColorRect
var _title: Label
var _progress: Label


func setup(content: GameData) -> void:
	game_data = content


func _ready() -> void:
	# Over the login screen (20) and under nothing.
	layer = 25
	_dim = ColorRect.new()
	_dim.color = BACKGROUND
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_dim.add_child(column)
	_title = _line(column, "Loading OpenRealm", 24)
	_progress = _line(column, "", 14)
	_progress.modulate = Color(0.7, 0.7, 0.75)
	_refresh()


func _line(into: Container, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	into.add_child(label)
	return label


## Once the content is in there is nothing more to wait for, so it stops
## asking every frame.
func _process(_delta: float) -> void:
	_refresh()
	if game_data != null and game_data.ready:
		set_process(false)


func _refresh() -> void:
	visible = game_data != null and not game_data.ready
	if visible:
		_progress.text = caption(game_data.sprites.sheet_count(), game_data.library.sheet_keys().size())


## "content ..." until the tables are in, then the sheets as they land.
static func caption(loaded: int, total: int) -> String:
	if total <= 0:
		return "content ..."
	return "sprites %d / %d" % [loaded, total]
