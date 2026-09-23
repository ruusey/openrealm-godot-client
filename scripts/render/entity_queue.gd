class_name EntityQueue
extends RefCounted

## Works out what the ground pass draws this frame, and in what order.
##
## Everything standing on the ground goes into one queue, sorted on its feet
## (`pos.y + size`) so an entity lower on the screen draws in front -- wire
## positions are top-left anchored, and sorting on those would order a tall
## sprite wrongly against a short one. Both reference clients sort the same
## value. Remote entities are queued at their interpolated position; the local
## player at its predicted one, always, so the camera can never lose you.
##
## Culling happens here, so what comes back is already the visible set. Each
## entry carries everything EntityRenderer needs to draw it and nothing about
## how to draw it.

const PLAYER_RENDER_SIZE := GameConstants.PLAYER_RENDER_SIZE
const SIMPLE_SIZE := 16


## Everything the ground pass would draw this frame, in draw order.
func build(state: RealmState, content: GameData, view: Rect2) -> Array:
	var queue: Array = []
	_queue_players(queue, state, content, view)
	_queue_enemies(queue, state, content, view)
	_queue_containers(queue, state, content, view)
	_queue_portals(queue, state, content, view)

	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["pos"].y + a["size"] < b["pos"].y + b["size"])
	return queue


## How big to draw a frame, in world pixels.
##
## Usually the body cell, but an attack frame can be wider or taller than the
## cell it was sliced from -- the weapon overhangs it. Squashing that back
## into the cell is what makes a sideways swing look compressed, so the rect
## takes the frame's own ratio, exactly as both references do.
static func frame_size(texture: Texture2D, cell: int, body: float) -> Vector2:
	if texture == null or cell <= 0:
		return Vector2.ONE * body
	return texture.get_size() / float(cell) * body


func _queue_players(queue: Array, state: RealmState, content: GameData,
		view: Rect2) -> void:
	for id in state.entities.players:
		var player: Dictionary = state.entities.players[id]
		var is_local: bool = id == state.local.id
		var position: Vector2 = state.local.render_position() if is_local \
			else state.entities.render_position(player)
		if not is_local and (not view.has_point(position) or not state.settings.is_on("show_other_players")):
			continue

		var class_id: int = state.local.class_id if is_local else player.get("class_id", 0)
		var facing: String = state.local.facing if is_local else player["facing"]
		var action := "walk" if _is_moving(state, player, is_local) else "idle"
		var frame: int = (state.local.walk if is_local else player["walk"]).frame
		var mirrored: bool = state.local.facing_left if is_local else player["facing_left"]

		# A swing overrides all three: it names its own clip, it counts its own
		# frames, and it faces where the shot went rather than where the feet
		# are pointed -- which is what makes a stationary shooter turn.
		var pose: AttackPose = state.local.attack if is_local else player["attack"]
		if pose.is_active():
			action = "attack"
			facing = pose.facing
			frame = pose.frame
			mirrored = pose.facing_left
		var texture := content.classes_art.frame(class_id, action, facing, frame, int(player.get("dye_id", 0)))
		queue.append({
			"kind": "players",
			"pos": position,
			"size": PLAYER_RENDER_SIZE,
			"draw": frame_size(texture, content.classes_art.cell_size(class_id),
				PLAYER_RENDER_SIZE),
			"texture": texture,
			"tint": Color(0.4, 1.0, 0.5) if is_local else Color(0.3, 0.6, 1.0),
			"modulate": StatusTint.of(state.local.effects if is_local
				else player.get("effects", [])),
			# The sheet only has a right-facing side clip, so leftward
			# movement is that clip mirrored.
			"flip": facing == "side" and mirrored,
			# Only the player we are wades: the web client asks this of one
			# entity and of no other.
			"wading": is_local and state.tiles.wades(position, PLAYER_RENDER_SIZE),
		})


func _queue_enemies(queue: Array, state: RealmState, content: GameData, view: Rect2) -> void:
	for id in state.entities.enemies:
		var enemy: Dictionary = state.entities.enemies[id]
		var position := state.entities.render_position(enemy)
		var size := int(enemy.get("size", SIMPLE_SIZE))
		if not view.has_point(position) or Blind.hides(state, position, size):
			continue
		queue.append({
			"kind": "enemies",
			"pos": position,
			"size": size,
			"draw": Vector2.ONE * float(size),
			"texture": content.enemy_texture(enemy.get("enemy_id", -1)),
			"tint": Color(0.8, 0.25, 0.25),
			"modulate": StatusTint.of(enemy.get("effects", [])),
			"flip": false,
		})


## A portal draws a tile wide, which is what both references give it, and its
## art comes from portalId -- nothing about how it looks is on the wire. A
## portal the content does not define falls back to the block, so a missing
## definition is visible rather than an invisible doorway.
func _queue_portals(queue: Array, state: RealmState, content: GameData,
		view: Rect2) -> void:
	for id in state.entities.portals:
		var portal: Dictionary = state.entities.portals[id]
		var position := state.entities.render_position(portal)
		if not view.has_point(position):
			continue
		queue.append({"kind": "portals", "pos": position,
			"size": GameConstants.TILE_SIZE,
			"draw": Vector2.ONE * float(GameConstants.TILE_SIZE),
			"texture": content.portals.texture(int(portal.get("portal_id", -1))),
			"tint": Color(0.5, 0.35, 0.9), "flip": false,
			"modulate": StatusTint.CLEAR})


## A loot bag or chest, in LootArt's rect: a chest fills its tile, a bag
## sits in the middle at half a tile. Its "pos" and "size" are that rect's,
## so it sorts on where the bag actually stands.
func _queue_containers(queue: Array, state: RealmState, content: GameData, view: Rect2) -> void:
	for id in state.entities.containers:
		var container: Dictionary = state.entities.containers[id]
		var position := state.entities.render_position(container)
		if not view.has_point(position):
			continue
		var tier := int(container.get("tier", 0))
		var chest := bool(container.get("is_chest", false))
		var at := LootArt.rect(content, position, tier, chest)
		queue.append({"kind": "containers", "pos": at.position, "size": at.size.x,
			"draw": at.size, "texture": LootArt.texture(content, tier, chest),
			"tint": Color(0.85, 0.7, 0.3), "flip": false, "modulate": StatusTint.CLEAR})


func _is_moving(state: RealmState, player: Dictionary, is_local: bool) -> bool:
	if is_local:
		return state.local.moving
	var snapshots: Array = player.get("snaps", [])
	return not snapshots.is_empty() and snapshots[-1]["vel"].length_squared() > 0.0001
