class_name BillboardOutlines
extends RefCounted

## The dark silhouette around the props and decorations standing on the
## collision layer -- trees, rocks, bushes, anvils: the "billboards" -- as
## both reference clients draw it.
##
## Two parts. The ring: SpriteOutline's eight offset copies, stamped behind
## each billboard as the tile pass reaches it. That alone loses the bottom
## edge -- whatever the pass draws in the next row down lands on the fringe
## below the prop, and a neighbour's own ring darkens a strip of the body
## above it -- so once every tile layer is down, each billboard is stamped
## again: one dark copy a unit lower, then its body over that, leaving only
## the lower edge of the visible pixels dark. That is the web client's
## addBottomOutlineOverlay and the native client's renderBottomOutline,
## "drawn last so nothing paints over it".
##
## Walls are not billboards: square ones get WallBands, tall ones their own
## front face. And neither reference gates these on the "Sprite outlines"
## option, which is about entities and shots: tile outlines are part of the
## map's look, so SpriteOutline.enabled is not read here either.

const TILE_SIZE := GameConstants.TILE_SIZE

## Billboards ringed, and re-stamped, by the last draw.
var ringed := 0
var drawn := 0


static func is_billboard(content: GameData, tile_id: int) -> bool:
	return tile_id > 0 and not content.tile_is_wall(tile_id)


## The ring behind one billboard, drawn just before its body. A tile with
## no art has no silhouette to ring; its placeholder block goes bare.
func ring(canvas: CanvasItem, texture: Texture2D, rect: Rect2, own := Rect2i()) -> void:
	if texture == null:
		return
	if GroundChunk.counts(own, floori(rect.position.x / TILE_SIZE), floori(rect.position.y / TILE_SIZE)):
		ringed += 1
	for offset in SpriteOutline.OFFSETS:
		canvas.draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, SpriteOutline.TINT)


## The bottom edge and the body again, for every billboard in view; call
## after every tile layer. Rows north to south, as both references run it.
func paint_bottoms(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i, own := Rect2i()) -> int:
	drawn = 0
	var props: Dictionary = tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	if props.is_empty():
		return 0
	var below := Vector2(0.0, SpriteOutline.OFFSET)
	for tile_y in range(first.y, last.y + 1):
		for tile_x in range(first.x, last.x + 1):
			var tile_id: int = props.get(Vector2i(tile_x, tile_y), 0)
			if not is_billboard(content, tile_id):
				continue
			var texture := content.tile_texture(tile_id)
			if texture == null:
				continue
			var rect := Rect2(tile_x * TILE_SIZE, tile_y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			canvas.draw_texture_rect(texture, Rect2(rect.position + below, rect.size), false, SpriteOutline.TINT)
			canvas.draw_texture_rect(texture, rect, false)
			if GroundChunk.counts(own, tile_x, tile_y):
				drawn += 1
	return drawn
