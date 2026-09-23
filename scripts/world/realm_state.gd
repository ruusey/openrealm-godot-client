class_name RealmState
extends RefCounted

## The client's model of the realm, and the router that feeds it. Each
## component handles its own wire mapping; adding a packet is one line here.
##
##   tiles, entities       terrain and collision; players, enemies, loot, portals
##   local, movement       the player we control, its prediction and reconciliation
##   projectiles, particles  bullets (simulated, never streamed) and their trails
##   texts, chat, bubbles  combat numbers, the chat log, what floats over heads
##   abilities, progress   skill points, cooldowns, casts; masteries, quests
##   store, fame, forge, market, minimap, trade, party  the tile panels, the map, a trade, the party

const TICK_DELTA := GameConstants.TICK_DELTA
const TILE_SIZE := GameConstants.TILE_SIZE
const PLAYER_SIZE := GameConstants.PLAYER_SIZE

var tiles: TileMapState
var entities: EntityRegistry
var local: LocalPlayer
var movement: MovementPredictor
var projectiles: ProjectileSystem
var particles: ParticleField
var texts: DamageText
var chat: ChatLog
var bubbles: ChatBubbles
var abilities: AbilityState
var store: ItemStore
var fame: FameStore
var forge: ForgeBench
var market: ExchangeMarket
var minimap: MinimapState
var trade: TradeSession
var party: PartyState
var transition: RealmTransition
## The difficulty of the realm being entered, when a portal said so.
var transition_difficulty := 0.0
## What the player has switched on and off; every view reads it from here.
var settings := GameSettings.new()
var progress := AccountProgress.new()   # masteries, quests, stars: kept across realms

var transition_pending: bool:
	get: return transition.pending


func _init(content: GameData = null,
		clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	tiles = TileMapState.new(content)
	entities = EntityRegistry.new(clock)
	local = LocalPlayer.new()
	entities.viewer = func() -> Vector2: return local.centre() if local.is_present() else Vector2.INF
	movement = MovementPredictor.new(local, tiles)
	projectiles = ProjectileSystem.new(local, content, clock, entities)
	particles = ParticleField.new(null if content == null else content.projectiles_art)
	texts = DamageText.new()
	chat = ChatLog.new(clock)
	bubbles = ChatBubbles.new(clock)
	abilities = AbilityState.new(clock)
	store = ItemStore.new()
	fame = FameStore.new()
	forge = ForgeBench.new()
	market = ExchangeMarket.new()
	minimap = MinimapState.new(content, clock)
	trade = TradeSession.new(clock)
	party = PartyState.new(clock)
	transition = RealmTransition.new(self, clock)


func apply_packet(name: String, data: Dictionary) -> void:
	match name:
		"LoadMapPacket":
			transition.apply_load_map(data)
		"LoadPacket":
			entities.apply_load(data)
			projectiles.apply_load(data)
			PlayerSync.local_class(self)
		"UnloadPacket":
			entities.apply_unload(data)
			projectiles.apply_unload(data)
		"ObjectMovePacket":
			entities.apply_object_move(data)
			transition.snap_local(data)
		"CompactMovePacket":
			entities.apply_compact_move(data)
		"UpdatePacket":
			PlayerSync.update(self, data)
		"PlayerStatePacket":
			PlayerSync.player_state(self, data)
		"PlayerPosAckPacket":
			movement.apply_position_ack(data)
		"TextEffectPacket":
			texts.apply_text_effect(data, entities, projectiles, local)
		"TextPacket":
			for listener in [chat, bubbles, transition, minimap, party]:
				listener.apply_text(data)
		"GlobalPlayerPositionPacket":
			minimap.apply_global_positions(data)
		"RealmPurificationPacket":
			minimap.apply_purification(data)
		"AbilityCastStartPacket":
			abilities.apply_cast_start(data, entities, local.id)
		"CreateEffectPacket":
			abilities.apply_effect(data)
		"OpenItemStorePacket":
			store.apply_open(data, local.id)
		"ItemStoreUpdatePacket":
			store.apply_update(data, local.id)
		"OpenFameStorePacket":
			fame.apply_open(data, local.id)
		"OpenForgePacket":
			forge.apply_open(data, local.id)
		"OpenExchangeMarketPacket":
			market.apply_open(data, local.id)
		"RequestTradePacket", "AcceptTradeRequestPacket", "UpdateTradePacket", \
				"UpdatePlayerTradeSelectionPacket":
			trade.apply(name, data, local.id)
		"SkillsPacket", "QuestStatePacket":
			progress.apply(name, data, local.id)
		"PartyUpdatePacket":
			party.apply_update(data)


func advance(delta: float, input: Vector2, latency_ms: float) -> Array:
	projectiles.latency_ms = latency_ms
	transition.expire()
	local.decay_smoothing(delta)
	var to_send := movement.predict(delta, input)
	local.walk.advance(movement.pace_px, delta)
	local.attack.tick(delta)
	RemoteAnimation.advance(entities.players, delta)
	projectiles.advance(delta)
	particles.advance(delta, projectiles.bullets,
		func(bullet: Dictionary) -> bool: return Blind.hides_bullet(self, bullet))
	texts.advance(delta)
	abilities.expire()
	minimap.expire()
	trade.expire()
	party.expire()
	return to_send


func reset_world() -> void:
	for component in [tiles, entities, projectiles, particles, texts, chat, bubbles,
			abilities, store, fame, forge, market, minimap, trade, party]:
		component.clear()


func begin_transition(difficulty := 0.0) -> void:
	transition.begin()
	transition_difficulty = difficulty
