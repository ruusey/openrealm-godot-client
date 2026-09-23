class_name WallOcclusionRenderer
extends Node2D

## Redraws each tall wall's top face over the entities, for 2.5D depth.
##
## Wall art is 8x16: the upper square is the top face, the lower one the front
## face that spills a cell south. The tile pass draws the whole sprite below
## the entities, which alone would let a character standing *behind* a wall
## draw over it. Stamping just the top face again up here covers them -- while
## a character standing in front, overlapping only the front face, still draws
## over the wall, because the front face exists only in the pass underneath.
##
## Its own layer for the same reason the others are: both reference clients
## give this pass a container of its own, above the entities and below the
## projectiles.

var state: RealmState
var content: GameData
## Top faces stamped last frame.
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
			var face := content.tile_top_face(tile_id)
			if face == null:
				continue
			draw_texture_rect(face,
				Rect2(tile_x * size, tile_y * size, size, size), false)
			drawn += 1
