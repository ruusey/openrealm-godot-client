class_name TileRenderer
extends Node2D

## Draws terrain, culled to the camera rect.
##
## Its own canvas item, so a shader can be hung on the ground without touching
## the entities standing on it.
##
## Tiles are square cells, except walls: their art is twice as tall as it is
## wide and carries its own front face, so it is drawn two cells tall.
##
## Tile id 0 is Void_Tile: "no tile here", not a black square. The overlay
## layer is almost entirely void -- 16109 of 16384 cells in Nexus_Auru_V1 --
## so drawing it blacks out the ground underneath. The web client skips it the
## same way (`if (!tile || tile.base <= 0) continue`).

const TILE_SIZE := GameConstants.TILE_SIZE
## Empty cell. Layers above the ground use it wherever they place nothing.
const VOID_TILE := 0

## The layer the terrain lives on; anything above it is collision and props.
const BASE_LAYER := 0

## Unknown tile ids are warned about once, not once per tile per frame.
var missing_tiles := {}
var feathers := FeatherPass.new()
var shadows := ObjectShadows.new()
var bands := WallBandPass.new()
var billboards := BillboardOutlines.new()
## Fringes laid down by the last draw.
var feathers_drawn: int:
	get: return feathers.drawn


var state: RealmState
var content: GameData
## What the last frame drew, after culling.
var drawn := 0


func _draw() -> void:
	if state == null or content == null:
		return
	drawn = paint(self, state.tiles, content, ViewRect.of(self))


func paint(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		view: Rect2) -> int:
	var first := Vector2i(floori(view.position.x / TILE_SIZE), floori(view.position.y / TILE_SIZE))
	var last := Vector2i(ceili(view.end.x / TILE_SIZE), ceili(view.end.y / TILE_SIZE))
	var drawn := 0
	billboards.ringed = 0

	var layers := tiles.layers.keys()
	layers.sort()
	for layer in layers:
		var cells: Dictionary = tiles.layers[layer]
		# Props cast their shadows, and walls their bands, before any of them
		# is drawn: ahead of the layer they live on, not after the terrain.
		if layer == GameConstants.COLLISION_LAYER:
			shadows.paint(canvas, tiles, content, first, last)
			bands.paint_under(canvas, tiles, content, first, last)
		for tile_x in range(first.x, last.x + 1):
			for tile_y in range(first.y, last.y + 1):
				var key := Vector2i(tile_x, tile_y)
				if not cells.has(key):
					continue
				var tile_id: int = cells[key]
				if tile_id <= VOID_TILE:
					continue
				var rect := Rect2(tile_x * TILE_SIZE, tile_y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				if layer == GameConstants.COLLISION_LAYER and BillboardOutlines.is_billboard(content, tile_id):
					billboards.ring(canvas, content.tile_texture(tile_id), rect)
				_draw_tile(canvas, content, tile_id, rect)
				drawn += 1
		# Fringes blend the base layer's seams, so they go on after it and
		# before the walls that sit on top; the walls' edge light goes over.
		if layer == BASE_LAYER:
			feathers.paint(canvas, tiles, content, first, last)
		elif layer == GameConstants.COLLISION_LAYER:
			bands.paint_over(canvas, tiles, content, first, last)
	# The billboards' lower edges, over every layer so nothing covers them.
	billboards.paint_bottoms(canvas, tiles, content, first, last)
	return drawn


func _draw_tile(canvas: CanvasItem, content: GameData, tile_id: int, rect: Rect2) -> void:
	var texture := content.tile_texture(tile_id)
	if texture != null:
		# Wall art is 8x16 -- top face above, front face below -- so it draws
		# cell-wide and aspect-scaled tall, anchored at the cell top, spilling
		# one cell south over the floor. Layers ascend and rows run north to
		# south, so a wall below re-covers the spill with its own top face,
		# exactly as both reference clients do it.
		var height := content.tile_render_height(tile_id)
		canvas.draw_texture_rect(texture,
			Rect2(rect.position, Vector2(rect.size.x, height)), false)
		return

	# A content gap should be visible rather than silently blank.
	if not missing_tiles.has(tile_id):
		missing_tiles[tile_id] = true
		push_warning("no sprite for tile id %d" % tile_id)
	canvas.draw_rect(rect, Color.from_hsv(fmod(tile_id * 0.137, 1.0), 0.35, 0.45))
