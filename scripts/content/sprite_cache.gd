class_name SpriteCache
extends RefCounted

## Slices sprite sheets into AtlasTextures and caches both.
##
## Sheets are read through a ContentSource at runtime, not imported as Godot
## resources, so the data repo stays the source of truth and needs no reimport.
## Every sheet is read up front. texture() is called from _draw, which cannot
## await, so nothing can be fetched on demand -- over HTTP the frame would be
## long gone before the bytes arrived. Both sources preload for that reason,
## which also means the desktop exercises the path the browser depends on.

const DEFAULT_SPRITE_SIZE := 8

var errors: Array[String] = []

var _textures := {}   # sprite key -> Texture2D (null when missing)
var _pending := {}    # sprite key -> true while its read is in flight
var _atlases := {}    # "key:row:col:size:width" -> AtlasTexture


## How many sheets have been read so far, missing ones included: progress.
func sheet_count() -> int:
	return _textures.size()


## Reads each sheet once, all of them at once, recording the ones that are
## not there. Called with ContentLibrary.sheet_keys() as soon as the content
## JSON has landed.
func preload_sheets(source: ContentSource, keys: Array) -> void:
	await SheetPreloader.new(self).run(source, keys)


## Whether a sheet has been read or is being read: asked for once, either way.
func holds(key: String) -> bool:
	return _textures.has(key) or _pending.has(key)


func expect(key: String) -> void:
	_pending[key] = true


func store(key: String, texture: Texture2D) -> void:
	_pending.erase(key)
	_textures[key] = texture


## Region for one cell of a sheet.
##
## `width` differs from `size` only for the double-width frames some attack
## animations use. `height` is the cell's own height and doubles as the row
## stride, because a sheet of 8x16 cells indexes rows by 16 -- that is how the
## reference clients slice it (`rect(col * cellW, row * cellH, w, h)`), and 42
## of the shipped tiles are 8x16 walls.
func atlas(sprite_key: String, row: int, col: int, size: int, width: int = -1,
		height: int = -1) -> AtlasTexture:
	if sprite_key == "" or size <= 0:
		return null
	if width <= 0:
		width = size
	if height <= 0:
		height = size

	var key := "%s:%d:%d:%d:%d:%d" % [sprite_key, row, col, size, width, height]
	if _atlases.has(key):
		return _atlases[key]

	var sheet := texture(sprite_key)
	if sheet == null:
		_atlases[key] = null
		return null

	var slice := AtlasTexture.new()
	slice.atlas = sheet
	slice.region = Rect2(col * size, row * height, width, height)
	slice.filter_clip = true
	_atlases[key] = slice
	return slice


## A cache lookup, nothing more -- see the note above on why.
func texture(sprite_key: String) -> Texture2D:
	if _textures.has(sprite_key):
		return _textures[sprite_key]
	# Content naming a sheet that sheet_keys() did not enumerate. Recorded once
	# rather than once per frame per sprite.
	errors.append("sprite sheet not preloaded: %s" % sprite_key)
	_textures[sprite_key] = null
	return null


## The upper square of a tall cell.
##
## Wall art is 8x16 -- top face above, front face below -- and the top face
## alone is what gets redrawn over the entities. The row stride stays the full
## cell height while the region is square, which is the one case the general
## call cannot express (it uses one value for both).
func top_face(sprite_key: String, row: int, col: int, size: int, cell_height: int) -> AtlasTexture:
	if sprite_key == "" or size <= 0 or cell_height <= size:
		return null

	var key := "top:%s:%d:%d:%d:%d" % [sprite_key, row, col, size, cell_height]
	if _atlases.has(key):
		return _atlases[key]

	var sheet := texture(sprite_key)
	if sheet == null:
		_atlases[key] = null
		return null

	var slice := AtlasTexture.new()
	slice.atlas = sheet
	slice.region = Rect2(col * size, row * cell_height, size, size)
	slice.filter_clip = true
	_atlases[key] = slice
	return slice


## `top_face` for the same definition shape `atlas_for` takes.
func top_face_for(definition: Dictionary, default_size := DEFAULT_SPRITE_SIZE) -> AtlasTexture:
	if definition.is_empty():
		return null
	var size := int(definition.get("spriteSize", default_size))
	if size <= 0:
		size = default_size
	return top_face(
		definition.get("spriteKey", ""),
		int(definition.get("row", 0)),
		int(definition.get("col", 0)),
		size,
		int(definition.get("spriteHeight", 0)),
	)


## Convenience for the common "definition dict with spriteKey/row/col" shape.
func atlas_for(definition: Dictionary, default_size := DEFAULT_SPRITE_SIZE) -> AtlasTexture:
	if definition.is_empty():
		return null
	var size := int(definition.get("spriteSize", default_size))
	if size <= 0:
		size = default_size
	return atlas(
		definition.get("spriteKey", ""),
		int(definition.get("row", 0)),
		int(definition.get("col", 0)),
		size,
		-1,
		int(definition.get("spriteHeight", 0)),
	)
