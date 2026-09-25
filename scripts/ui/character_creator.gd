class_name CharacterCreator
extends VBoxContainer

## The class grid both references put under the character list: pick a
## class, press a button, and the data service adds a fresh character.
##
## The native client's "CREATE CHARACTER" block is four columns of class
## options, each a 32px idle frame beside the class name, with the button
## dead until one is picked; the web client's is the same grid with a 28px
## canvas. Both send one request -- POST .../character?classId=N -- and
## refill the list from the account that comes back. Both then leave the
## player to find the new character in the list and pick it, which is the
## step "Create & play" skips: it is the prominent button, and the plain
## "Create" beside it is for making one without entering the realm. Here
## the grid is three columns, beside the list rather than under it, each
## option a thumb's height (TouchSize).
##
## The roster is the shipped character-classes.json in classId order, so a
## new class shows up on its own.

signal created(characters: Array, play: bool)
signal failed(reason: String)

const COLUMNS := 3
const ICON_PX := 32
const HEADING := Color(0.78, 0.66, 0.43)

var data_service: DataService
var game_data: GameData

var grid: GridContainer
var play_button: Button
var create_button: Button
var options := {}   # class_id -> Button

var _group := ButtonGroup.new()
var _busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "Create character"
	heading.add_theme_color_override("font_color", HEADING)
	heading.add_theme_font_size_override("font_size", TouchSize.FONT)
	add_child(heading)

	grid = GridContainer.new()
	grid.columns = COLUMNS
	add_child(grid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	play_button = Button.new()
	play_button.text = "Create & play"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(func() -> void: _create(true))
	row.add_child(TouchSize.grow(play_button, 20))
	create_button = Button.new()
	create_button.text = "Create"
	create_button.pressed.connect(func() -> void: _create(false))
	row.add_child(TouchSize.grow(create_button))
	fill()


## Rebuilds the grid from the content. Called again each time the screen is
## shown, because over HTTP the content arrives after the screen is built.
func fill() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	options.clear()
	if game_data != null:
		var ids := game_data.library.classes.keys()
		ids.sort()
		for class_id in ids:
			options[class_id] = _add_option(class_id)
	_refresh()


func _add_option(class_id: int) -> Button:
	var option := Button.new()
	option.toggle_mode = true
	option.button_group = _group
	option.text = game_data.classes_art.display_name(class_id)
	option.icon = icon_for(game_data.classes_art.frame(class_id, "idle", "front", 0))
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.toggled.connect(func(_on: bool) -> void: _refresh())
	grid.add_child(TouchSize.grow(option, 16))
	return option


## The 8px frame blown up to icon size, as the web client draws it into its
## 28px canvas. Not Button.expand_icon: that scales the icon to whatever
## width the text leaves over, and for the longest name in a column -- the
## one that set the column's width -- that is nothing, so the Barbarian
## drew as a dot and the Necromancer not at all.
static func icon_for(frame: Texture2D) -> Texture2D:
	if frame == null:
		return null
	var image: Image = frame.atlas.get_image().get_region(Rect2i(frame.region)) \
		if frame is AtlasTexture else frame.get_image()
	image.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


## The picked class, or -1.
func selected_class_id() -> int:
	for class_id in options:
		if options[class_id].button_pressed:
			return class_id
	return -1


func _refresh() -> void:
	var dead := _busy or selected_class_id() < 0
	play_button.disabled = dead
	create_button.disabled = dead
	play_button.text = "Creating ..." if _busy else "Create & play"


func _create(play: bool) -> void:
	var class_id := selected_class_id()
	if class_id < 0 or _busy:
		return
	_busy = true
	_refresh()
	var result: Dictionary = await data_service.create_character(class_id)
	_busy = false
	if result["success"]:
		# The native client drops the pick once it has been made, so a second
		# press cannot make another by accident. A failure keeps it, as both
		# references do, for a retry.
		options[class_id].button_pressed = false
		created.emit(result["result"], play)
	else:
		failed.emit(str(result["result"]))
	_refresh()
