class_name TouchScale
extends RefCounted

## A layer laid out in desktop points, drawn at a thumb's size on a phone.
##
## A phone's canvas is its device pixels over the UI scale, so a panel built
## for a desktop comes out a fraction of its CSS size there. Scaling the layer
## by the pixel ratio over the canvas's own scale puts it back in points, the
## size the on-screen buttons already use. Never under one.


static func factor(layer: CanvasLayer, pixel_ratio: float) -> float:
	var window := layer.get_window()
	var canvas: float = window.content_scale_factor if window != null else 1.0
	return maxf(1.0, pixel_ratio / canvas)
