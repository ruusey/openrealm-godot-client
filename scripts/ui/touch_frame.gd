class_name TouchFrame
extends Control

## The screen in a panel layer's own points. The layer is scaled by
## TouchScale.panel_factor, and its controls anchor to this frame, sized to
## the screen over that scale, rather than to the unscaled viewport -- so a
## centred or corner-anchored panel stays on screen at any boost. With no
## boost (every desktop) it is simply the full screen. It follows the screen
## only while its layer shows, so a shut panel does no work.


## Move a built layer's controls under a frame and keep the layer scaled.
## Called last in the layer's _ready, once its controls exist.
static func adopt(layer: CanvasLayer) -> TouchFrame:
	var controls := layer.get_children().filter(func(child: Node) -> bool: return child is Control)
	var frame := TouchFrame.new()
	layer.add_child(frame)
	layer.move_child(frame, 0)
	for control in controls:
		control.reparent(frame, false)
	return frame


func _init() -> void:
	name = "TouchFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var layer := get_parent() as CanvasLayer
	if layer != null:
		layer.visibility_changed.connect(_follow_layer)
	_follow_layer()


func _process(_delta: float) -> void:
	_fit()


func _follow_layer() -> void:
	var layer := get_parent() as CanvasLayer
	set_process(layer != null and layer.visible)
	_fit()


func _fit() -> void:
	var layer := get_parent() as CanvasLayer
	if layer == null or not is_inside_tree():
		return
	var factor := TouchScale.panel_factor
	if layer.scale.x != factor:
		layer.scale = Vector2.ONE * factor
	var screen := get_viewport().get_visible_rect().size / factor
	if position != Vector2.ZERO:
		position = Vector2.ZERO
	if size != screen:
		size = screen
