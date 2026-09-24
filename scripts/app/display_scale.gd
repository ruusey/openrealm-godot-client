class_name DisplayScale
extends Node

## Fills the window at a whole-number pixel scale.
##
## Godot's integer stretch centres a base-aspect picture in black margins
## (a 1900x1000 window drew 1368x720), so the base is the window itself and
## the scale goes in content_scale_factor: the canvas is drawn at exactly
## `k`, stepping up at whole multiples of BASE, and a bigger window shows
## more world, as the web client's canvas does.
##
## A browser's canvas is the page times its pixel ratio, so a phone's --
## 2340x1080 for 891x411 CSS px -- never fits BASE twice and drew at 1x, a
## third of its CSS size. Every page, and the phone app, therefore draws
## at WEB_UI and WEB_WORLD, the owner's picks on a laptop and a phone. The
## desktop app keeps the whole-number fit; the goldens are made at 1x.
##
## The world has a zoom of its own: the canvas scale would magnify it with
## the UI, so the camera divides it back out -- WORLD_ZOOM times the
## world's scale over the canvas's -- automatic or `world_chosen`.
##
## A node, so it follows the window while in the tree. Headless there is no
## screen and it stays out of the way: the unit suite shares one 64x64
## window, and pinning the base to it would cull every scene there.

const BASE := Vector2i(1280, 720)
## The camera's zoom at a world scale of one: two canvas pixels a world unit.
const WORLD_ZOOM := 2.0
## The automatic UI scale and world zoom in a browser and the phone app.
const WEB_UI := 2.0
const WEB_WORLD := 1.25

## The window to follow. Set by a test; otherwise the one this node is in,
## when it is a real one.
var window: Window
## A page in any browser, or the phone app: WEB_UI and WEB_WORLD apply.
var web := OS.has_feature("web") or OS.has_feature("android")
## The player's own scale from the options, or 0 for automatic.
var chosen := 0.0:
	set(value):
		chosen = value
		_on_resized()
## The player's world zoom from the options, or 0 for automatic.
var world_chosen := 0.0:
	set(value):
		world_chosen = value
		_on_resized()
## The world's camera, zoomed to keep the world at its own scale.
var camera: Camera2D:
	set(value):
		camera = value
		_on_resized()


## The player's scale; on the web, WEB_UI; otherwise the largest whole
## scale at which BASE still fits the window, never below one. Integer
## division is the floor.
static func factor_for(window_size: Vector2i, player := 0.0, on_web := false) -> float:
	if player > 0.0:
		return player
	if on_web:
		return WEB_UI
	return float(maxi(1, mini(window_size.x / BASE.x, window_size.y / BASE.y)))


## The world's automatic scale: WEB_WORLD on the web, the UI's automatic
## one in the desktop app.
static func auto_world(window_size: Vector2i, on_web := false) -> float:
	return WEB_WORLD if on_web else factor_for(window_size)


static func apply(target: Window, player := 0.0, on_web := false) -> void:
	var size := target.size
	if size.x <= 0 or size.y <= 0:
		return
	target.content_scale_size = size
	target.content_scale_factor = factor_for(size, player, on_web)


## The camera zoom that draws the world at `world_player` (0: the automatic
## scale) whatever the canvas is scaled by for the UI.
static func camera_zoom(window_size: Vector2i, ui_player := 0.0, world_player := 0.0, on_web := false) -> float:
	var world := world_player if world_player > 0.0 else auto_world(window_size, on_web)
	return WORLD_ZOOM * world / factor_for(window_size, ui_player, on_web)


## The world's scale on screen now, read back off the camera and the canvas.
static func world_now(viewport: Viewport) -> float:
	var camera := viewport.get_camera_2d()
	var canvas := viewport.get_window().content_scale_factor if viewport.get_window() != null else 1.0
	return canvas if camera == null else camera.zoom.x * canvas / WORLD_ZOOM


## Keeps both scales to the player's settings, now and on every change.
func follow(settings: GameSettings) -> void:
	var take := func() -> void:
		chosen = settings.ui_scale
		world_chosen = settings.world_zoom
	take.call()
	settings.changed.connect(take)


## A scale as a player reads it: 1.75, 2 -- never 2.0.
static func label(scale: float) -> String:
	return String.num(scale, 2).trim_suffix(".0")


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
	if window == null:
		return
	apply(window, chosen, web)
	if camera != null:
		camera.zoom = Vector2.ONE * camera_zoom(window.size, chosen, world_chosen, web)
