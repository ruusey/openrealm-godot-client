class_name DyedSprites
extends RefCounted

## A character's dye: the web client's getDyedRegion.
##
## A class's frames carry a mask, painted in the editor
## (character-class-masks.json), of which pixels are cloth; a dye
## (dye-assets.json) recolours those and leaves the rest. A solid dye keeps
## each pixel's shading: its luminance over 128 scales the dye's colour, so
## a dark fold stays dark and a highlight stays light. The mask covers the
## body cell only, so the weapon overhanging a wide attack frame keeps its
## own colours, as in the web. Every other dye type -- the web's `sprite`
## cloths, which no shipped dye uses -- and any frame without a mask draw
## undyed. Each dyed frame is made once and kept.

var _library: ContentLibrary
var _masks := {}     # "class:row:col" -> mask rows
var _indexed := false
var _sheets := {}    # sheet texture -> its Image, read back once
var _made := {}      # "class:row:col:size:dye" -> Texture2D


func _init(library: ContentLibrary) -> void:
	_library = library


## `frame` in `dye_id`, or `frame` itself when there is nothing to dye.
func apply(frame: AtlasTexture, class_id: int, row: int, col: int, dye_id: int) -> Texture2D:
	if frame == null or dye_id <= 0:
		return frame
	var dye: Dictionary = _library.dyes.get(dye_id, {})
	if String(dye.get("type", "")) != "solid":
		return frame
	var mask := mask_of(class_id, row, col)
	if mask.is_empty():
		return frame
	var key := "%d:%d:%d:%s:%d" % [class_id, row, col, frame.region.size, dye_id]
	if not _made.has(key):
		_made[key] = _dyed(frame, mask, int(dye.get("color", 0)))
	return _made[key]


## The painted mask for one cell of a class's sheet; empty when none.
func mask_of(class_id: int, row: int, col: int) -> Array:
	if not _indexed:
		_indexed = true
		for entry in _library.class_masks.values():
			for cell in entry.get("frames", []):
				_masks["%d:%d:%d" % [int(entry.get("classId", -1)), int(cell.get("row", -1)),
					int(cell.get("col", -1))]] = cell.get("mask", [])
	return _masks.get("%d:%d:%d" % [class_id, row, col], [])


## The web's solid dye over `image`, in place.
static func recolour(image: Image, mask: Array, colour: int) -> void:
	var dye := Vector3((colour >> 16) & 0xff, (colour >> 8) & 0xff, colour & 0xff)
	for y in mini(mask.size(), image.get_height()):
		var cells: Array = mask[y]
		for x in mini(cells.size(), image.get_width()):
			var pixel := image.get_pixel(x, y)
			if int(cells[x]) == 0 or pixel.a8 == 0:
				continue
			var scale := (0.299 * pixel.r8 + 0.587 * pixel.g8 + 0.114 * pixel.b8) / 128.0
			image.set_pixel(x, y, Color8(clampi(roundi(dye.x * scale), 0, 255),
				clampi(roundi(dye.y * scale), 0, 255), clampi(roundi(dye.z * scale), 0, 255), pixel.a8))


func _dyed(frame: AtlasTexture, mask: Array, colour: int) -> Texture2D:
	var sheet := _sheet(frame.atlas)
	if sheet == null:
		return frame
	var image := sheet.get_region(Rect2i(frame.region))
	recolour(image, mask, colour)
	return ImageTexture.create_from_image(image)


func _sheet(texture: Texture2D) -> Image:
	if not _sheets.has(texture):
		var image := texture.get_image() if texture != null else null
		if image != null:
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
		_sheets[texture] = image
	return _sheets[texture]
