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
		first: Vector2i, last: Vector2i) -> void:
	drawn = 0
	# Only called once the base layer has been drawn, so it exists and has
	# cells in it.
	var base: Dictionary = tiles.layers[BASE_LAYER]
	var fringe := maxf(2.0, roundf(TILE_SIZE * TileFeather.FRACTION))

	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var mine: int = base.get(Vector2i(tile_x, tile_y), VOID_TILE)
			if mine <= VOID_TILE or _blocks_blending(tiles, content, tile_x, tile_y, mine):
				continue
			var origin := Vector2(tile_x * TILE_SIZE, tile_y * TILE_SIZE)
			for direction in EDGES:
				var step: Vector2i = EDGES[direction]
				var neighbour: int = base.get(Vector2i(tile_x + step.x, tile_y + step.y), VOID_TILE)
				if neighbour <= VOID_TILE or neighbour == mine:
					continue
				if _blocks_blending(tiles, content, tile_x + step.x, tile_y + step.y, neighbour):
					continue
				if not blending.blends(content, mine, neighbour):
					continue
				var texture := feathers.texture(content, neighbour, direction)
				if texture != null:
					canvas.draw_texture_rect(texture,
						TileFeather.edge_rect(origin, direction, TILE_SIZE, fringe), false)
					drawn += 1


## A wall cell, or a tile that opts out of blending.
func _blocks_blending(tiles: TileMapState, content: GameData,
		tile_x: int, tile_y: int, tile_id: int) -> bool:
	if int(content.tile_data(tile_id).get("noBlend", 0)) != 0:
		return true
	var above: int = tiles.layers.get(GameConstants.COLLISION_LAYER, {}).get(
		Vector2i(tile_x, tile_y), VOID_TILE)
	return above > VOID_TILE and int(content.tile_data(above).get("isWall", 0)) != 0
