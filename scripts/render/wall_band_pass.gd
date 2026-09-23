class_name WallBandPass
extends RefCounted

## Paints WallBands over the view: the bands and rim copies under the
## wall bodies, the highlights over them. Two calls, because the tile pass
## draws the bodies in between.

var drawn := 0
## The options' "Wall side-bands" -- the web client's 'fancy' walls; off is
## its 'simple'. GameSettings.apply sets it.
static var enabled := true


## Bands and rim copies for every square wall in view; call before the
## collision layer's bodies.
func paint_under(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i) -> void:
	drawn = 0
	if not enabled:
		return
	for cell in _square_walls(tiles, content, first, last):
		var rect := Rect2(cell.x * WallBands.TILE, cell.y * WallBands.TILE, WallBands.TILE, WallBands.TILE)
		var open := WallBands.exposure(tiles, content, cell)
		for band in WallBands.bands(rect, open):
			canvas.draw_rect(band["rect"], Color(0, 0, 0, band["alpha"]))
			drawn += 1
		var texture := content.tile_texture(tiles.tile_at(GameConstants.COLLISION_LAYER, cell.x, cell.y))
		if texture == null:
			continue
		for offset in WallBands.outline_offsets(open):
			canvas.draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, WallBands.OUTLINE)


## The white edges; call after the bodies.
func paint_over(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i) -> void:
	if not enabled:
		return
	for cell in _square_walls(tiles, content, first, last):
		var rect := Rect2(cell.x * WallBands.TILE, cell.y * WallBands.TILE, WallBands.TILE, WallBands.TILE)
		for line in WallBands.highlights(rect, WallBands.exposure(tiles, content, cell)):
			canvas.draw_rect(line["rect"], Color(1, 1, 1, line["alpha"]))


static func _square_walls(tiles: TileMapState, content: GameData, first: Vector2i, last: Vector2i) -> Array:
	var out: Array = []
	var walls: Dictionary = tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var cell := Vector2i(tile_x, tile_y)
			if WallBands.is_square_wall(content, int(walls.get(cell, 0))):
				out.append(cell)
	return out
