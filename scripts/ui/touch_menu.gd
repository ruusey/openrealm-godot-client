class_name TouchMenu
extends CanvasLayer

## What Menu opens: a short column of big buttons for the panels a keyboard
## reaches with K, J, L and Escape -- the character sheet, the skills, the
## quests, the options -- and the leaderboard, which only the Menu opens. A press opens that panel and folds the list away;
## Menu folds it too. A layer of its own, over the panels (11 and up) that
## sit over the buttons' layer, so the list is never drawn under one.

const BUTTON_SIZE := Vector2(140.0, 44.0)

var _list := VBoxContainer.new()


func _init() -> void:
	layer = 13
	visible = false
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)


## [label, Callable] pairs, in the order they are listed.
func set_items(items: Array) -> void:
	for child in _list.get_children():
		child.free()
	for item in items:
		var open: Callable = item[1]
		_list.add_child(TouchButtons.flat(item[0], BUTTON_SIZE, func() -> void:
			visible = false
			open.call()))


func toggle() -> void:
	visible = not visible


## At `at` in points, drawn at the buttons' own scale.
func place(at: Vector2, points_scale: Vector2) -> void:
	scale = points_scale
	_list.position = at


func count() -> int:
	return _list.get_child_count()


func item(index: int) -> Button:
	return _list.get_child(index)


func holds(point: Vector2) -> bool:
	return visible and _list.get_global_rect().has_point(point)
