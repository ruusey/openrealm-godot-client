class_name LiquidRenderer
extends TileRenderer

## Water and lava in their own chunk-cached layer, animated entirely by a shader.
##
## A subclass of TileRenderer so it inherits the ground's chunk caching and camera
## culling -- the cells are drawn ONCE and kept, and the GPU animates them from TIME
## (see liquid.gdshader), so an ocean or a lava lake shimmers and flows with no
## per-frame CPU redraw. It paints only the base-layer tiles the ground skips
## (GameData.tile_is_liquid), sits UNDER the ground layer, and the ground leaves
## those cells transparent -- so a prop or wall standing on a liquid cell still
## draws over it.

const LIQUID_SHADER := preload("res://scripts/render/shaders/liquid.gdshader")

## [content, map id, dungeon id] the chunks were built for; a change drops them.
var _liquid_key := []


func _init() -> void:
	var shaded := ShaderMaterial.new()
	shaded.shader = LIQUID_SHADER
	material = shaded


## Chunk bookkeeping keyed to the map, kept separate from the ground's so it never
## races it over state.tiles.changed_cells (which the ground clears). Call this
## BEFORE the ground's refresh each frame, while changed_cells is still populated.
func refresh() -> void:
	if state == null or content == null:
		return
	var tiles := state.tiles
	var key := [content, tiles.map_id, tiles.dungeon_id]
	if tiles.cleared or _liquid_key != key:
		chunks.drop_all()
		_liquid_key = key
	if not tiles.changed_cells.is_empty():
		chunks.mark(tiles.changed_cells)   # mark only; the ground layer clears them
	chunks.update(self, ViewRect.of(self))


## Only the base-layer water/lava tiles; the ground draws everything else.
func paint_cells(canvas: CanvasItem, own: Rect2i) -> Dictionary:
	if state == null or content == null:
		return {}
	var tiles := state.tiles
	var first := own.position - Vector2i.ONE
	var last := own.end
	var base: Dictionary = tiles.layers.get(BASE_LAYER, {})
	var drawn := 0
	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var tile_id: int = base.get(Vector2i(tile_x, tile_y), VOID_TILE)
			if tile_id <= VOID_TILE or not content.tile_is_liquid(tile_id):
				continue
			_draw_tile(canvas, content, tile_id,
				Rect2(tile_x * TILE_SIZE, tile_y * TILE_SIZE, TILE_SIZE, TILE_SIZE))
			if GroundChunk.counts(own, tile_x, tile_y):
				drawn += 1
	return {"tiles": drawn}
