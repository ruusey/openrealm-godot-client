class_name HallTiles
extends RefCounted

## The stone hall itself: a wall of brick fronts along the top, its top
## face on the first row, and a floor of stone with the odd accent tile,
## every cell lit by whatever flames are near it.

## 8px art at 4x: what the world draws at on a 2x display.
const TILE := 32
const WALL_ROWS := 7
const ACCENT_ODDS := 0.15
const AMBIENT := Color(0.16, 0.16, 0.26)
const WARM := Color(1.0, 0.68, 0.32)
const LIGHT_RADIUS := 360.0

## Which tiles the hall is built from: a tall stone wall, a stone floor
## and its accent. Content ids, replaceable for a test's fixture.
var wall_tile := 64
var floor_tile := 37
var floor_accent := 38
## Rolled once per cell, so the floor's accents do not shimmer.
var _accents := {}
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	_rng.seed = seed_value


## Paints the hall over `size`, lit by `lights` ([{at, strength}]), and
## says how many cells it drew.
func paint(canvas: CanvasItem, content: GameData, size: Vector2, lights: Array) -> int:
	if content == null:
		return 0
	var front := front_face(content.tile_texture(wall_tile))
	var top := content.tile_top_face(wall_tile)
	var floor := content.tile_texture(floor_tile)
	var accent := content.tile_texture(floor_accent)
	var rows := ceili(size.y / TILE)
	var columns := ceili(size.x / TILE)
	var painted := 0
	for row in rows:
		for column in columns:
			var texture: Texture2D = (top if row == 0 else front) if row < WALL_ROWS \
				else (accent if _accent(Vector2i(column, row)) else floor)
			if texture == null:
				continue
			var cell := Rect2(column * TILE, row * TILE, TILE, TILE)
			canvas.draw_texture_rect(texture, cell, false, TorchFlame.light(cell.get_center(),
				AMBIENT, float(row) / rows, lights, WARM, LIGHT_RADIUS))
			painted += 1
	return painted


func _accent(cell: Vector2i) -> bool:
	if not _accents.has(cell):
		_accents[cell] = _rng.randf() < ACCENT_ODDS
	return _accents[cell]


## Wall art is 8x16, the top face over the front; the hall shows fronts.
static func front_face(wall: AtlasTexture) -> AtlasTexture:
	if wall == null or wall.region.size.y < 16.0:
		return wall
	var front := AtlasTexture.new()
	front.atlas = wall.atlas
	front.region = Rect2(wall.region.position + Vector2(0.0, 8.0), Vector2(wall.region.size.x, 8.0))
	return front
