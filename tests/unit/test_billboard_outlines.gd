extends GutTest

## The silhouette around the props and decorations on the collision layer:
## a ring behind each as it is drawn, and its lower edge stamped again over
## every tile layer, as both reference clients do it.

var data: GameData
var state: RealmState
var renderer: WorldRenderer


func before_each():
	data = GameData.new()
	await data.load_from(FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir")))
	state = RealmState.new(data, func() -> int: return 0)
	renderer = WorldRenderer.new()
	renderer.setup(state, data)
	add_child_autofree(renderer)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	camera.position = Vector2(80, 80)


func after_each():
	SpriteOutline.enabled = true


## Fixture tile 1 is grass, 2 a square wall, 6 a tall one, 9 an anvil (a
## prop), 5 a tile with no art. Grass on the collision layer is decoration.
func _render(props: Array) -> void:
	var tiles: Array = []
	for x in range(0, 6):
		for y in range(0, 6):
			tiles.append(WireHelper.tile(1, 0, x, y))
	for prop in props:
		tiles.append(WireHelper.tile(prop[2], 1, prop[0], prop[1]))
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapWidth": 6, "mapHeight": 6, "tiles": tiles})
	renderer.queue_redraw()
	await wait_process_frames(2)


func test_props_and_decorations_are_billboards_and_walls_are_not():
	assert_true(BillboardOutlines.is_billboard(data, 9), "a prop")
	assert_true(BillboardOutlines.is_billboard(data, 1), "decoration: no collision, not a wall")
	assert_false(BillboardOutlines.is_billboard(data, 2), "a square wall gets bands instead")
	assert_false(BillboardOutlines.is_billboard(data, 6), "a tall wall has its own face")
	assert_false(BillboardOutlines.is_billboard(data, 0), "void")


func test_every_billboard_in_view_is_ringed_and_its_bottom_restamped():
	await _render([[1, 1, 9], [1, 2, 9], [3, 3, 1], [4, 1, 2], [4, 3, 6]])
	assert_eq(renderer.draw_stats["billboard_rings"], 3, "two anvils, one decoration; no walls")
	assert_eq(renderer.draw_stats["billboard_bottoms"], 3)


func test_terrain_alone_has_no_billboards():
	await _render([])
	assert_eq(renderer.draw_stats["billboard_rings"], 0)
	assert_eq(renderer.draw_stats["billboard_bottoms"], 0)


func test_a_billboard_without_art_goes_bare():
	await _render([[2, 2, 5]])
	assert_eq(renderer.draw_stats["billboard_rings"], 0, "no silhouette to ring on a placeholder block")
	assert_eq(renderer.draw_stats["billboard_bottoms"], 0)


func test_the_counts_are_per_frame():
	await _render([[1, 1, 9]])
	renderer.queue_redraw()
	await wait_process_frames(2)
	assert_eq(renderer.draw_stats["billboard_rings"], 1, "not the sum of every frame so far")


func test_a_billboard_out_of_view_is_culled():
	await _render([[1, 1, 9]])
	state.apply_packet("LoadMapPacket", {"realmId": 1, "tiles": [WireHelper.tile(9, 1, 4000, 4000)]})
	renderer.queue_redraw()
	await wait_process_frames(2)
	assert_eq(renderer.draw_stats["billboard_bottoms"], 1, "only the one near the camera")


func test_the_outline_option_leaves_the_map_alone():
	# Both references gate only entities and shots on it; the tiles' strokes
	# are part of the map.
	SpriteOutline.enabled = false
	await _render([[1, 1, 9]])
	assert_eq(renderer.draw_stats["billboard_rings"], 1)
	assert_eq(renderer.draw_stats["billboard_bottoms"], 1)

