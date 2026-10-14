class_name TileFeather
extends RefCounted

## Seam blending where two terrain types meet.
##
## Each base tile gets four pre-baked fringes -- one per cardinal direction --
## cut from the *neighbour's* edge pixels and faded out with an alpha ramp.
## Drawing the neighbour's fringe along the shared edge turns a hard checker
## boundary into a soft transition. This is what the web client's "Loading
## shaders" bar is baking, and the native client's renderFeathers draws.
##
## Peak alpha is half, not full: both sides show a 50/50 mix at the seam
## rather than one replacing the other. The strip is flipped perpendicular to
## the seam so the neighbour's seam-adjacent pixels land at the visible edge --
## without it the fringe reads inside-out.
##
## Baking is lazy: a realm uses a handful of tile types, so paying per type on
## first sight beats walking all 338 up front.

## Fringe depth as a fraction of the cell, and how much to upsample the strip
## before the ramp is applied.
##
## The two references differ here, and this follows the web client: it
## upsamples 4x "so the stretched fringe reads smoothly", which gives an 8px
## tile's 2px strip eight alpha steps instead of two. The native client bakes
## at source resolution and gets the coarser ramp. Everything else below --
## peak alpha, the per-direction ramp, the perpendicular flip, the strips, the
## colour gate -- matches both of them exactly.
const FRACTION := 0.15
const UPSAMPLE := 4
const PEAK_ALPHA := 0.5
enum { NORTH, SOUTH, WEST, EAST, NORTH_WEST, NORTH_EAST, SOUTH_WEST, SOUTH_EAST }

## Land beside a liquid gets a band of its own rather than the liquid's pixels:
## ground darkened wet by water, scorched and lit by lava. Its depth wanders on a
## wave that repeats every SHORE_PERIOD cells along the shore, so each cell bakes
## the stretch of the wave at its place in that period and joins its neighbours.
const SHORE_DEPTH := 14
const SHORE_PERIOD := 4
const WET_ALPHA := 0.42
const SCORCH_ALPHA := 0.7
const WET_SHADE := 0.3
const SCORCH := Color(0.12, 0.035, 0.02)
const LAVA_GLOW := Color(1.0, 0.5, 0.14)

## Baked fringes are packed onto shared pages, so every fringe a chunk draws
## comes from one texture and batches into one draw call, not one per fringe
## texture. A page is re-uploaded when fringes land on it; during a paint that
## waits for flush(), once, rather than once a fringe.
const PAGE_SIZE := 256
const PAGE_PAD := 1

## Texture2D sheet -> its Image, shared by every tile cut from it.
static var _sheet_images := {}
static var _pages: Array[ImageTexture] = []
static var _page_images: Array[Image] = []
static var _dirty_pages := {}
static var _shelf := Vector2i.ZERO
static var _shelf_height := 0
var _variants := {}     # id * 4 + direction -> AtlasTexture, or null when unbakeable
## Set by a pass that will flush() when it is done drawing.
var deferred := false


## The fringe to draw along an edge shared with `tile_id`, or null.
func texture(content: GameData, tile_id: int, direction: int) -> Texture2D:
	var key := tile_id * 4 + direction
	if not _variants.has(key):
		_variants[key] = _bake(content, tile_id, direction)
		if not deferred:
			flush()
	return _variants[key]


## Bakes the band along an edge (or, for a corner direction, around a corner) of
## a land cell shared with a liquid of average colour `colour`. `along` is the
## cell's coordinate along that edge. Not cached here: the caller keeps them.
func shore(colour: Color, direction: int, along: int) -> Texture2D:
	var texture := _pack(_bake_shore(colour, direction,
		posmod(along, SHORE_PERIOD) if direction <= EAST else 0))
	if not deferred:
		flush()
	return texture


static func _bake_shore(colour: Color, direction: int, phase: int) -> Image:
	var cell := GameConstants.TILE_SIZE
	var depth := SHORE_DEPTH
	var size := Vector2i(cell, depth) if direction <= SOUTH \
		else Vector2i(depth, cell) if direction <= EAST else Vector2i(depth, depth)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var warm := clampf((colour.r - colour.b) * 3.0, 0.0, 1.0)
	var wet := Color(colour.r * WET_SHADE, colour.g * WET_SHADE, colour.b * WET_SHADE)
	var period := float(cell * SHORE_PERIOD)
	for y in size.y:
		for x in size.x:
			var from_seam := 0.0
			var along := 0.0
			var near := Vector2(x + 0.5, y + 0.5)
			var far := Vector2(size) - near
			match direction:
				NORTH: from_seam = near.y; along = near.x
				SOUTH: from_seam = far.y; along = near.x
				WEST: from_seam = near.x; along = near.y
				EAST: from_seam = far.x; along = near.y
				NORTH_WEST: from_seam = near.length()
				NORTH_EAST: from_seam = Vector2(far.x, near.y).length()
				SOUTH_WEST: from_seam = Vector2(near.x, far.y).length()
				_: from_seam = far.length()
			var turn := TAU * (along + phase * cell) / period
			var wander := 0.5 + 0.3 * sin(turn + 0.7) + 0.2 * sin(3.0 * turn + 2.1)
			var reach := depth * (0.65 + 0.35 * wander) if direction <= EAST else depth * 0.8
			var fade := 1.0 - from_seam / reach
			if fade <= 0.0:
				continue
			var heat := 1.0 - smoothstep(0.0, 0.4, 1.0 - fade)
			var scorch := SCORCH.lerp(LAVA_GLOW, heat * 0.85)
			var tint := wet.lerp(scorch, warm)
			var strength := lerpf(WET_ALPHA * pow(fade, 1.4), SCORCH_ALPHA * pow(fade, 1.1), warm)
			image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, strength))
	return image


## Where a shore corner sits within a cell: tucked into that corner.
static func corner_rect(origin: Vector2, direction: int, cell: float, depth: float) -> Rect2:
	match direction:
		NORTH_WEST:
			return Rect2(origin, Vector2(depth, depth))
		NORTH_EAST:
			return Rect2(origin + Vector2(cell - depth, 0.0), Vector2(depth, depth))
		SOUTH_WEST:
			return Rect2(origin + Vector2(0.0, cell - depth), Vector2(depth, depth))
	return Rect2(origin + Vector2(cell - depth, cell - depth), Vector2(depth, depth))


## A baked fringe's pixels, read from its page's own copy rather than back off the GPU.
static func pixels(fringe: AtlasTexture) -> Image:
	var page := _pages.find(fringe.atlas)
	if page < 0:
		return fringe.get_image()
	return _page_images[page].get_region(Rect2i(fringe.region))


## Uploads the pages fringes have been packed onto since the last flush.
static func flush() -> void:
	for page in _dirty_pages:
		_pages[page].update(_page_images[page])
	_dirty_pages.clear()


func _bake(content: GameData, tile_id: int, direction: int) -> AtlasTexture:
	var cell: Variant = cell_image(content, tile_id)
	if cell == null:
		return null

	var image: Image = cell
	var depth := maxi(2, roundi(image.get_height() * FRACTION))
	if direction > SOUTH:
		depth = maxi(2, roundi(image.get_width() * FRACTION))
	# The strip adjacent to the seam: for a fringe drawn on my north edge, that
	# is the north neighbour's *bottom* row of pixels.
	var strip: Rect2i
	match direction:
		NORTH: strip = Rect2i(0, image.get_height() - depth, image.get_width(), depth)
		SOUTH: strip = Rect2i(0, 0, image.get_width(), depth)
		WEST: strip = Rect2i(image.get_width() - depth, 0, depth, image.get_height())
		_: strip = Rect2i(0, 0, depth, image.get_height())

	var fringe := image.get_region(strip)
	if direction <= SOUTH:
		fringe.flip_y()
	else:
		fringe.flip_x()
	fringe.resize(fringe.get_width() * UPSAMPLE, fringe.get_height() * UPSAMPLE,
		Image.INTERPOLATE_NEAREST)
	_fade(fringe, direction)
	return _pack(fringe)


## A shelf packer: left to right along a shelf, a new shelf under the tallest
## fringe on it, a new page when the page is full.
static func _pack(fringe: Image) -> AtlasTexture:
	var size := fringe.get_size()
	if size.x > PAGE_SIZE or size.y > PAGE_SIZE:
		var alone := AtlasTexture.new()
		alone.atlas = ImageTexture.create_from_image(fringe)
		alone.region = Rect2(Vector2.ZERO, size)
		return alone
	if _shelf.x + size.x > PAGE_SIZE:
		_shelf = Vector2i(0, _shelf.y + _shelf_height + PAGE_PAD)
		_shelf_height = 0
	if _pages.is_empty() or _shelf.y + size.y > PAGE_SIZE:
		var image := Image.create(PAGE_SIZE, PAGE_SIZE, false, Image.FORMAT_RGBA8)
		_page_images.append(image)
		_pages.append(ImageTexture.create_from_image(image))
		_shelf = Vector2i.ZERO
		_shelf_height = 0
	var page := _pages.size() - 1
	_page_images[page].blit_rect(fringe, Rect2i(Vector2i.ZERO, size), _shelf)
	_dirty_pages[page] = true
	var texture := AtlasTexture.new()
	texture.atlas = _pages[page]
	texture.region = Rect2(_shelf, size)
	texture.filter_clip = true
	_shelf.x += size.x + PAGE_PAD
	_shelf_height = maxi(_shelf_height, size.y)
	return texture


## Alpha ramp: PEAK_ALPHA at the seam edge falling to nothing at the far edge.
static func _fade(image: Image, direction: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	for y in height:
		for x in width:
			var along := 0.0
			match direction:
				NORTH: along = float(y) / float(maxi(height - 1, 1))
				SOUTH: along = 1.0 - float(y) / float(maxi(height - 1, 1))
				WEST: along = float(x) / float(maxi(width - 1, 1))
				_: along = 1.0 - float(x) / float(maxi(width - 1, 1))
			var pixel := image.get_pixel(x, y)
			pixel.a *= PEAK_ALPHA * (1.0 - along)
			image.set_pixel(x, y, pixel)


## The tile's own pixels, cut out of its sheet. Shared with TileBlend, which
## needs the same pixels to work out an average colour.
static func cell_image(content: GameData, tile_id: int) -> Variant:
	var atlas := content.tile_texture(tile_id)
	if atlas == null or atlas.atlas == null:
		return null
	# No null or zero-size guards here: atlas() refuses a sprite key it cannot
	# load and any size at or below zero, so a non-null AtlasTexture always
	# carries a real sheet and a real region.
	# get_image() reads the whole sheet back off the GPU, so each sheet is read
	# once and its pixels kept: fringes are baked the first time a pair of tiles
	# meets, which is mid-walk, as new ground streams in.
	var sheet: Image = _sheet_images.get(atlas.atlas)
	if sheet == null:
		sheet = atlas.atlas.get_image()
		sheet.convert(Image.FORMAT_RGBA8)
		_sheet_images[atlas.atlas] = sheet
	return sheet.get_region(Rect2i(atlas.region))


## Where a fringe sits within a cell: a shallow band hugging the shared edge.
static func edge_rect(origin: Vector2, direction: int, cell: float, depth: float) -> Rect2:
	match direction:
		NORTH:
			return Rect2(origin, Vector2(cell, depth))
		SOUTH:
			return Rect2(origin + Vector2(0.0, cell - depth), Vector2(cell, depth))
		WEST:
			return Rect2(origin, Vector2(depth, cell))
	return Rect2(origin + Vector2(cell - depth, 0.0), Vector2(depth, cell))
