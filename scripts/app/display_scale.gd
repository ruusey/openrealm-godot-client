class_name DisplayScale
extends Node

## Fills the window at a whole-number pixel scale.
##
## Godot's own integer stretch cannot. It expands the base viewport to the
## window's aspect, scales that by the largest whole number that fits, and
## centres what is left in black -- so between 1x and 2x of the base the
## picture stops growing and the margins grow instead. Measured on a
## 1900x1000 window: a 1368x720 picture offset (266, 140), and this
## MacBook's whole 3024x1964 screen keeps 262px of black top and bottom.
##
## So the base is the window itself and the scale goes in
## content_scale_factor: the canvas is drawn at exactly `k` and the world
## sees a viewport of exactly window / k, with k stepping up at whole
## multiples of BASE as it always did. A bigger window shows more world,
## which is what the web client's canvas does by filling its container at
## a fixed world scale, and the pixel scale never lands between whole
## numbers, which is what fractional stretch did wrong.
##
## A node, so that it follows the window for exactly as long as it is in
## the tree. Under a headless display there is no screen to fill and it
## stays out of the way: the unit suite shares one 64x64 window between
## every test, and pinning the base to it would cull every scene there.

const BASE := Vector2i(1280, 720)

## The window to follow. Set by a test; otherwise the one this node is in,
## when it is a real one.
var window: Window


## The largest whole scale at which BASE still fits the window, never below
## one. Integer division is the floor.
static func factor_for(window_size: Vector2i) -> int:
	return maxi(1, mini(window_size.x / BASE.x, window_size.y / BASE.y))


static func apply(target: Window) -> void:
	var size := target.size
	if size.x <= 0 or size.y <= 0:
		return
	target.content_scale_size = size
	target.content_scale_factor = float(factor_for(size))


func _enter_tree() -> void:
	if window == null and DisplayServer.get_name() != "headless":
		window = get_window()
	if window == null:
		return
	window.size_changed.connect(_on_resized)
	_on_resized()


func _exit_tree() -> void:
	if window != null:
		window.size_changed.disconnect(_on_resized)


func _on_resized() -> void:
	apply(window)
