class_name LootPreviews
extends RefCounted

## A LootPreview under every loot container on screen with anything in it:
## the web client's renderLootPreviews, driven by EntityOverlay each frame.
##
## Every container, not just the one at your feet -- the web walks all of
## `gameState.lootContainers` and culls only what is well off the screen,
## so a bag across the room shows its contents before you walk to it, and
## the one you stand on shows them under it as well as in the bag panel.
## The anchor is the bag's tile's bottom-middle (the wire carries no size,
## so the web's `loot.size || tileSize` is always the tile), pushed through
## the camera and rounded. The "lootBagPreview" switch turns the lot off.

const SETTING := "loot_preview"
## How far off the screen, in screen pixels, a bag still gets its grid.
const MARGIN := 80.0

var shown := 0

var _root: Control
var _pool: ControlPool


func _init(root: Control) -> void:
	_root = root
	_pool = ControlPool.new(root, func() -> Control: return LootPreview.new())


func show_all(state: RealmState, content: GameData, to_screen: Transform2D, screen_size: Vector2) -> void:
	shown = 0
	if state != null and state.settings.is_on(SETTING):
		var on_screen := Rect2(Vector2.ZERO, screen_size).grow(MARGIN)
		for id in state.entities.containers:
			_show(id, state, content, to_screen, on_screen)
	_pool.sweep()


func size() -> int:
	return _pool.size()


func preview(id: int) -> LootPreview:
	return _pool._live.get(id)


func preview_parent() -> Control:
	return _root


static func anchor(to_screen: Transform2D, position: Vector2) -> Vector2:
	var tile := float(GameConstants.TILE_SIZE)
	return EntityOverlay.screen(to_screen, position + Vector2(tile / 2.0, tile))


func _show(id: int, state: RealmState, content: GameData, to_screen: Transform2D, on_screen: Rect2) -> void:
	var container: Dictionary = state.entities.containers[id]
	var items := LootPreview.shown_items(container.get("items", []))
	if items.is_empty():
		return
	var at := anchor(to_screen, state.entities.render_position(container))
	if not on_screen.has_point(at):
		return
	var textures := items.map(func(item: Dictionary) -> Texture2D:
		return content.item_texture(int(item.get("itemId", -1))) if content != null else null)
	var grid: LootPreview = _pool.acquire(id)
	grid.show_items(textures)
	grid.place(at)
	shown += 1
