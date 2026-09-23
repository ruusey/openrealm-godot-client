class_name ViewRect
extends RefCounted

## The slice of world the camera can currently see, padded so entities
## straddling the edge are not popped.

const PADDING_TILES := 2


static func of(canvas: CanvasItem) -> Rect2:
	var viewport := canvas.get_viewport()
	var size := canvas.get_viewport_rect().size
	var camera := viewport.get_camera_2d() if viewport != null else null
	var centre := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	var extent := size / zoom
	return Rect2(centre - extent * 0.5, extent).grow(GameConstants.TILE_SIZE * PADDING_TILES)
