class_name PipColumn
extends Control

## The skill-point tally down an ability cell's right edge.
##
## One pip per point the ability takes, the first `level` of them lit --
## the column both references draw, which reads from across the screen
## where a `2/5` would not. The web client's form: 5px squares with a dark
## border, a pixel apart, from the top-right corner down -- 5px in its
## 44px cell, and the same proportion of ours. The native's are 3.5px
## slivers that vanish at any cell size.

const SIZE_RATIO := 5.0 / 44.0
const GAP := 1.0
const INSET := 2.0
const SPENT := Color("ff9020")
const EMPTY := Color("3a2a20")
const BORDER := Color("2a1a08")

var _pips: Array = []
var _lit := 0
var _cell_px: float
var _size: float


func _init(cell_px: float) -> void:
	_cell_px = cell_px
	_size = pip_px(cell_px)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_points(level: int, cap: int) -> void:
	for pip in _pips:
		remove_child(pip)
		pip.free()
	_pips.clear()
	_lit = mini(level, cap)
	for p in cap:
		var pip := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = SPENT if p < level else EMPTY
		style.border_color = BORDER
		style.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", style)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.position = Vector2(_cell_px - INSET - _size, INSET + p * (_size + GAP))
		pip.size = Vector2(_size, _size)
		add_child(pip)
		_pips.append(pip)


## A pip's side for a cell of this size, whole pixels.
static func pip_px(cell_px: float) -> float:
	return roundf(cell_px * SIZE_RATIO)


## [lit, total], for anyone checking.
func counts() -> Array:
	return [_lit, _pips.size()]


func pip(index: int) -> Panel:
	return _pips[index]


func is_lit(index: int) -> bool:
	return index < _lit
