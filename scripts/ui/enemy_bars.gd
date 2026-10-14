class_name EnemyBars
extends Control

## Every hurt enemy's health bar, drawn as two rects each in one canvas item.
##
## A bar is all an enemy's tag shows until a status lands on it, and a pooled
## Control tree per enemy, moved every frame, cost more than everything else
## the overlay does; the bars are collected each frame and drawn here instead.
## Same geometry as EntityTag's: ENEMY_BAR_LIFT above the anchor, the
## enemy's width across, ENEMY_BAR_HEIGHT tall.

const BACK := Color(0, 0, 0, 0.6)

var _at := PackedVector2Array()
var _width := PackedFloat32Array()
var _filled := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func begin() -> void:
	_at.clear()
	_width.clear()
	_filled.clear()


## A bar under the tag anchor `at` (screen space, top-left), `width` across.
func add(at: Vector2, width: float, filled: float) -> void:
	_at.append(at)
	_width.append(width)
	_filled.append(filled)


func finish() -> void:
	queue_redraw()


func count() -> int:
	return _at.size()


func _draw() -> void:
	for i in _at.size():
		var top := _at[i] + Vector2(0.0, -EntityTag.ENEMY_BAR_LIFT)
		var width := _width[i]
		draw_rect(Rect2(top, Vector2(width, EntityTag.ENEMY_BAR_HEIGHT)), BACK)
		draw_rect(Rect2(top, Vector2(width * _filled[i], EntityTag.ENEMY_BAR_HEIGHT)), EntityTag.ENEMY_HP)
