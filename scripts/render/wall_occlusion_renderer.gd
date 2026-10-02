class_name WallOcclusionRenderer
extends Node2D

## Redraws each tall wall's top face -- and each large decoration's canopy -- over
## the entities, for 2.5D depth.
##
## Wall art is 8x16: the upper square is the top face, the lower one the front
## face that spills a cell south. The tile pass draws the whole sprite below
## the entities, which alone would let a character standing *behind* a wall
## draw over it. Stamping just the top face again up here covers them -- while
## a character standing in front, overlapping only the front face, still draws
## over the wall, because the front face exists only in the pass underneath.
##
## Oversized decorations (large trees, tiles whose `size` exceeds the cell) use the
## same trick: their trunk is the centre cell, so redrawing the sprite from its top
## down to that cell's south edge covers a character behind/under the canopy, while
## one in front (south of the trunk) overlaps only the un-redrawn bottom and draws over.
##
## Its own layer for the same reason the others are: both reference clients
## give this pass a container of its own, above the entities and below the
## projectiles.

var state: RealmState
var content: GameData
## Top faces / canopies stamped last frame.
var drawn := 0


func _draw() -> void:
	drawn = 0
	if state == null or content == null:
		return

	var walls: Dictionary = state.tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	if walls.is_empty():
		return

	var size := GameConstants.TILE_SIZE
	var view := ViewRect.of(self)
	var first := Vector2i(floori(view.position.x / size), floori(view.position.y / size))
	var last := Vector2i(ceili(view.end.x / size), ceili(view.end.y / size))

	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var tile_id: int = walls.get(Vector2i(tile_x, tile_y), 0)
			if tile_id <= 0:
				continue
			# Large decorations (render bigger than the cell): redraw the canopy over entities,
			# from the sprite's top down to the trunk cell's south edge. A character standing
			# south of that edge (in front of the trunk) overlaps only the un-redrawn bottom
			# and so draws over it; one behind/under the canopy is covered.
			var cell_rect := Rect2(tile_x * size, tile_y * size, size, size)
			var draw_rect := content.tile_render_rect(tile_id, cell_rect)
			if draw_rect != cell_rect:
				var cover_h := float(tile_y * size + size) - draw_rect.position.y
				var canopy := content.tile_canopy(tile_id, cover_h / draw_rect.size.y)
				if canopy != null:
					draw_texture_rect(canopy,
						Rect2(draw_rect.position, Vector2(draw_rect.size.x, cover_h)), false)
					drawn += 1
				continue
			var face := content.tile_top_face(tile_id)
			if face == null:
				continue
			draw_texture_rect(face,
				Rect2(tile_x * size, tile_y * size, size, size), false)
			drawn += 1
