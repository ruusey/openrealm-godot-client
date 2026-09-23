class_name CollisionOverlay
extends Node2D

## The collision debug view: every solid cell in the camera's view, tinted.
##
## Its own layer, last in the world, rather than drawn with the tiles: the
## wall tops are stamped above the tile layer, so anything drawn down there
## is hidden by them. F2 toggles it.

var state: RealmState
var content: GameData
var show_collision := false


func _draw() -> void:
	if not show_collision or state == null or content == null:
		return
	var view := ViewRect.of(self)
	var size := GameConstants.TILE_SIZE
	var cells: Dictionary = state.tiles.layers.get(GameConstants.COLLISION_LAYER, {})
	var first := Vector2i(floori(view.position.x / size), floori(view.position.y / size))
	var last := Vector2i(ceili(view.end.x / size), ceili(view.end.y / size))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var tile_id: int = cells.get(Vector2i(x, y), -1)
			if tile_id >= 0 and content.tile_has_collision(tile_id):
				draw_rect(Rect2(x * size, y * size, size, size), Color(1, 0, 0, 0.25), true)
