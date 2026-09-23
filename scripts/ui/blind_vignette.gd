class_name BlindVignette
extends TextureRect

## The dark around a blinded player: the web client's renderBlindVignette.
##
## Clear inside the tunnel (Blind.RADIUS on screen), then darkening in the
## web's stops -- 55% just past the edge, 90% two-fifths of the way out, 98%
## at the far corner of the screen -- so the edges are all but black on any
## aspect. A radial GradientTexture2D on a square centred on the player and
## reaching that corner, so the circle stays round on a wide window; it is
## rebuilt only when the tunnel or the window changes size, and otherwise
## only moves. Click-through, like the rest of the overlay.

## Where the darkening lands between the tunnel's edge (0) and the far
## corner (1), and how dark it is there.
const STOPS := [[0.0, 0.0], [0.12, 0.55], [0.4, 0.9], [1.0, 0.98]]
## The gradient's own resolution; it is stretched, and a radial fade has no
## detail to lose.
const SIDE := 256

var _key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


## Over the player on `screen` while they are blind; hidden otherwise.
func follow(state: RealmState, to_screen: Transform2D, screen: Vector2) -> void:
	visible = state != null and Blind.active(state)
	if not visible:
		return
	var centre := (to_screen * Blind.centre(state)).round()
	var inner := Blind.RADIUS * to_screen.get_scale().x
	var reach := Vector2(maxf(centre.x, screen.x - centre.x), maxf(centre.y, screen.y - centre.y))
	var outer := maxf(reach.length() + 8.0, inner + 1.0)
	var key := "%d:%d" % [roundi(inner), roundi(outer)]
	if key != _key:
		_key = key
		texture = gradient(inner / outer)
	position = centre - Vector2(outer, outer)
	size = Vector2(outer, outer) * 2.0


## The fade, with the clear tunnel the first `clear` of the radius.
static func gradient(clear: float) -> GradientTexture2D:
	var offsets := PackedFloat32Array([0.0])
	var colours := PackedColorArray([Color(0, 0, 0, 0)])
	for stop in STOPS:
		offsets.append(clear + float(stop[0]) * (1.0 - clear))
		colours.append(Color(0, 0, 0, float(stop[1])))
	var fade := Gradient.new()
	fade.offsets = offsets
	fade.colors = colours
	var out := GradientTexture2D.new()
	out.gradient = fade
	out.fill = GradientTexture2D.FILL_RADIAL
	out.fill_from = Vector2(0.5, 0.5)
	out.fill_to = Vector2(1.0, 0.5)
	out.width = SIDE
	out.height = SIDE
	return out
