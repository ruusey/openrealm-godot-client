class_name FeatherPass
extends RefCounted

## Softens the joins between different terrain types by laying each
## neighbour's faded edge over the shared boundary.
##
## Walls are skipped on both sides -- they are architectural boundaries, and
## feathering them reads as mush -- as are tiles flagged noBlend, like carpet.
## Runs over the base layer once it is drawn, before the walls on top of it.

const TILE_SIZE := GameConstants.TILE_SIZE
const VOID_TILE := 0
const BASE_LAYER := 0
## Which neighbour each fringe direction reads from.
const NO_CELLS := {}
const NO_RECTS: Array = []
## EDGES as two parallel arrays, for the per-cell loop.
const DIRECTIONS := [TileFeather.NORTH, TileFeather.SOUTH, TileFeather.WEST, TileFeather.EAST]
const STEPS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const EDGES := {
	TileFeather.NORTH: Vector2i(0, -1),
	TileFeather.SOUTH: Vector2i(0, 1),
	TileFeather.WEST: Vector2i(-1, 0),
	TileFeather.EAST: Vector2i(1, 0),
}

var feathers := TileFeather.new()
var blending := TileBlend.new()
## Fringes laid down by the last pass -- the visible evidence that seam
## blending is running and that the gates are letting the right edges through.
var drawn := 0


func paint(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i, own := Rect2i()) -> void:
	drawn = 0
	# Only called once the base layer has been drawn, so it exists and has
	# cells in it.
	var base: Dictionary = tiles.layers[BASE_LAYER]
	var above: Dictionary = tiles.layers.get(GameConstants.COLLISION_LAYER, NO_CELLS)
	var looks: Dictionary = content.tile_looks
	var fringe := maxf(2.0, roundf(TILE_SIZE * TileFeather.FRACTION))
	var count_all := not own.has_area()
	var by_texture := {}
	feathers.deferred = true

	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var cell := Vector2i(tile_x, tile_y)
			var mine: int = base.get(cell, VOID_TILE)
			if mine <= VOID_TILE:
				continue
			var mine_look: Array = looks.get(mine, GameData.NO_LOOK)
			if mine_look.is_empty():
				mine_look = content.tile_look(mine)
			# Never lay a fringe OVER a liquid cell: water/lava are drawn by the animated
			# LiquidRenderer above-which this static fringe would paint a dark band, and on
			# a lake's perimeter that becomes a hard rectangular outline that reads as a
			# reversed gradient. The land cells beside the liquid still feather toward it
			# (mine=land, neighbour=liquid below), so the join stays soft from the land side.
			if mine_look[GameData.LOOK_FLAGS] & (GameData.LOOK_NO_BLEND | GameData.LOOK_LIQUID) \
					or _covered(above, looks, content, cell):
				continue
			var origin := Vector2(tile_x * TILE_SIZE, tile_y * TILE_SIZE)
			for direction in DIRECTIONS:
				var beside: Vector2i = cell + STEPS[direction]
				var neighbour: int = base.get(beside, VOID_TILE)
				if neighbour <= VOID_TILE or neighbour == mine:
					continue
				var neighbour_look: Array = looks.get(neighbour, GameData.NO_LOOK)
				if neighbour_look.is_empty():
					neighbour_look = content.tile_look(neighbour)
				if neighbour_look[GameData.LOOK_FLAGS] & GameData.LOOK_NO_BLEND \
						or _covered(above, looks, content, beside):
					continue
				if not blending.blends(content, mine, neighbour):
					continue
				var texture := feathers.texture(content, neighbour, direction)
				if texture != null:
					var batch: Array = by_texture.get(texture, NO_RECTS)
					if batch.is_empty():
						batch = []
						by_texture[texture] = batch
					batch.append(TileFeather.edge_rect(origin, direction, TILE_SIZE, fringe))
					if count_all or own.has_point(cell):
						drawn += 1
	# Drawn grouped by texture, so a chunk's fringes cost a draw call per fringe
	# texture rather than one per fringe; only where two fringes overlap at a
	# corner does the order show, and only as a sliver.
	feathers.deferred = false
	TileFeather.flush()
	for texture in by_texture:
		for rect in by_texture[texture]:
			canvas.draw_texture_rect(texture, rect, false)


## Whether a wall or a solid prop stands over the cell, which stops it blending.
static func _covered(above: Dictionary, looks: Dictionary, content: GameData, cell: Vector2i) -> bool:
	var tile_id: int = above.get(cell, VOID_TILE)
	if tile_id <= VOID_TILE:
		return false
	var look: Array = looks.get(tile_id, GameData.NO_LOOK)
	if look.is_empty():
		look = content.tile_look(tile_id)
	return look[GameData.LOOK_FLAGS] & (GameData.LOOK_WALL | GameData.LOOK_COLLISION) != 0


## A tile that opts out of blending, or one hidden under a solid block above it
## (a wall or any collision tile): water under a wall must not feather into the
## bordering floor. Checking hasCollision as well as isWall catches solid wall
## blocks that aren't flagged isWall. This runs at chunk build, not per frame.
func _blocks_blending(tiles: TileMapState, content: GameData,
		tile_x: int, tile_y: int, tile_id: int) -> bool:
	if int(content.tile_data(tile_id).get("noBlend", 0)) != 0:
		return true
	var above: int = tiles.layers.get(GameConstants.COLLISION_LAYER, {}).get(
		Vector2i(tile_x, tile_y), VOID_TILE)
	if above <= VOID_TILE:
		return false
	var above_data: Dictionary = content.tile_data(above)
	return int(above_data.get("isWall", 0)) != 0 or int(above_data.get("hasCollision", 0)) != 0
