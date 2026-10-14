extends Node2D

## Repaints one ground chunk's worth of cells inside its own draw, timing it.

var ground: TileRenderer
var chunk := Vector2i(2, 2)
var samples: Array[float] = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ground == null:
		return
	var started := Time.get_ticks_usec()
	ground.paint_cells(self, Rect2i(chunk * GroundChunk.SIZE, Vector2i(GroundChunk.SIZE, GroundChunk.SIZE)))
	samples.append(Time.get_ticks_usec() - started)
