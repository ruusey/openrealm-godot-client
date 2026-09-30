class_name ForgePixelGrid
extends Control

## The forge's pixel picker: the target item's sprite blown up to a clickable
## grid. Click an opaque, unpainted pixel to choose where the crystal or gem
## mounts -- the same choice the web and native clients offer. Already-painted
## pixels show in their colour, ringed, and can't be re-picked; the pick is
## emitted so the bench remembers it for the enchant. Purely visual guidance:
## the server still validates the pixel on ForgeEnchant.

signal picked(pixel: Vector2i)

const CANVAS := 176.0
const GRID := Color(1, 1, 1, 0.10)
const PAINTED_RING := Color(1.0, 0.85, 0.42, 0.7)
const SELECT_RING := Color(1.0, 0.96, 0.5, 1.0)
const HOVER := Color(1, 1, 1, 0.20)

var _content: GameData
var _image: Image
var _region := Rect2i()
var _painted := {}   # Vector2i -> Color
var _selected := Vector2i(-1, -1)
var _hover := Vector2i(-1, -1)


func _init() -> void:
	custom_minimum_size = Vector2(CANVAS, CANVAS)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(content: GameData) -> void:
	_content = content


## Loads a target item's sprite as the pickable canvas and its existing mounts as
## the locked, coloured pixels. Clears any prior selection.
func show_item(item: Dictionary) -> void:
	_selected = Vector2i(-1, -1)
	_hover = Vector2i(-1, -1)
	_image = null
	_region = Rect2i()
	_painted = {}
	if _content != null and Inventory.holds(item):
		var texture := _content.item_texture(int(item.get("itemId", -1)))
		if texture is AtlasTexture:
			var sheet: Texture2D = texture.atlas
			_image = sheet.get_image() if sheet != null else null
			_region = Rect2i(texture.region)
		elif texture != null:
			_image = texture.get_image()
			_region = Rect2i(Vector2i.ZERO, _image.get_size()) if _image != null else Rect2i()
		for mark in ItemArt.marks(item):
			_painted[mark[0]] = mark[1]
	queue_redraw()


func selected() -> Vector2i:
	return _selected


func _draw() -> void:
	if _image == null or _region.size.x <= 0:
		return
	var sw := _region.size.x
	var sh := _region.size.y
	var cw := CANVAS / float(sw)
	var ch := CANVAS / float(sh)
	for y in sh:
		for x in sw:
			var rect := Rect2(x * cw, y * ch, cw, ch)
			var src := _image.get_pixel(_region.position.x + x, _region.position.y + y)
			if src.a > 0.0:
				draw_rect(rect, src)
			var at := Vector2i(x, y)
			if _painted.has(at):
				draw_rect(rect, _painted[at])
				draw_rect(rect, PAINTED_RING, false, 2.0)
	if _valid(_hover):
		draw_rect(Rect2(_hover.x * cw, _hover.y * ch, cw, ch), HOVER)
	if _selected.x >= 0:
		draw_rect(Rect2(_selected.x * cw, _selected.y * ch, cw, ch), SELECT_RING, false, 2.0)
	for gx in sw + 1:
		draw_line(Vector2(gx * cw, 0), Vector2(gx * cw, ch * sh), GRID, 1.0)
	for gy in sh + 1:
		draw_line(Vector2(0, gy * ch), Vector2(cw * sw, gy * ch), GRID, 1.0)


func _gui_input(event: InputEvent) -> void:
	if _image == null or _region.size.x <= 0:
		return
	if event is InputEventMouseMotion:
		var at := _pixel_at(event.position)
		if at != _hover:
			_hover = at
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _pixel_at(event.position)
		if _valid(at):
			_selected = at
			picked.emit(at)
			queue_redraw()


func _pixel_at(pos: Vector2) -> Vector2i:
	var sw := _region.size.x
	var sh := _region.size.y
	if sw <= 0 or sh <= 0:
		return Vector2i(-1, -1)
	var at := Vector2i(int(pos.x / (CANVAS / float(sw))), int(pos.y / (CANVAS / float(sh))))
	if at.x < 0 or at.x >= sw or at.y < 0 or at.y >= sh:
		return Vector2i(-1, -1)
	return at


## A pixel is pickable if it's on the sprite, still opaque, and not already spoken for.
func _valid(at: Vector2i) -> bool:
	if at.x < 0 or _painted.has(at):
		return false
	return _image.get_pixel(_region.position.x + at.x, _region.position.y + at.y).a > 0.0
