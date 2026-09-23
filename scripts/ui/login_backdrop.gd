class_name LoginBackdrop
extends Control

## The scene behind the sign-in panel: a torchlit stone hall built from the
## game's own tiles at the world's pixel scale, four torches along the
## wall and a candelabra on the floor, their flames the projectile trails'
## particles and their light on the stone. Nothing here is interactive.
##
## Three canvas items, drawn in order: this one paints the tiles lit per
## cell and the torch sprites; `_glow` adds a soft warm halo at each flame
## (an additive blend, so it brightens rather than paints over); `_flames`
## draws the particle field on top.

const TILE := HallTiles.TILE
## Where along the wall the torches hang, as fractions of the width, and
## the wall row they hang on.
const TORCH_COLUMNS := [0.08, 0.31, 0.69, 0.92]
const TORCH_ROW := 3
const CANDELABRA_Y := 0.73

var game_data: GameData
## Content ids, replaceable for a test's fixture; the hall's own are on `hall`.
var torch_tile := 214
var candelabra_tile := 213
var field := ParticleField.new()
## Seconds, for the flicker; pinned by a scripted render.
var clock: Callable = func() -> float: return Time.get_ticks_msec() * 0.001
var drawn := {"tiles": 0, "torches": 0, "flames": 0}

var _glow: Control
var _flames: Control
var hall := HallTiles.new()
var _torch_acc := {}
var _candle_acc := {}


static func attach(into: Node, content: GameData) -> LoginBackdrop:
	var backdrop := LoginBackdrop.new()
	backdrop.game_data = content
	into.add_child(backdrop)
	return backdrop


func _ready() -> void:
	field.rng.seed = 1
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Under a CanvasLayer the anchors alone left this at zero size, so the
	# size is taken from the viewport outright and again when it changes.
	_fit()
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow = _layer(CanvasItemMaterial.BLEND_MODE_ADD)
	_glow.draw.connect(_draw_glow)
	_flames = _layer(CanvasItemMaterial.BLEND_MODE_MIX)
	_flames.draw.connect(_draw_flames)


func _fit() -> void:
	if not get_parent() is Control:
		size = get_viewport_rect().size


func _layer(blend: CanvasItemMaterial.BlendMode) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.material = CanvasItemMaterial.new()
	layer.material.blend_mode = blend
	add_child(layer)
	return layer


## Hidden -- the player is in the game -- it stops stepping and drops the
## fire it had, so nothing burns unseen behind a whole session; shown again
## after a death or a disconnect, it lights up anew.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
		var shown := is_visible_in_tree()
		set_process(shown)
		if not shown:
			field.clear()
			_torch_acc.clear()
			_candle_acc.clear()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		step(delta)


## One frame of fire, apart from _process so a capture can run a fixed
## number of them.
func step(delta: float) -> void:
	field.advance(delta, {})
	TorchFlame.emit(field, torch_tips(), delta, _torch_acc)
	TorchFlame.emit(field, [candle_tip()], delta, _candle_acc, TorchFlame.CANDLE)
	queue_redraw()
	_glow.queue_redraw()
	_flames.queue_redraw()


## Where each torch's flame starts: the sprite is drawn two tiles square,
## its flame at the top centre.
func torch_tips() -> Array:
	var tips: Array = []
	for fraction in TORCH_COLUMNS:
		tips.append(Vector2(roundf(fraction * size.x), TORCH_ROW * TILE + 8.0))
	return tips


func candle_tip() -> Vector2:
	return Vector2(roundf(size.x * 0.5), roundf(size.y * CANDELABRA_Y) + 6.0)


## Every flame with how hard it burns right now.
func lights() -> Array:
	return TorchFlame.lights(torch_tips(), candle_tip(), clock.call())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04))
	drawn = {"tiles": 0, "torches": 0, "flames": drawn["flames"]}
	# Not before the sheets are in: a sheet asked for early is recorded as
	# a content warning, and the browser fetches them while this is up.
	if game_data == null or not game_data.ready:
		return
	drawn["tiles"] = hall.paint(self, game_data, size, lights())
	var torch := game_data.tile_texture(torch_tile)
	for tip in torch_tips():
		if _sprite(torch, tip):
			drawn["torches"] += 1
	_sprite(game_data.tile_texture(candelabra_tile), candle_tip())


## A sprite two tiles square with its flame at `tip`.
func _sprite(texture: Texture2D, tip: Vector2) -> bool:
	if texture == null:
		return false
	draw_texture_rect(texture, Rect2(tip - Vector2(TILE, 8.0), Vector2(TILE, TILE) * 2.0), false)
	return true


func _draw_glow() -> void:
	TorchFlame.paint_glow(_glow, lights())


func _draw_flames() -> void:
	drawn["flames"] = ParticleRenderer.paint(_flames, field, Rect2(Vector2.ZERO, size))
