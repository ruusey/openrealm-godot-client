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
