class_name MinimapCanvas
extends Control

## The picture: the tile image scaled up, the others as dots, us as an
## arrow, and a pin on every realm event's boss.
##
## A screen-space Control at 1x, so the strings it draws for the pin names
## and the hovered player are laid out on whole pixels and stay put; the
## rule against draw_string is about the zoomed world canvas, where a
## label's fraction of a pixel changes every frame.

const SIDE := 200.0
const DOT_RADIUS := 3.0
const PIN_RADIUS := 5.0
const EDGE_INSET := 8.0
const OTHER := Color("#ffdd44")
## A player who cannot be teleported to: hidden, or in stasis.
const OTHER_HIDDEN := Color("#888866")
const LOCAL := Color("#40ff40")
const PIN := Color(1.0, 0.31, 0.31, 0.85)
const PIN_NAME := Color("#ffaa66")
const BORDER := Color("#3a2a38")
const HINT := Color("#aaaaaa")
## The web client's hop badge: cyan on a dark box, top left.
const HOP := Color("#4cd0ff")
const HOP_BACK := Color(0, 0, 0, 0.6)

var state: RealmState
## Set by the panel every frame, in tiles.
var window := Rect2()
var hovered := {}
## What the pulse and the pins are timed from; pinned by a scripted render.
var clock: Callable = func() -> int: return Time.get_ticks_msec()
## What the last frame drew, for the tests: dots, pins, arrows off the edge.
var draw_stats := {"dots": 0, "pins": 0, "arrows": 0, "hop": false}

var _texture: ImageTexture
var _painted := -1


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size


func _draw() -> void:
	draw_stats = {"dots": 0, "pins": 0, "arrows": 0, "hop": false}
	if state == null or state.minimap.image == null:
		return
	_refresh_texture()
	draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, Vector2(SIDE, SIDE)), window)
	for player in state.minimap.players:
		# Ours is drawn below from the live predicted position: this
		# snapshot steps at the server's rate while the map scrolls under it.
		if int(player["id"]) == state.local.id:
			continue
		var at := MinimapView.to_panel(player["position"], window, SIDE)
		if not Rect2(-5, -5, SIDE + 10, SIDE + 10).has_point(at):
			continue
		draw_circle(at, DOT_RADIUS, OTHER if player["teleportable"] else OTHER_HIDDEN)
		draw_stats["dots"] += 1
	for marker in state.minimap.markers.values():
		_draw_pin(marker)
	if state.local.is_present():
		draw_colored_polygon(MinimapView.arrow(
			MinimapView.to_panel(state.local.render_position(), window, SIDE),
			MinimapView.heading(state.local.facing, state.local.facing_left)), LOCAL)
	if not hovered.is_empty():
		_draw_name(MinimapView.to_panel(hovered["position"], window, SIDE), hovered)
	if state.minimap.hop:
		_draw_hop_badge()
	draw_rect(Rect2(0.5, 0.5, SIDE - 1.0, SIDE - 1.0), BORDER, false)


func _draw_hop_badge() -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size("HOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_rect(Rect2(2.0, 2.0, roundf(width + 8.0), 14.0), HOP_BACK)
	draw_string(font, Vector2(6.0, 13.0), "HOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HOP)
	draw_stats["hop"] = true


func _refresh_texture() -> void:
	var image: Image = state.minimap.image
	if _texture == null or _texture.get_size() != Vector2(image.get_size()):
		_texture = ImageTexture.create_from_image(image)
	elif _painted != state.minimap.version:
		_texture.update(image)
	_painted = state.minimap.version


## A pulsing red ring and the event's name under it, or a red arrow at the
## edge pointing toward one that is out of the window.
func _draw_pin(marker: Dictionary) -> void:
	var at := MinimapView.to_panel(marker["position"], window, SIDE)
	var pulse := 0.55 + 0.45 * sin(float(clock.call()) * 0.005)
	if not Rect2(0, 0, SIDE, SIDE).has_point(at):
		var edge := at.clamp(Vector2(EDGE_INSET, EDGE_INSET), Vector2(SIDE - EDGE_INSET, SIDE - EDGE_INSET))
		var angle := (at - edge).angle()
		var tip := PackedVector2Array()
		for corner in [Vector2(7, 0), Vector2(-3, -5), Vector2(-3, 5)]:
			tip.append(edge + corner.rotated(angle))
		draw_colored_polygon(tip, Color(1.0, 0.31, 0.31, 0.7 + 0.3 * pulse))
		draw_stats["arrows"] += 1
		return
	draw_circle(at, 8.0 + pulse * 3.0, Color(0.7, 0.12, 0.12, 0.25 + 0.2 * pulse))
	draw_circle(at, PIN_RADIUS, PIN)
	var font := get_theme_default_font()
	var width := font.get_string_size(marker["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_rect(Rect2(Vector2(at.x - width * 0.5 - 3.0, at.y + 8.0).round(), Vector2(width + 6.0, 12.0).round()),
		Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(at.x - width * 0.5, at.y + 17.0).round(), marker["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PIN_NAME)
	draw_stats["pins"] += 1


func _draw_name(at: Vector2, player: Dictionary) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(player["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_rect(Rect2(Vector2(at.x + 5.0, at.y - 12.0).round(), Vector2(width + 6.0, 14.0).round()), Color.BLACK)
	draw_string(font, Vector2(at.x + 8.0, at.y - 1.0).round(), player["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, OTHER if player["teleportable"] else HINT)
	if player["teleportable"]:
		draw_string(font, Vector2(at.x + 8.0, at.y + 9.0).round(), "click to tp",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, HINT)
