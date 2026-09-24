class_name PixelSnap
extends RefCounted

## A world position moved to the nearest whole screen pixel.
##
## The camera follows the player between ticks, so every world coordinate
## lands on a different fraction of a screen pixel each frame. A sprite
## survives that; text does not: a label drawn at x.3 and then x.7 is
## rasterised twice, differently, and reads as a wobble under the feet
## that is worst on a diagonal, where both axes drift. The web client
## rounds its sprites and keeps its labels in screen space for the same
## reason. Snapping through the canvas transform and back leaves the caller
## drawing in world units, with nothing to know about the zoom.


## Far below a pixel, far above float noise on a realm's coordinates.
const SETTLE := 0.01


static func world(canvas: CanvasItem, position: Vector2) -> Vector2:
	var to_screen := canvas.get_global_transform_with_canvas()
	return to_screen.affine_inverse() * (to_screen * position).round()


## The camera on `centre`, moved the least it takes to put the world's
## origin on a whole screen pixel and `anchor` -- the body the camera
## follows, as `world` snaps it -- on the same pixel every frame.
##
## Every body is snapped (`world`); the ground is not, it is drawn where the
## canvas puts it. A camera at a fraction of a pixel therefore slid the
## ground by that fraction while the bodies on it held, until they jumped a
## whole pixel at once -- after every stop the blue flame in the nexus did
## exactly that. On the grid, the ground moves in whole pixels with them.
##
## But the grid alone is not enough at a zoom that puts the followed body
## on a half pixel -- 1.25, a browser's: rounded apart, the camera and the
## body disagreed by one pixel on alternate frames, and the player and the
## name under them hopped between two spots, a blur on a diagonal. So the
## origin is the one that leaves the body where it would stand with the
## camera exactly on it, rounded once. The web client rounds its world
## layer's pivot for the same reason.
static func camera(camera: Camera2D, centre: Vector2, anchor := centre) -> void:
	camera.position = centre
	camera.force_update_scroll()
	var to_screen := camera.get_viewport().get_canvas_transform()
	var body := to_screen.basis_xform(anchor)
	# Where the body lands with the camera exactly on it never changes; a
	# hair of bias keeps float noise from flipping a half pixel's rounding.
	var origin := (to_screen.origin + body + Vector2(SETTLE, SETTLE)).round() - body.round()
	camera.position += (to_screen.origin - origin) / camera.zoom
	camera.force_update_scroll()
