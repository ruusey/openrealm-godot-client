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


static func world(canvas: CanvasItem, position: Vector2) -> Vector2:
	var to_screen := canvas.get_global_transform_with_canvas()
	return to_screen.affine_inverse() * (to_screen * position).round()


## The camera on `centre`, moved the least it takes to put the world's
## origin on a whole screen pixel.
##
## Every body is snapped (`world`); the ground is not, it is drawn where the
## canvas puts it. A camera at a fraction of a pixel therefore slides the
## ground by that fraction while the bodies on it hold, until they jump a
## whole pixel at once -- after every stop, while the correction's offset
## unwinds a fraction a frame, the blue flame in the nexus did exactly that.
## On the grid, the ground moves in whole pixels with them. The web client
## rounds its world layer's pivot for the same reason.
static func camera(camera: Camera2D, centre: Vector2) -> void:
	camera.position = centre
	camera.force_update_scroll()
	var origin := camera.get_viewport().get_canvas_transform().origin
	camera.position += (origin - origin.round()) / camera.zoom
	camera.force_update_scroll()
