class_name ObjectShadows
extends RefCounted

## Ground shadows for the collision props standing on the map -- anvils,
## tables, torches.
##
## Walls are excluded. They are architecture rather than something resting on
## the floor, and a tall one already carries its own front face; both
## references skip them here for the same reason.
##
## Nothing casts a shadow onto the surface of a liquid, where it would read as
## a hole in the water. The web client gates on the base tile being a slowing
## tile you walk *through* rather than into, which is exactly what water and
## lava are. The native client arrives at the same picture from the other
## side, by redrawing water over the shadow pass afterwards.
##
## Every prop in view is stamped before any of them is drawn, so a prop never
## stands on its neighbour's shadow -- the native client's Pass 3 batches it
## the same way.

const TILE_SIZE := GameConstants.TILE_SIZE
const BASE_LAYER := 0

## Stamped by the last pass.
var drawn := 0


func paint(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i, own := Rect2i()) -> int:
	drawn = 0
	var props: Dictionary = tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	var ground: Dictionary = tiles.layers.get(BASE_LAYER, {})

	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var key := Vector2i(tile_x, tile_y)
			var tile_id: int = props.get(key, 0)
			if not _casts(content, tile_id) or _is_liquid(content, ground.get(key, 0)):
				continue
			if GroundShadow.under_object(canvas,
					Vector2(tile_x * TILE_SIZE, tile_y * TILE_SIZE), TILE_SIZE) \
					and GroundChunk.counts(own, tile_x, tile_y):
				drawn += 1
	return drawn


## A prop: something solid that is not a wall. Decoration on the collision
## layer has no collision at all and rests flat on the ground.
static func _casts(content: GameData, tile_id: int) -> bool:
	return tile_id > 0 and content.tile_has_collision(tile_id) \
		and not content.tile_is_wall(tile_id)


## Water and lava: they slow you and you pass through them.
static func _is_liquid(content: GameData, tile_id: int) -> bool:
	return tile_id > 0 and content.tile_slows(tile_id) \
		and not content.tile_has_collision(tile_id)
