class_name WallBands
extends RefCounted

## Side-bands and edge highlights on square walls: the web client's "fancy"
## wall decoration, which is what gives a flat 8x8 wall tile its depth.
##
## A tall wall (8x16) carries its own front face and gets none of this;
## both references skip it. A square one gets, on every side with no wall
## beyond it: three bands of black fading outward, deepest to the south
## (the face the eye reads as the front), then east, then west, then
## north; four copies of its own sprite tinted near-black and shifted a
## pixel out, which read as a rim; and over the body a white highlight
## along the top and left edges. A cell the server has not sent counts as
## a wall, so nothing is extruded toward the unknown.
##
## The numbers are the web client's at its 2x scale, divided back to world
## units, so a band here is the band there to the pixel.

const TILE := float(GameConstants.TILE_SIZE)
## The web client draws at twice world scale; its pixel constants live there.
const SCALE := 2.0
const OUTLINE := Color(0.067, 0.067, 0.094, 0.55)
## [alpha ...] outward, per side.
const SOUTH_ALPHA := [0.55, 0.32, 0.13]
const EAST_ALPHA := [0.42, 0.24, 0.10]
const WEST_ALPHA := [0.32, 0.18, 0.08]
const NORTH_ALPHA := [0.28, 0.15, 0.06]


## Which of a wall's four sides face open ground: {n, s, w, e} -> bool,
## true when nothing wall-like is beyond.
static func exposure(tiles: TileMapState, content: GameData, cell: Vector2i) -> Dictionary:
	return {
		"n": not is_wall_at(tiles, content, cell + Vector2i(0, -1)),
		"s": not is_wall_at(tiles, content, cell + Vector2i(0, 1)),
		"w": not is_wall_at(tiles, content, cell + Vector2i(-1, 0)),
		"e": not is_wall_at(tiles, content, cell + Vector2i(1, 0)),
	}


## A wall of either height, or a cell never sent on any layer -- the web
## client's second isWallAt, which treats the unknown as solid. The stream
## carries no empty cells, so a cell with a floor and nothing on it is one
## the collision layer simply lacks.
static func is_wall_at(tiles: TileMapState, content: GameData, cell: Vector2i) -> bool:
	var tile_id := tiles.tile_at(GameConstants.COLLISION_LAYER, cell.x, cell.y)
	if tile_id > 0:
		return content.tile_is_wall(tile_id)
	return tile_id < 0 and tiles.tile_at(0, cell.x, cell.y) < 0


## A square wall: flagged as one, and drawn a cell tall.
static func is_square_wall(content: GameData, tile_id: int) -> bool:
	return tile_id > 0 and content.tile_is_wall(tile_id) \
		and content.tile_render_height(tile_id) <= TILE


## The bands behind a wall at `cell`, as [{rect, alpha}] in world units.
static func bands(cell: Rect2, open: Dictionary) -> Array:
	var out: Array = []
	var size := cell.size.x * SCALE
	var x := cell.position.x * SCALE
	var y := cell.position.y * SCALE
	if open["s"]:
		var band := ceilf(maxf(roundf(size * 0.28), 4.0) / 3.0)
		var width := size + (roundf(size * 0.18) if open["e"] else 0.0)
		for i in 3:
			out.append(_band(x, y + size + i * band, width, band, SOUTH_ALPHA[i]))
	if open["e"]:
		var band := ceilf(maxf(roundf(size * 0.18), 3.0) / 3.0)
		var top := y + (0.0 if not open["n"] else 2.0)
		for i in 3:
			out.append(_band(x + size + i * band, top, band, y + size - top, EAST_ALPHA[i]))
	if open["w"]:
		var band := ceilf(maxf(roundf(size * 0.13), 3.0) / 3.0)
		for i in 3:
			out.append(_band(x - (i + 1) * band, y, band, size, WEST_ALPHA[i]))
	if open["n"]:
		var band := ceilf(maxf(roundf(size * 0.12), 3.0) / 3.0)
		var left := x + (0.0 if not open["w"] else 2.0)
		var right := x + size - (0.0 if not open["e"] else 2.0)
		for i in 3:
			out.append(_band(left, y - (i + 1) * band, right - left, band, NORTH_ALPHA[i]))
	return out


## Where the tinted copies of the sprite go: one per open side, a pixel out.
static func outline_offsets(open: Dictionary) -> Array:
	var out: Array = []
	for side in [["e", Vector2(1, 0)], ["w", Vector2(-1, 0)], ["s", Vector2(0, 1)], ["n", Vector2(0, -1)]]:
		if open[side[0]]:
			out.append(side[1])
	return out


## The white edge over the body: [{rect, alpha}], top then left.
static func highlights(cell: Rect2, open: Dictionary) -> Array:
	var out: Array = []
	var size := cell.size.x * SCALE
	var x := cell.position.x * SCALE
	var y := cell.position.y * SCALE
	if open["n"]:
		out.append(_band(x, y, size, 2.0, 0.26))
		out.append(_band(x, y + 2.0, size, 2.0, 0.11))
	if open["w"]:
		out.append(_band(x, y, 1.0, size, 0.14))
		out.append(_band(x + 1.0, y, 1.0, size, 0.06))
	return out


static func _band(x: float, y: float, width: float, height: float, alpha: float) -> Dictionary:
	return {"rect": Rect2(x / SCALE, y / SCALE, width / SCALE, height / SCALE), "alpha": alpha}
