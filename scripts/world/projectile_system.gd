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

var bullets := {}
## Round-trip time, used to fast-forward freshly received bullets.
var latency_ms := 0.0

var _player: LocalPlayer
var _content: GameData
var _clock: Callable
var _shot_counter := 0
## Homing and anchored bullets steer toward / stick to an entity, so the
## simulation needs the roster. Optional: a system built without one simply
## leaves those bullets flying straight.
var _entities: EntityRegistry


func _init(player: LocalPlayer, content: GameData,
		clock: Callable = func() -> int: return Time.get_ticks_msec(),
		entities: EntityRegistry = null) -> void:
	_player = player
	_content = content
	_clock = clock
	_entities = entities


func clear() -> void:
	bullets.clear()


## Adopts the bullets in a LoadPacket, skipping any we already drew locally.
func apply_load(data: Dictionary) -> void:
	var now: int = _clock.call()
	for wire in data.get("bullets", []):
		var id := int(wire.get("id", 0))
		if bullets.has(id):
			continue
		if ShotPredictor.claim(bullets, wire, id, _player.id):
			# Already on screen as a prediction; adopting the server copy too
			# would draw the same bullet twice.
			continue
		var bullet := Projectile.from_wire(wire, now)
		if _entities != null and ProjectileKind.is_anchored(bullet):
			ProjectileTracking.capture_anchor(bullet, _entities, _player)
		ProjectileMotion.catch_up(bullet, latency_ms * 0.5)
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
	RemoteAnimation.note_attack(_entities.players, source, float(wire.get("angle", 0.0)))


func apply_unload(data: Dictionary) -> void:
	for value in data.get("bullets", []):
		var id := int(value)
		bullets.erase(id)
		for local_id in bullets.keys():
			if bullets[local_id].get("server_id", 0) == id:
				bullets.erase(local_id)


## Advances every bullet by one frame and drops the expired ones.
func advance(delta: float) -> void:
	if bullets.is_empty():
		return
	var bullet_scale := delta * GameConstants.TICK_RATE
	var now: int = _clock.call()
	for id in bullets.keys():
		var bullet: Dictionary = bullets[id]
		# Order matches the server tick: steer, integrate, then re-anchor.
		if _entities != null and ProjectileKind.is_homing(bullet):
			ProjectileTracking.steer(bullet, _entities, _player, bullet_scale)
		ProjectileMotion.step(bullet, bullet_scale, now)
		if _entities != null and ProjectileKind.is_anchored(bullet):
			ProjectileTracking.anchor(bullet, _entities, _player)
		if ProjectileMotion.is_expired(bullet, now):
			bullets.erase(id)


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
	if not bool(archetype.get("melee", false)):
		bullets.merge(ShotPredictor.build(shot, group_id, definitions,
			base_angle, _player.position, archetype, _clock.call(), extra))

	return {
		"projectileId": shot,
		"projectileGroupId": group_id,
		"destX": target.x,
		"destY": target.y,
		"srcX": _player.position.x,
		"srcY": _player.position.y,
	}
