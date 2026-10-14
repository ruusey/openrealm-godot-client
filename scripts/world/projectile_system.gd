class_name ProjectileSystem
extends RefCounted

## Every bullet in the world, simulated rather than streamed.
##
## The server sends a bullet's spawn parameters once and nothing after that,
## so this advances them locally with the same integrator the server runs.
## Locally predicted shots live in the same table under negative ids.

## Multishot Gem's gemstoneType; it adds one extra fanned bullet, which the
## prediction must include or that bullet arrives late and looks staggered.
const MULTISHOT_GEM := 3
## Hit-circle radius = size * this, for both bullet and enemy. Mirrors the
## server's GlobalConstants.HIT_RADIUS_FACTOR / circleHit so the client's
## predicted despawn lands where the server's damage does.
const HIT_RADIUS_FACTOR := 0.4
## A non-pierce bullet freezes at impact and lingers this long before the local
## fallback removes it, in case the server's Unload is slow.
const CONSUME_LINGER_MS := 50
## A LINE_SEGMENT wall is a persistent, server-authoritative hazard removed by the
## server's Unload, not by travel. The normal 10s enemy-bullet backstop is clocked
## from receipt (not the server's spawn tick) and short enough to erase a wall the
## server still keeps in our ledger and damages us with -- an invisible wall it never
## re-sends. Walls get a far longer backstop so only the Unload normally removes them,
## while a genuinely lost Unload is still swept up eventually. The server hard-caps a
## wall's life at 10s, so this never fires during a live one.
const WALL_FALLBACK_LIFETIME_MS := 30_000
const NO_TILES := {}
## Traits that take a bullet off the plain straight-line integrator.
const CURVED_MOTION := ProjectileKind.TRAIT_ORBITAL | ProjectileKind.TRAIT_PARAMETRIC \
	| ProjectileKind.TRAIT_SPINS | ProjectileKind.TRAIT_SPEED_CURVE \
	| ProjectileKind.TRAIT_HOMING | ProjectileKind.TRAIT_ANCHORED

var bullets := {}
## Round-trip time, used to fast-forward freshly received bullets.
var latency_ms := 0.0
## A smoothed round-trip, so a single RTT spike can't teleport a just-loaded
## bullet a quarter-second forward in one frame (a visible spawn jump).
var _catchup_latency := 0.0

var _player: LocalPlayer
var _content: GameData
var _clock: Callable
var _shot_counter := 0
## Live local predictions (id -> bullet), the only bullets a server copy can claim
## or an Unload can reach through server_id; kept so neither scans every bullet.
var _predictions := {}
## tile id -> whether it stops a bullet, once the content has loaded.
var _tile_stops := {}
## Scratch lists reused every frame: what advance() drops, and the own shots that
## hit prediction tests.
var _dropped: Array = []
var _own_live: Array[Dictionary] = []
## Client-side hit prediction is O(own-bullets x enemies); it only consumes a
## non-pierce shot a few ms before the server's Unload, so on the web renderer we
## run it every 3rd frame instead of every frame. Native runs it every frame.
var _web := OS.has_feature("web")
var _predict_frame := 0
## Homing and anchored bullets steer toward / stick to an entity, so the
## simulation needs the roster. Optional: a system built without one simply
## leaves those bullets flying straight.
var _entities: EntityRegistry
## Terrain, for the wall/prop collision test. Optional: without it bullets don't
## predict terrain hits and fall back to waiting on the server's Unload.
var _tiles: TileMapState


func _init(player: LocalPlayer, content: GameData,
		clock: Callable = func() -> int: return Time.get_ticks_msec(),
		entities: EntityRegistry = null, tiles: TileMapState = null) -> void:
	_player = player
	_content = content
	_clock = clock
	_entities = entities
	_tiles = tiles


func clear() -> void:
	bullets.clear()
	_predictions.clear()


## A locally predicted bullet, registered so its server copy can claim it.
func add_prediction(local_id: int, bullet: Dictionary) -> void:
	bullets[local_id] = bullet
	_predictions[local_id] = bullet


## Adopts the bullets in a LoadPacket, skipping any we already drew locally.
func apply_load(data: Dictionary) -> void:
	var now: int = _clock.call()
	# EMA the round-trip before it drives catch-up, so a lag spike doesn't jerk a
	# freshly loaded bullet forward.
	_catchup_latency = _catchup_latency * 0.8 + latency_ms * 0.2
	for wire in data.get("bullets", []):
		var id := int(wire.get("id", 0))
		if bullets.has(id):
			continue
		if not _predictions.is_empty() and ShotPredictor.claim(_predictions, wire, id, _player.id):
			# Already on screen as a prediction; adopting the server copy too
			# would draw the same bullet twice.
			continue
		var bullet := Projectile.from_wire(wire, now)
		if _entities != null and ProjectileKind.is_anchored(bullet):
			ProjectileTracking.capture_anchor(bullet, _entities, _player)
		ProjectileMotion.catch_up(bullet, _catchup_latency * 0.5)
		bullets[id] = bullet
		_note_shooter(wire)


## A bullet carries the id of whoever fired it, which is the only way a
## remote player's swing is knowable -- no packet announces one. The local
## player starts its own pose on input, so its own shots coming back from the
## server must not restart it mid-swing.
func _note_shooter(wire: Dictionary) -> void:
	if _entities == null:
		return
	var source := int(wire.get("srcEntityId", 0))
	if source == 0 or source == _player.id:
		return
	var angle := float(wire.get("angle", 0.0))
	# The shooter is a remote player OR an enemy -- note_attack no-ops on the dict
	# that doesn't hold the id, so try both and the right one plays its swing.
	RemoteAnimation.note_attack(_entities.players, source, angle)
	RemoteAnimation.note_attack(_entities.enemies, source, angle)
	# A remote player's swing is audible too (not the bullet-hell of enemies); the
	# shot origin places it. Sfx throttles a multishot volley down to one sound.
	if _entities.players.has(source):
		var pos: Dictionary = wire.get("pos", {})
		Sfx.remote_attack(source, Vector2(pos.get("x", 0.0), pos.get("y", 0.0)))


func apply_unload(data: Dictionary) -> void:
	var ids: Array = data.get("bullets", [])
	if ids.is_empty():
		return
	var gone := {}
	for value in ids:
		var id := int(value)
		bullets.erase(id)
		gone[id] = true
	# A prediction that claimed one of these server bullets goes with it.
	for local_id in _predictions.keys():
		if gone.has(int(_predictions[local_id].get("server_id", 0))) or not bullets.has(local_id):
			bullets.erase(local_id)
			_predictions.erase(local_id)


## Advances every bullet by one frame and drops the expired ones.
##
## The hottest loop in the client: what each bullet is gets read off its cached
## traits, and dropped ids are erased after the walk instead of iterating a
## copied key list.
func advance(delta: float) -> void:
	if bullets.is_empty():
		return
	var bullet_scale := delta * GameConstants.TICK_RATE
	var now: int = _clock.call()
	var tracking := _entities != null
	var solid := _solid_layer()
	_dropped.clear()
	_own_live.clear()
	for id in bullets:
		var bullet: Dictionary = bullets[id]
		# Cross-script static calls cost ten dictionary reads in GDScript, so the
		# cached traits are read here directly and resolved only on first sight.
		var traits: int = bullet.get("traits", -1)
		if traits < 0 or not traits & ProjectileKind.TRAIT_OWNER_RESOLVED:
			traits = _resolve_traits(bullet)
		# A non-pierce bullet that predicted a hit is frozen at the impact point
		# (not flying through the enemy) and lingers briefly before the local
		# fallback removes it; the server's Unload normally removes it first.
		if traits & ProjectileKind.TRAIT_CONSUMED:
			if now - int(bullet.get("consumed_at", now)) > CONSUME_LINGER_MS:
				_dropped.append(id)
			continue
		if traits & CURVED_MOTION == 0:
			# ProjectileMotion.straight, inlined: most of a bullet hell is plain shots.
			var step_size: float = bullet["magnitude"] * bullet_scale
			var angle: float = bullet["angle"]
			bullet["pos"] += Vector2(sin(angle) * step_size, cos(angle) * step_size)
			bullet["traveled"] += absf(step_size)
		else:
			# Order matches the server tick: steer, integrate, then re-anchor.
			if tracking and traits & ProjectileKind.TRAIT_HOMING:
				ProjectileTracking.steer(bullet, _entities, _player, bullet_scale)
			ProjectileMotion.step(bullet, bullet_scale, now)
			if tracking and traits & ProjectileKind.TRAIT_ANCHORED:
				ProjectileTracking.anchor(bullet, _entities, _player)
		# _should_drop_locally, inlined for everything but a LINE_SEGMENT wall.
		var drop := false
		if traits & ProjectileKind.TRAIT_LINE_SEGMENT:
			drop = _should_drop_locally(bullet, traits, now, solid)
		else:
			if traits & ProjectileKind.TRAIT_STOPS_AT_WALLS and not solid.is_empty():
				var half := float(bullet.get("size", 4)) * 0.5
				var pos: Vector2 = bullet["pos"]
				var tile_id: int = solid.get(Vector2i(floori((pos.x + half) / GameConstants.TILE_SIZE),
					floori((pos.y + half) / GameConstants.TILE_SIZE)), -1)
				drop = tile_id > 0 and _in_wall(bullet, traits, solid)
			if not drop:
				drop = (now - int(bullet.get("created_ms", now))) > ProjectileMotion.MAX_LIFETIME_MS \
					or (traits & ProjectileKind.TRAIT_OWN and bullet["traveled"] > bullet["range"])
		if drop:
			_dropped.append(id)
		elif traits & ProjectileKind.TRAIT_OWN \
				and not traits & (ProjectileKind.TRAIT_PIERCES | ProjectileKind.TRAIT_HOMING):
			_own_live.append(bullet)
	for id in _dropped:
		bullets.erase(id)
		_predictions.erase(id)
	if _own_live.is_empty():
		return
	if _web:
		_predict_frame = (_predict_frame + 1) % 3
		if _predict_frame == 0:
			_predict_hits(now)
	else:
		_predict_hits(now)


## Whether to drop a bullet from the local table on our own, WITHOUT a server Unload.
## Our OWN shots (local predictions, or player-flagged copies) are predicted for snappy
## feedback: they expire at max range and stop at walls locally. ENEMY shots are
## server-authoritative: the client removes them only on a wall hit (which the server
## mirrors exactly) or the Unload, so it can never hide a bullet the server keeps flying
## into us (that was the "die to an invisible projectile" bug: client-side range/lifetime
## GUESSES dropped an enemy bullet the server kept alive -- terrain is not a guess). A hard
## 10s lifetime cap stays as a backstop for the rare case an Unload is never delivered.
func _should_drop_locally(bullet: Dictionary, traits: int, now: int, solid: Dictionary) -> bool:
	# A LINE_SEGMENT beam/wall is server-authoritative no matter who fired it -- removed by
	# the server's Unload, with the long cap only as a backstop. It must NOT take the
	# own-shot path below: a stationary beam never expires by range, so a player's own beam
	# would otherwise sit on screen for the full MAX_LIFETIME instead of clearing on Unload.
	if traits & ProjectileKind.TRAIT_LINE_SEGMENT:
		return (now - int(bullet.get("created_ms", now))) > WALL_FALLBACK_LIFETIME_MS
	if traits & ProjectileKind.TRAIT_OWN:
		return bullet["traveled"] > bullet["range"] \
			or (now - int(bullet.get("created_ms", now))) > ProjectileMotion.MAX_LIFETIME_MS \
			or _in_wall(bullet, traits, solid)
	# Enemy shots are server-authoritative, but a wall stops them on the server too
	# (proccessTerrainHit), so mirroring that ONE rule client-side is safe: the bullet the
	# server keeps flying is one that did not hit a wall, which _in_wall leaves alone.
	if _in_wall(bullet, traits, solid):
		return true
	return (now - int(bullet.get("created_ms", now))) > ProjectileMotion.MAX_LIFETIME_MS


## A bullet WE are responsible for: our own local prediction, or one the server attributes
## to us. NEVER keyed on the id's sign -- server bullet ids are random longs that are often
## negative, so an enemy bullet routinely has a negative id and must not be taken for ours.
## A Codex ally bolt carries the owner's id for kill credit, which would read as ours,
## but it's server-authoritative, not a local prediction, so it is never culled, claimed
## or hit-predicted here.
## The bullet's traits plus whether it is ours, which depends on who we are and so
## is resolved here rather than in ProjectileKind.
func _resolve_traits(bullet: Dictionary) -> int:
	var traits := ProjectileKind.traits(bullet) | ProjectileKind.TRAIT_OWNER_RESOLVED
	if _is_own_shot(bullet, traits):
		traits |= ProjectileKind.TRAIT_OWN
	if bool(bullet.get("consumed", false)):
		traits |= ProjectileKind.TRAIT_CONSUMED
	if traits & ProjectileKind.TRAIT_PREDICTED:
		_predictions[int(bullet.get("id", 0))] = bullet
	bullet["traits"] = traits
	return traits


func _is_own_shot(bullet: Dictionary, traits: int) -> bool:
	if traits & ProjectileKind.TRAIT_ALLY:
		return false
	return traits & (ProjectileKind.TRAIT_PREDICTED | ProjectileKind.TRAIT_PLAYER_SHOT) != 0 \
		or int(bullet.get("src_entity_id", 0)) == _player.id


## The collision layer this frame, or an empty table when there is no terrain to test.
func _solid_layer() -> Dictionary:
	if _tiles == null or _content == null:
		return NO_TILES
	return _tiles.layers.get(GameConstants.COLLISION_LAYER, NO_TILES)


## Mirrors the server's proccessTerrainHit: a bullet that isn't PASS_THROUGH_TERRAIN
## dies the instant its centre enters a collision-layer tile that has collision (a
## wall or a solid prop like a tree). Removed locally so a shot stops at the wall
## instead of sailing through it until the server's Unload arrives a round-trip later.
func _in_wall(bullet: Dictionary, traits: int, solid: Dictionary) -> bool:
	if not traits & ProjectileKind.TRAIT_STOPS_AT_WALLS or solid.is_empty():
		return false
	var half := float(bullet.get("size", 4)) * 0.5
	var pos: Vector2 = bullet["pos"]
	var tile_id: int = solid.get(Vector2i(floori((pos.x + half) / GameConstants.TILE_SIZE),
		floori((pos.y + half) / GameConstants.TILE_SIZE)), -1)
	if tile_id <= 0:
		return false
	var stops: Variant = _tile_stops.get(tile_id)
	if stops == null:
		stops = _content.tile_has_collision(tile_id)
		if _content.ready:
			_tile_stops[tile_id] = stops
	return stops


## Client-side predicted bullet-vs-enemy hits for our own non-pierce shots, mirroring
## the server's circleHit and the web client. It ONLY freezes a bullet at impact so it
## stops on the first enemy instead of visually piercing -- damage, HP and despawn stay
## server-authoritative. Runs over the own shots advance() collected, against each
## enemy's centre and reach snapshotted once.
func _predict_hits(now: int) -> void:
	if _entities == null or _entities.enemies.is_empty():
		return
	var enemy_centres := PackedVector2Array()
	var enemy_reaches := PackedFloat32Array()
	for enemy_id in _entities.enemies:
		var enemy: Dictionary = _entities.enemies[enemy_id]
		var enemy_size := float(enemy.get("size", GameConstants.TILE_SIZE))
		enemy_centres.append(_entities.render_position(enemy) + Vector2(enemy_size, enemy_size) * 0.5)
		enemy_reaches.append(enemy_size * HIT_RADIUS_FACTOR)
	var enemy_count := enemy_centres.size()
	for bullet in _own_live:
		var size := float(bullet.get("size", 4))
		var radius := size * HIT_RADIUS_FACTOR
		var centre: Vector2 = bullet["pos"] + Vector2(size, size) * 0.5
		for i in enemy_count:
			var reach := radius + enemy_reaches[i]
			if centre.distance_squared_to(enemy_centres[i]) < reach * reach:
				bullet["consumed"] = true
				bullet["consumed_at"] = now
				bullet["traits"] = int(bullet["traits"]) | ProjectileKind.TRAIT_CONSUMED
				break


## The projectile group a basic attack fires. The equipped item carries it on
## the wire; content is the fallback for an item sent without damage data.
func weapon_projectile_group() -> int:
	var weapon := _player.equipped_weapon()
	if weapon.is_empty():
		return 0
	var group_id := int(weapon.get("damage", {}).get("projectileGroupId", 0))
	if group_id == 0 and _content != null:
		group_id = _content.item_projectile_group(int(weapon.get("itemId", -1)))
	return group_id


## One counter for every predicted shot, weapon or ability, so their local
## ids never collide.
func claim_shot_number() -> int:
	_shot_counter += 1
	return _shot_counter


## Fires a basic attack at a world point, spawning predicted bullets straight
## away -- except for a melee weapon, whose swing is an invisible server-side
## AoE with nothing travelling to predict: the wielder's swing animation is
## the whole of it, as in the web client. Returns the PlayerShootPacket
## payload, or {} when there is nothing to fire.
func fire_basic_attack(target: Vector2) -> Dictionary:
	if not _player.is_present() or _content == null:
		return {}
	var group_id := weapon_projectile_group()
	if group_id == 0:
		return {}
	var definitions := _content.projectiles_in_group(group_id)
	if definitions.is_empty():
		return {}

	var centre := _player.centre()
	var base_angle := ProjectileAngle.aim(centre, target)
	var shot := claim_shot_number()
	_player.face_toward(target - centre)
	_player.attack.begin(target - centre)

	var weapon := _player.equipped_weapon()
	var archetype := _content.archetype_for_item(int(weapon.get("itemId", -1)))
	# Match the server's bullet count: a Multishot Gem adds one more.
	var extra := 1 if int(weapon.get("gemstoneType", 0)) == MULTISHOT_GEM else 0
	# A LINE_SEGMENT beam is a stationary, server-authoritative hazard, like an enemy
	# beam -- never locally predicted. A predicted copy drew a SECOND beam along the
	# client's aim angle, a quarter turn off the server's segment axis, and because a
	# stationary bullet never expires by range it lingered for the full MAX_LIFETIME.
	# Draw only the server's copy, removed by its Unload, exactly as enemy beams are.
	var is_beam := definitions.any(func(d: Dictionary) -> bool:
		return ProjectileKind.has_flag(d, ProjectileKind.LINE_SEGMENT))
	# Origin is the body centre (matches the server's getCenteredPosition), so a
	# resized player (/size) still fires from the middle of the sprite rather than
	# its top-left corner.
	if not bool(archetype.get("melee", false)) and not is_beam:
		var predicted := ShotPredictor.build(shot, group_id, definitions,
			base_angle, centre, archetype, _clock.call(), extra)
		bullets.merge(predicted)
		_predictions.merge(predicted)

	return {
		"projectileId": shot,
		"projectileGroupId": group_id,
		"destX": target.x,
		"destY": target.y,
		"srcX": centre.x,
		"srcY": centre.y,
	}
