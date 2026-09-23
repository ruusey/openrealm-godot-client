class_name InteractPrompt
extends CanvasLayer

## "Use Forge (F)", while a tile that can be used is in reach.
##
## The web client's prompt bar, as one line over the ability bar. It asks
## the same question every frame that F would ask on the way down, so what
## it names is exactly what F will send.

const MARGIN_BOTTOM := 100.0
const FONT_SIZE := 14

var state: RealmState
var shop: ShopActions

var _label: Label


func setup(realm_state: RealmState, shop_actions: ShopActions) -> void:
	state = realm_state
	shop = shop_actions


func _ready() -> void:
	layer = 11
	visible = false
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -MARGIN_BOTTOM
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(_delta: float) -> void:
	var found := {}
	if state != null and shop != null and state.local.is_present():
		found = shop.candidate()
	visible = not found.is_empty()
	if visible:
		_label.text = "%s (F)" % TileInteract.verb(found)
