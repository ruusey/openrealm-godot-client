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
enum { NORTH, SOUTH, WEST, EAST }

var _variants := {}     # "id:direction" -> ImageTexture, or null when unbakeable


## The fringe to draw along an edge shared with `tile_id`, or null.
func texture(content: GameData, tile_id: int, direction: int) -> Texture2D:
	var key := "%d:%d" % [tile_id, direction]
	if not _variants.has(key):
		_variants[key] = _bake(content, tile_id, direction)
	return _variants[key]


func _bake(content: GameData, tile_id: int, direction: int) -> ImageTexture:
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
	return ImageTexture.create_from_image(fringe)


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
	var cell := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	cell.convert(Image.FORMAT_RGBA8)
	return cell


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
