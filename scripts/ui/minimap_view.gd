class_name MinimapView
extends RefCounted

## Where the minimap looks, and the mapping between its pixels and the world.
##
## The web client's render(): a window `zoom` times the map on each side,
## centred on the player and pushed back inside the map at its edges -- so
## mid-map the marker sits at the centre and slides toward the edge as the
## window runs out of map. Pure functions, so the panel's arithmetic is
## tested without a window.

const TILE := float(GameConstants.TILE_SIZE)
## `zoom` is the visible fraction of the map: 1 is all of it. The web
## client's range and wheel step.
const MIN_ZOOM := 0.05
const MAX_ZOOM := 1.0
const ZOOM_STEP := 0.05
## About this many tiles across to start with. The native client's rule: the
## web opens on the whole map, which on a 320-tile overworld makes the
## region you have been sent a dot.
const INITIAL_TILES := 64.0
const INITIAL_MIN_ZOOM := 0.1


## The window, in tiles.
static func window(map_size: Vector2i, zoom: float, focus_tile: Vector2) -> Rect2:
	var extent := Vector2(map_size) * zoom
	var origin := focus_tile - extent * 0.5
	origin.x = clampf(origin.x, 0.0, maxf(0.0, map_size.x - extent.x))
	origin.y = clampf(origin.y, 0.0, maxf(0.0, map_size.y - extent.y))
	return Rect2(origin, extent)


## A world position to a point on a square panel `panel_px` wide showing `window`.
static func to_panel(world: Vector2, window: Rect2, panel_px: float) -> Vector2:
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		return Vector2.ZERO
	return (world / TILE - window.position) / window.size * panel_px


## And back, for a click.
static func to_world(panel_point: Vector2, window: Rect2, panel_px: float) -> Vector2:
	return (window.position + panel_point / panel_px * window.size) * TILE


static func initial_zoom(map_size: Vector2i) -> float:
	var longest := maxi(map_size.x, map_size.y)
	if longest <= 0:
		return MAX_ZOOM
	return clampf(INITIAL_TILES / float(longest), INITIAL_MIN_ZOOM, MAX_ZOOM)


## One wheel notch: -1 zooms in (a smaller fraction), +1 out.
static func step(zoom: float, direction: int) -> float:
	return clampf(zoom + direction * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)


## Which way the local marker points, from the sprite's own facing -- the
## same fields a scripted render sets, so a capture can reproduce it.
static func heading(facing: String, facing_left: bool) -> Vector2:
	match facing:
		"back": return Vector2.UP
		"side": return Vector2.LEFT if facing_left else Vector2.RIGHT
	return Vector2.DOWN


## The web client's marker: a triangle 5 up and 4 to each side, rotated
## to its heading.
static func arrow(at: Vector2, heading: Vector2) -> PackedVector2Array:
	var angle := heading.angle() + PI * 0.5
	var points := PackedVector2Array()
	for corner in [Vector2(0, -5), Vector2(-4, 4), Vector2(4, 4)]:
		points.append(at + corner.rotated(angle))
	return points
