class_name EntityOverlay
extends CanvasLayer

## The UI pinned to the world: every character's tag (name, bars, chips,
## bubble), the portal captions, the combat numbers, the grid of what each
## loot bag holds (LootPreviews), and the dark around a blinded player
## (BlindVignette).
##
## Godot Controls, not draw calls, because they are UI -- the house rule --
## and because a Label keeps its shaped text and only moves, where a string
## redrawn inside the zoomed world was re-laid out at a new fraction of a
## pixel every frame and wobbled. Kept on a CanvasLayer of its own outside
## the camera, exactly the web client's `uiLayer`, so the text is its own
## size at the web client's sizes. Every anchor is a world position pushed
## through the camera's transform and rounded -- `worldToScreen` and
## `Math.round` -- and the Controls are pooled by entity, acquired each
## frame and freed when nothing acquired them, as the web client pools its
## PIXI.Text.

const LOCAL_NAME := Color(0.6, 1.0, 0.6)

var state: RealmState
var content: GameData
## What the last frame showed, after culling.
var chips := 0
var bubbles := 0
var previews: int:
	get: return _loot.shown
var captions: int:
	get: return _labels.captions
var texts: int:
	get: return _labels.texts

var _root: Control
var _tags: ControlPool
var _labels: FloatingLabels
var _loot: LootPreviews
var _vignette: BlindVignette


func setup(realm_state: RealmState, game_data: GameData = null) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_tags = ControlPool.new(_root, func() -> Control: return EntityTag.new())
	_labels = FloatingLabels.new(_root)
	# Over the names and numbers, under the dark: where the web keeps it.
	var loot_root := Control.new()
	loot_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	loot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loot_root)
	_loot = LootPreviews.new(loot_root)
	# Last, so it darkens the names and bars too, as the web's tops its uiLayer.
	_vignette = BlindVignette.new()
	add_child(_vignette)


func _process(_delta: float) -> void:
	refresh()


## Split out so a test can drive a frame without waiting for one.
func refresh() -> void:
	chips = 0
	bubbles = 0
	var to_screen := get_viewport().get_canvas_transform()
	var view := ViewRect.of(_root)
	if state != null:
		_show_players(to_screen, view)
		_show_enemies(to_screen, view)
	_tags.sweep()
	_labels.show_all(state, to_screen, view)
	_loot.show_all(state, content, to_screen, _root.size)
	_vignette.follow(state, to_screen, _root.size)


## A world point on the pixel it lands on.
static func screen(to_screen: Transform2D, world: Vector2) -> Vector2:
	return (to_screen * world).round()


func tag_count() -> int:
	return _tags.size()


func _show_players(to_screen: Transform2D, view: Rect2) -> void:
	var size := float(GameConstants.PLAYER_RENDER_SIZE) * to_screen.get_scale().x
	var local := state.local
	var on: GameSettings = state.settings
	for id in state.entities.players:
		var player: Dictionary = state.entities.players[id]
		var is_local: bool = id == local.id
		var position: Vector2 = local.render_position() if is_local \
			else state.entities.render_position(player)
		if not is_local and (not view.has_point(position) or not on.is_on("show_other_players")):
			continue
		var label: String = player.get("name", "")
		if is_local and label == "":
			label = local.name
		var chips_on := on.is_on("show_status_chips")
		var tag: EntityTag = _tags.acquire(["player", id])
		tag.show_player(screen(to_screen, position), size, label if on.is_on("show_names") else "",
			NameColours.over_head(String(player.get("chat_role", "")), is_local, LOCAL_NAME),
			local.health if is_local else int(player.get("health", 0)),
			int(local.stats.get("hp", 0)) if is_local else int(player.get("max_health", 0)),
			local.mana if is_local else int(player.get("mana", 0)),
			int(local.stats.get("mp", 0)) if is_local else int(player.get("max_mana", 0)),
			(local.effects if is_local else player.get("effects", [])) if chips_on else [],
			(local.effect_stacks if is_local else player.get("effect_stacks", [])) if chips_on else [],
			state.bubbles.over(label) if on.is_on("show_chat_bubbles") else {}, int(player.get("stars", 0)))
		chips += tag.chip_count()
		if tag.has_bubble():
			bubbles += 1


func _show_enemies(to_screen: Transform2D, view: Rect2) -> void:
	var zoom := to_screen.get_scale().x
	for id in state.entities.enemies:
		var enemy: Dictionary = state.entities.enemies[id]
		var position := state.entities.render_position(enemy)
		if not view.has_point(position) or Blind.hides(state, position, float(enemy.get("size", 16))):
			continue
		var maximum: int = maxi(enemy.get("max_health", 1), 1)
		var tag: EntityTag = _tags.acquire(["enemy", id])
		tag.show_enemy(screen(to_screen, position), float(enemy.get("size", 16)) * zoom,
			enemy.get("health", maximum), maximum,
			enemy.get("effects", []) if state.settings.is_on("show_status_chips") else [], enemy.get("effect_stacks", []))
		chips += tag.chip_count()
