class_name FeatherPass
extends RefCounted

## Softens the joins between different terrain types by laying each
## neighbour's faded edge over the shared boundary.
##
## Walls are skipped on both sides -- they are architectural boundaries, and
## feathering them reads as mush -- as are tiles flagged noBlend, like carpet.
## Runs over the base layer once it is drawn, before the walls on top of it.
##
## Where land meets water only the land side is drawn here, with a shore band
## (TileFeather.shore) rather than a fringe; the water's side of the same shore
## is foam and shallows, animated by liquid.gdshader. Lava is left as it always
## was: the land beside it takes the ordinary fringe, and lava itself none.

const TILE_SIZE := GameConstants.TILE_SIZE
const VOID_TILE := 0
const BASE_LAYER := 0
## Which neighbour each fringe direction reads from.
const NO_CELLS := {}
const NO_RECTS: Array = []
## EDGES as two parallel arrays, for the per-cell loop.
const DIRECTIONS := [TileFeather.NORTH, TileFeather.SOUTH, TileFeather.WEST, TileFeather.EAST]
const STEPS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## A liquid cell's diagonal steps, and the corner of the land cell there that
## faces back at it.
const DIAGONALS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const FACING_CORNERS := [TileFeather.SOUTH_EAST, TileFeather.SOUTH_WEST, TileFeather.NORTH_EAST,
	TileFeather.NORTH_WEST]
## The liquid cell's two sides between it and each diagonal, as a bit mask over
## DIRECTIONS: liquid on either means the land there has a side band already.
const DIAGONAL_SIDES := [(1 << TileFeather.NORTH) | (1 << TileFeather.WEST),
	(1 << TileFeather.NORTH) | (1 << TileFeather.EAST), (1 << TileFeather.SOUTH) | (1 << TileFeather.WEST),
	(1 << TileFeather.SOUTH) | (1 << TileFeather.EAST)]
const EDGES := {
	TileFeather.NORTH: Vector2i(0, -1),
	TileFeather.SOUTH: Vector2i(0, 1),
	TileFeather.WEST: Vector2i(-1, 0),
	TileFeather.EAST: Vector2i(1, 0),
}

var feathers := TileFeather.new()
var blending := TileBlend.new()
## Baked shore bands by (liquid id * 8 + direction) * SHORE_PERIOD + phase,
## liquid colours by id, and whether each liquid is lava.
var _shores := {}
var _colours := {}
var _lava := {}
## Fringes laid down by the last pass -- the visible evidence that seam
## blending is running and that the gates are letting the right edges through.
var drawn := 0


func paint(canvas: CanvasItem, tiles: TileMapState, content: GameData,
		first: Vector2i, last: Vector2i, own := Rect2i()) -> void:
	drawn = 0
	# Only called once the base layer has been drawn, so it exists and has
	# cells in it.
	var base: Dictionary = tiles.layers[BASE_LAYER]
	var above: Dictionary = tiles.layers.get(GameConstants.COLLISION_LAYER, NO_CELLS)
	var looks: Dictionary = content.tile_looks
	var fringe := maxf(2.0, roundf(TILE_SIZE * TileFeather.FRACTION))
	var shore_depth := float(TileFeather.SHORE_DEPTH)
	var count_all := not own.has_area()
	var by_texture := {}
	feathers.deferred = true

	for tile_x in range(first.x, last.x + 1):
		for tile_y in range(first.y, last.y + 1):
			var cell := Vector2i(tile_x, tile_y)
			var mine: int = base.get(cell, VOID_TILE)
			if mine <= VOID_TILE:
				continue
			var mine_look: Array = looks.get(mine, GameData.NO_LOOK)
			if mine_look.is_empty():
				mine_look = content.tile_look(mine)
			if mine_look[GameData.LOOK_FLAGS] & GameData.LOOK_NO_BLEND \
					or _covered(above, looks, content, cell):
				continue
			# Liquid feathers only into other liquid (deep water into shallow); its
			# shores belong to the land beside it.
			var mine_liquid: bool = mine_look[GameData.LOOK_FLAGS] & GameData.LOOK_LIQUID != 0
			if mine_liquid and _is_lava(content, mine):
				continue
			var liquid_sides := 0
			var origin := Vector2(tile_x * TILE_SIZE, tile_y * TILE_SIZE)
			for direction in DIRECTIONS:
				var beside: Vector2i = cell + STEPS[direction]
				var neighbour: int = base.get(beside, VOID_TILE)
				if neighbour <= VOID_TILE:
					continue
				if neighbour == mine:
					if mine_liquid:
						liquid_sides |= 1 << direction
					continue
				var neighbour_look: Array = looks.get(neighbour, GameData.NO_LOOK)
				if neighbour_look.is_empty():
					neighbour_look = content.tile_look(neighbour)
				var liquid_beside: bool = neighbour_look[GameData.LOOK_FLAGS] & GameData.LOOK_LIQUID != 0
				if liquid_beside:
					liquid_sides |= 1 << direction
				if neighbour_look[GameData.LOOK_FLAGS] & GameData.LOOK_NO_BLEND \
						or _covered(above, looks, content, beside):
					continue
				var texture: Texture2D = null
				var rect: Rect2
				var lava_beside := liquid_beside and _is_lava(content, neighbour)
				if lava_beside:
					if not mine_liquid and blending.blends(content, mine, neighbour):
						texture = feathers.texture(content, neighbour, direction)
						rect = TileFeather.edge_rect(origin, direction, TILE_SIZE, fringe)
				elif liquid_beside and not mine_liquid:
					var along := tile_x if direction <= TileFeather.SOUTH else tile_y
					var key: int = (neighbour * 8 + direction) * TileFeather.SHORE_PERIOD \
						+ posmod(along, TileFeather.SHORE_PERIOD)
					texture = _shores.get(key)
					if texture == null:
						texture = feathers.shore(_colour(content, neighbour), direction, along)
						_shores[key] = texture
					rect = TileFeather.edge_rect(origin, direction, TILE_SIZE, shore_depth)
				elif liquid_beside == mine_liquid and blending.blends(content, mine, neighbour):
					texture = feathers.texture(content, neighbour, direction)
					rect = TileFeather.edge_rect(origin, direction, TILE_SIZE, fringe)
				if texture != null:
					_add(by_texture, texture, rect)
					if count_all or own.has_point(cell):
						drawn += 1
			if mine_liquid and liquid_sides != 15:
				_wet_corners(by_texture, base, above, looks, content, cell, mine, liquid_sides,
					first, last, shore_depth)
	# Drawn grouped by texture, so a chunk's fringes cost a draw call per fringe
	# texture rather than one per fringe; only where two fringes overlap at a
	# corner does the order show, and only as a sliver.
	feathers.deferred = false
	TileFeather.flush()
	for texture in by_texture:
		for rect in by_texture[texture]:
			canvas.draw_texture_rect(texture, rect, false)


static func _add(by_texture: Dictionary, texture: Texture2D, rect: Rect2) -> void:
	var batch: Array = by_texture.get(texture, NO_RECTS)
	if batch.is_empty():
		batch = []
		by_texture[texture] = batch
	batch.append(rect)


## Land only diagonally beside a liquid cell still gets that corner wet, or the
## shore band breaks into a notch where it turns. Worked from the liquid's side:
## liquid is rarer than land, and this cell's sides are already known.
func _wet_corners(by_texture: Dictionary, base: Dictionary, above: Dictionary, looks: Dictionary,
		content: GameData, cell: Vector2i, liquid_id: int, liquid_sides: int,
		first: Vector2i, last: Vector2i, depth: float) -> void:
	for i in 4:
		if liquid_sides & DIAGONAL_SIDES[i]:
			continue
		var land_cell: Vector2i = cell + DIAGONALS[i]
		if land_cell.x < first.x or land_cell.x > last.x or land_cell.y < first.y or land_cell.y > last.y:
			continue
		var land: int = base.get(land_cell, VOID_TILE)
		if land <= VOID_TILE:
			continue
		var look: Array = looks.get(land, GameData.NO_LOOK)
		if look.is_empty():
			look = content.tile_look(land)
		if look[GameData.LOOK_FLAGS] & (GameData.LOOK_LIQUID | GameData.LOOK_NO_BLEND) \
				or _covered(above, looks, content, land_cell):
			continue
		var corner: int = FACING_CORNERS[i]
		var key := (liquid_id * 8 + corner) * TileFeather.SHORE_PERIOD
		var texture: Texture2D = _shores.get(key)
		if texture == null:
			texture = feathers.shore(_colour(content, liquid_id), corner, 0)
			_shores[key] = texture
		_add(by_texture, texture, TileFeather.corner_rect(
			Vector2(land_cell * TILE_SIZE), corner, TILE_SIZE, depth))


func _is_lava(content: GameData, tile_id: int) -> bool:
	if not _lava.has(tile_id):
		_lava[tile_id] = TileFeather.is_lava(blending.signature(content, tile_id))
	return _lava[tile_id]


## A liquid's average colour; blue when it has none.
func _colour(content: GameData, tile_id: int) -> Color:
	if not _colours.has(tile_id):
		var signature: Variant = blending.signature(content, tile_id)
		_colours[tile_id] = signature if signature != null else Color(0.2, 0.4, 0.8)
	return _colours[tile_id]


## Whether a wall or a solid prop stands over the cell, which stops it blending.
static func _covered(above: Dictionary, looks: Dictionary, content: GameData, cell: Vector2i) -> bool:
	var tile_id: int = above.get(cell, VOID_TILE)
	if tile_id <= VOID_TILE:
		return false
	var look: Array = looks.get(tile_id, GameData.NO_LOOK)
	if look.is_empty():
		look = content.tile_look(tile_id)
	return look[GameData.LOOK_FLAGS] & (GameData.LOOK_WALL | GameData.LOOK_COLLISION) != 0


## A tile that opts out of blending, or one hidden under a solid block above it
## (a wall or any collision tile): water under a wall must not feather into the
## bordering floor. Checking hasCollision as well as isWall catches solid wall
## blocks that aren't flagged isWall. This runs at chunk build, not per frame.
func _blocks_blending(tiles: TileMapState, content: GameData,
		tile_x: int, tile_y: int, tile_id: int) -> bool:
	if int(content.tile_data(tile_id).get("noBlend", 0)) != 0:
		return true
	var above: int = tiles.layers.get(GameConstants.COLLISION_LAYER, {}).get(
		Vector2i(tile_x, tile_y), VOID_TILE)
	if above <= VOID_TILE:
		return false
	var above_data: Dictionary = content.tile_data(above)
	return int(above_data.get("isWall", 0)) != 0 or int(above_data.get("hasCollision", 0)) != 0
