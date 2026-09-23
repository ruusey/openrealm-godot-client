class_name Screens
extends Node

## Every overlay the client draws over the world, built in one place.
##
## Each is a CanvasLayer that reads the realm state on its own; this only
## constructs them, in their layer order, and answers the one question the
## input layer asks of them together -- whether a click right now belongs to
## a panel rather than to the world underneath it.

var overlay: EntityOverlay
var hud: DebugHud
var dev: DevOverlay
var chat: ChatPanel
var inventory: InventoryPanel
var skills: SkillsPanel
var masteries: MasteryPanel
var quests: QuestLogPanel
var abilities: AbilityBar
var store: ItemStorePanel
var fame: FameStorePanel
var forge: ForgePanel
var market: ExchangeMarketPanel
var prompt: InteractPrompt
var minimap: MinimapPanel
var player: PlayerHud
var banner: RealmBanner
var trade_request: TradeRequestPopup
var trade: TradePanel
var party_invite: PartyInvitePopup
var party: PartyPanel
var nearby: NearbyPanel
var options: OptionsPanel
var transition: TransitionScreen
var death: DeathScreen
var login: LoginScreen
var loading: LoadingScreen


func build(state: RealmState, game_data: GameData, client: OpenRealmClient,
		data_service: DataService, inventory_actions: InventoryActions,
		caster: AbilityCaster, shop: ShopActions, forge_actions: ForgeActions,
		world: WorldRenderer, chat_actions: ChatActions = null) -> void:
	overlay = EntityOverlay.new()
	overlay.setup(state, game_data)
	add_child(overlay)
	hud = DebugHud.new()
	hud.setup(client, state, world)
	add_child(hud)
	dev = DevOverlay.new()
	dev.setup(client)
	add_child(dev)
	if chat_actions != null:
		chat_actions.commands = ClientCommands.new(state, dev, hud, client)

	chat = ChatPanel.new()
	chat.setup(state, chat_actions)
	add_child(chat)
	inventory = InventoryPanel.new()
	inventory.setup(state, game_data, inventory_actions)
	add_child(inventory)
	skills = SkillsPanel.new()
	skills.setup(state, game_data, client)
	add_child(skills)
	masteries = MasteryPanel.new()
	masteries.setup(state)
	add_child(masteries)
	quests = QuestLogPanel.new()
	quests.setup(state, game_data, client)
	add_child(quests)
	abilities = AbilityBar.new()
	abilities.setup(state, game_data, caster, skills)
	add_child(abilities)

	prompt = InteractPrompt.new()
	prompt.setup(state, shop)
	add_child(prompt)
	minimap = MinimapPanel.new()
	minimap.setup(state, chat_actions)
	add_child(minimap)
	player = PlayerHud.new()
	player.setup(state, game_data)
	add_child(player)
	banner = RealmBanner.new()
	banner.setup(state, game_data)
	add_child(banner)

	var trade_actions := TradeActions.new(state, client)
	trade_request = TradeRequestPopup.new()
	trade_request.setup(state, trade_actions)
	add_child(trade_request)
	trade = TradePanel.new()
	trade.setup(state, game_data, trade_actions)
	add_child(trade)

	var party_actions := PartyActions.new(state, client)
	party_invite = PartyInvitePopup.new()
	party_invite.setup(state, party_actions)
	add_child(party_invite)
	party = PartyPanel.new()
	party.setup(state, game_data, party_actions, hud)
	add_child(party)
	options = OptionsPanel.new()
	options.setup(state.settings, client)
	add_child(options)
	nearby = NearbyPanel.new()
	nearby.setup(state, game_data, trade_actions, party_actions, chat_actions, party)
	add_child(nearby)

	store = ItemStorePanel.new()
	store.setup(state, game_data, inventory_actions, shop)
	add_child(store)
	fame = FameStorePanel.new()
	fame.setup(state, game_data, shop)
	add_child(fame)
	forge = ForgePanel.new()
	forge.setup(state, game_data, forge_actions)
	add_child(forge)
	market = ExchangeMarketPanel.new()
	market.setup(state, game_data, shop)
	add_child(market)

	transition = TransitionScreen.new()
	transition.setup(state, game_data)
	add_child(transition)

	death = DeathScreen.new()
	add_child(death)

	login = LoginScreen.new()
	login.data_service = data_service
	login.game_data = game_data
	add_child(login)

	loading = LoadingScreen.new()
	loading.setup(game_data)
	add_child(loading)


## A click on the bag, the bar or the sheet is a gesture on it, not a shot
## at -- or a cast into -- the world behind it.
func captures_mouse() -> bool:
	return [inventory, abilities, skills, masteries, quests, store, fame, forge, minimap, market, trade,
		trade_request, party, party_invite, nearby, options].any(
			func(panel) -> bool: return panel.captures_mouse())


## A key while the chat line is open is a letter, not a command.
func captures_keyboard() -> bool:
	return chat.is_typing() or options.capturing()
