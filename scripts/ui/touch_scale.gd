class_name TouchScale
extends RefCounted

## Phone sizing for the UI layers.
##
## A phone's canvas is its device pixels over the UI scale, so a layer built
## in desktop points comes out a fraction of its CSS size there. The touch
## buttons scale their own layer by the pixel ratio over the canvas, which
## pins them to a thumb whatever the UI scale. Panels instead take a fixed
## boost, the pixel ratio over the UI scale a phone gets by default: at the
## default they are drawn in points, and the Options UI-scale slider still
## grows or shrinks them from there.

## The panels' boost (TouchFrame applies it). One off a phone; set by Main.
static var panel_factor := 1.0


## The touch buttons' scale: points, whatever the canvas is drawn at.
static func factor(layer: CanvasLayer, pixel_ratio: float) -> float:
	var window := layer.get_window()
	var canvas: float = window.content_scale_factor if window != null else 1.0
	return maxf(1.0, pixel_ratio / canvas)


## The panels' boost for a device pixel ratio and the UI scale it defaults to.
static func panel_factor_for(pixel_ratio: float, default_ui: float) -> float:
	return maxf(1.0, pixel_ratio / maxf(default_ui, 0.01))


## The screen in points at the full panel boost, whatever a frame has
## given up to fit: what a panel lays itself out for.
static func panel_view(item: CanvasItem) -> Vector2:
	return item.get_viewport().get_visible_rect().size / panel_factor


## The screen in an item's own canvas units: a scaled layer's points.
static func view_size(item: CanvasItem) -> Vector2:
	return item.get_viewport().get_visible_rect().size / item.get_canvas_transform().get_scale().x
