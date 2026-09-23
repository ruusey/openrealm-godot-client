class_name WorldRenderer
extends Node2D

## The realm, drawn as six stacked canvas items.
##
## Each layer is a Node2D that redraws itself every frame -- still
## immediate-mode, still culled to the camera rect, with no node per entity.
## The split exists so a layer can carry its own material: every CanvasItem
## has one, so a shader on the ground leaves the characters standing on it
## alone. Both reference clients are arranged the same way, and the web client
## deliberately keeps its bullet layer outside the graded world container
## because a filter haloes the alpha-faded edges of a projectile.
##
## Draw order is child order. Nothing here sets z_index: on a CanvasItem that
## value is relative to the parent, and a stray one is what put a map layer
## over the players the last time this was a tree of nodes.

var state: RealmState
var game_data: GameData

var tiles := TileRenderer.new()
var entities := EntityRenderer.new()
var wall_tops := WallOcclusionRenderer.new()
var particles := ParticleRenderer.new()
var bullets := BulletRenderer.new()
var effects := EffectRenderer.new()
var debug := CollisionOverlay.new()

var show_collision: bool:
	get: return debug.show_collision
	set(value): debug.show_collision = value


func _ready() -> void:
	# Added in draw order: ground, what stands on it, the wall tops that must
	# cover anything behind them, what flies over all of it, then the debug
	# view. Names, bars and numbers are not here: they are UI, Controls on
	# EntityOverlay's own CanvasLayer, outside the camera.
	# Nearest on every layer, said outright rather than inherited from the
	# project default: the web export drew the zoomed world with linear
	# filtering -- every tile, sprite and name a 2x blur -- while the
	# Controls beside it, which do not zoom, stayed crisp. The desktop honours
	# the default; the world must not depend on which build honours what.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for layer in [tiles, entities, wall_tops, particles, bullets, effects, debug]:
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(layer)
	_wire()


func setup(realm_state: RealmState, content: GameData) -> void:
	state = realm_state
	game_data = content
	_wire()


## What the last frame actually drew, after culling -- the externally visible
## evidence that culling works, and what the debug HUD reports.
var draw_stats: Dictionary:
	get:
		var stats := entities.counts.duplicate()
		stats["tiles"] = tiles.drawn
		stats["feathers"] = tiles.feathers_drawn
		stats["bullets"] = bullets.drawn
		stats["particles"] = particles.drawn
		stats["effects"] = effects.drawn
		stats["wall_tops"] = wall_tops.drawn
		stats["object_shadows"] = tiles.shadows.drawn
		stats["wall_bands"] = tiles.bands.drawn
		stats["billboard_rings"] = tiles.billboards.ringed
		stats["billboard_bottoms"] = tiles.billboards.drawn
		return stats


func _process(_delta: float) -> void:
	for layer in [tiles, entities, wall_tops, particles, bullets, effects, debug]:
		layer.queue_redraw()


func _wire() -> void:
	tiles.state = state
	tiles.content = game_data
	entities.state = state
	entities.content = game_data
	wall_tops.state = state
	wall_tops.content = game_data
	particles.state = state
	bullets.state = state
	bullets.content = game_data
	effects.state = state
	debug.state = state
	debug.content = game_data
