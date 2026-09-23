class_name TileBlend
extends RefCounted

## Which neighbouring terrain types are worth feathering together.
##
## Two tiles of near-enough the same material gain nothing from a seam fringe
## and only muddy each other, so they are left with a hard edge. The gate is
## the average colour of each tile, compared against the same distance both
## reference clients use.

## Euclidean RGB distance, 0-255 per channel. Matches the web client's
## TILE_BLEND_DIST_DEFAULT and the native client's TILE_BLEND_MIN_COLOR_DIST.
const MIN_COLOUR_DISTANCE := 36.0

var _signatures := {}   # tile id -> Color, or null when it has no visible pixels


## Whether two neighbouring types are different enough to be worth blending.
func blends(content: GameData, a: int, b: int) -> bool:
	if a == b:
		return false
	var first: Variant = signature(content, a)
	var second: Variant = signature(content, b)
	if first == null or second == null:
		return true   # no signature to compare -- blend rather than guess
	var one: Color = first
	var two: Color = second
	var distance := Vector3(one.r - two.r, one.g - two.g, one.b - two.b).length() * 255.0
	return distance >= MIN_COLOUR_DISTANCE


## Alpha-weighted average colour, so a mostly-transparent tile still reports
## the hue of the pixels it does show.
func signature(content: GameData, tile_id: int) -> Variant:
	if _signatures.has(tile_id):
		return _signatures[tile_id]

	var cell: Variant = TileFeather.cell_image(content, tile_id)
	_signatures[tile_id] = null
	if cell == null:
		return null

	var image: Image = cell
	var total := 0.0
	var sum := Vector3.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			sum += Vector3(pixel.r, pixel.g, pixel.b) * pixel.a
			total += pixel.a
	if total > 0.03:
		_signatures[tile_id] = Color(sum.x / total, sum.y / total, sum.z / total)
	return _signatures[tile_id]
