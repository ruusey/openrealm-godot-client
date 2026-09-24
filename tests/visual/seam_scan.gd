extends SceneTree

## Looks for a line of background between ground chunks.
##
## A chunk's clip is cut in whole screen pixels. At a fractional scale --
## a browser's UI 2x over world 1.25x -- with a chunk border on a half
## pixel, which an odd window height puts it on, two clips cut edge to edge
## could both round away from the border and leave a one-pixel line of
## background across the map: 23 frames in 100 at 1920x961 before
## GroundChunk.OVERLAP. The goldens cannot see it: they are made at 1x in
## an even window. This lays solid floor over a block of chunks, draws it at
## the given scale from a hundred seeded camera positions, and counts dark
## pixels in every row and every column.
##
##   godot --path . --resolution 1920x961 --script tests/visual/seam_scan.gd -- [canvas_scale] [camera_zoom]
##
## Windowed only (headless has no pixels). Exit 0 clean, 1 a line showed.

const FRAMES := 100
const DARK := 0.03


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var canvas := float(args[0]) if args.size() > 0 else 2.0
	var zoom := float(args[1]) if args.size() > 1 else 1.25
	var content := GameData.new()
	if not await content.load_from(FileContentSource.new(ClientConfig.new().resolved_data_root())):
		push_error("no content")
		quit(1)
		return
	var state := RealmState.new(content, func() -> int: return 0)
	var tiles: Array = []
	for x in range(-40, 40):
		for y in range(-30, 30):
			tiles.append({"tileId": 1, "layer": 0, "xIndex": y, "yIndex": x})
	state.apply_packet("LoadMapPacket", {"realmId": 1, "mapId": 1, "tiles": tiles})
	root.content_scale_size = root.size
	root.content_scale_factor = canvas
	RenderingServer.set_default_clear_color(Color.BLACK)
	var world := WorldRenderer.new()
	world.setup(state, content)
	root.add_child(world)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * zoom
	root.add_child(camera)
	camera.make_current()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var showed := 0
	var worst := 0
	for frame in FRAMES:
		camera.position = Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0))
		for i in 3:
			await process_frame
		var dark := _dark_pixels(root.get_texture().get_image())
		worst = maxi(worst, dark)
		showed += 1 if dark > 0 else 0
	print("[seam] %s at canvas %sx, camera %sx: a line in %d of %d frames, worst %d dark pixels" % [
		root.size, canvas, zoom, showed, FRAMES, worst])
	quit(0 if showed == 0 else 1)


## Every row at a sparse stride catches a horizontal line; every column, a
## vertical one.
static func _dark_pixels(image: Image) -> int:
	var dark := 0
	for y in image.get_height():
		for x in range(0, image.get_width(), 16):
			dark += 1 if image.get_pixel(x, y).get_luminance() < DARK else 0
	for x in image.get_width():
		for y in range(0, image.get_height(), 16):
			dark += 1 if image.get_pixel(x, y).get_luminance() < DARK else 0
	return dark
