extends SceneTree

## Walks to a nexus shop tile, uses it, and waits for the server to open it.
##
## The unit suite proves what F sends; this proves the server answers. The
## nexus keeps a Fame Store tile (301) and a Forge (300) on its floor, so a
## fresh login can reach one under real prediction: the client scans the
## streamed map for the tile, walks into reach, sends InteractTilePacket, and
## waits for the OpenFameStorePacket that names the account's balance.
##
##   godot --path . --script tests/visual/live_shop.gd -- \
##     <host> <data_port> <email> <password> <character_uuid> <out_dir> [ws] [forge|market]
##
## The fame store by default; a trailing "forge" walks to the Forge tile and
## waits for OpenForgePacket instead.
##
## Exit codes: 0 the store opened, 1 it did not, 2 bad arguments, 3 no fame
## store tile in the realm we landed in.

const LOGIN_TIMEOUT := 20.0
const LOAD_TIMEOUT := 20.0
const WALK_TIMEOUT := 60.0
const OPEN_TIMEOUT := 8.0
const FAME_STORE_TILE := 301
const FORGE_TILE := 300
const EXCHANGE_TILE := 417

var _drive: LiveDriver


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: <host> <data_port> <email> <password> <character> <out_dir> [ws]")
		quit(2)
		return

	_drive = LiveDriver.new(self, args[5])
	await _drive.boot(LiveDriver.config_from(args))
	var main := _drive.main
	var state: RealmState = main.state

	if not await _drive.wait(LOGIN_TIMEOUT, func() -> bool: return main.client.is_in_game()):
		push_error("never reached in-game; client state = %d" % main.client.state)
		quit(1)
		return
	if not await _drive.wait(LOAD_TIMEOUT, func() -> bool: return state.tiles.tile_count() > 300):
		push_error("the map never streamed in")
		quit(1)
		return
	await _drive.settle(1.0)

	var forge: bool = args.size() > 7 and args[7] == "forge"
	var exchange: bool = args.size() > 7 and args[7] == "market"
	var what := "forge" if forge else ("exchange market" if exchange else "fame store")
	var tile := _nearest_tile(state, FORGE_TILE if forge else (EXCHANGE_TILE if exchange else FAME_STORE_TILE))
	if tile.x < 0:
		push_error("no %s tile in realm %d map %d" % [what, state.tiles.realm_id, state.tiles.map_id])
		quit(3)
		return
	# Stop a tile and a half short of the centre: inside the three-tile reach,
	# outside the tile itself, which has collision. Any side will do, nearest
	# first, since a tile against furniture cannot be reached from below.
	print("walking from %s to the %s at tile %s" % [state.local.position, what, tile])
	var reached := false
	for side in _approaches(state, tile):
		if await _drive.walk_to(side, 12.0, WALK_TIMEOUT / 4.0):
			reached = true
			break
		print("  could not reach %s; trying another side" % side)
	if not reached:
		push_error("never reached the %s from any side" % what)
		quit(1)
		return
	await _drive.settle(0.5)
	_drive.capture("shop_prompt")

	if not main.shop.interact_nearby():
		push_error("nothing in reach after all: candidate %s" % main.shop.candidate())
		quit(1)
		return
	if not await _drive.wait(OPEN_TIMEOUT, func() -> bool:
			return state.forge.is_open if forge else (state.market.is_open if exchange else state.fame.is_open)):
		push_error("the server never opened the %s" % what)
		quit(1)
		return
	await _drive.settle(0.5)
	if forge:
		print("forge open; the panel says: %s" % main.screens.forge._status.text)
	elif exchange:
		print("exchange market open; %d stacks to give: %s" % [main.screens.market._rows["give"].size(),
			main.screens.market._rows["give"].map(func(r: Dictionary) -> int: return r["item_id"])])
	else:
		print("fame store open, balance %d, %d rows" % [state.fame.balance, main.screens.fame._rows.size()])
	_drive.capture("forge_open" if forge else ("market_open" if exchange else "shop_open"))
	quit(0)


## The four points a tile and a half from the tile's centre, nearest first.
func _approaches(state: RealmState, tile: Vector2i) -> Array:
	var centre := Vector2(tile.x + 0.5, tile.y + 0.5) * GameConstants.TILE_SIZE
	var points: Array = []
	for offset in [Vector2(0, 1.4), Vector2(0, -1.4), Vector2(1.4, 0), Vector2(-1.4, 0)]:
		points.append(centre + offset * GameConstants.TILE_SIZE)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return state.local.position.distance_to(a) < state.local.position.distance_to(b))
	return points


## The closest cell carrying `tile_id` on either layer, or (-1, -1).
func _nearest_tile(state: RealmState, tile_id: int) -> Vector2i:
	var found := Vector2i(-1, -1)
	var best := INF
	for layer in state.tiles.layers:
		for cell in state.tiles.layers[layer]:
			if state.tiles.layers[layer][cell] != tile_id:
				continue
			var d := state.local.position.distance_to(Vector2(cell) * GameConstants.TILE_SIZE)
			if d < best:
				best = d
				found = cell
	return found
