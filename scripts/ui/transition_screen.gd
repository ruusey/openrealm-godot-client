class_name TransitionScreen
extends CanvasLayer

## Covers the stretch between asking to leave a realm and arriving in the next.
##
## The client has nothing to draw in between: the realm it is leaving is gone
## and the one it is entering has not been sent yet, so what is on screen is
## the player standing on black. Both references cover it -- the web client's
## splash carries the zone name, a difficulty badge and a walking sprite, the
## native client's is a settings-gated state -- because without one it reads
## as a crash rather than as loading.
##
## A dim, the zone's name, the player's class walking (TransitionArt), the
## realm's difficulty as pips when the portal gave one, and a fade that only
## begins once the realm has actually landed, so a slow transition never
## flashes and a fast one is still legible.

## How long the cover stays up once the next realm has arrived, before it
## begins to clear. The web client's TRANSITION_DURATION_MS, and it is what
## makes the realm's name readable: without a floor the name arrives with the
## fade and is gone in a third of a second, because the server sends it on the
## heels of the tiles.
const HOLD_SECONDS := 2.0
## And how long the clearing itself takes.
const FADE_SECONDS := 0.35

var state: RealmState
var content: GameData
## Read rather than accumulated, so a scripted render can pin it the way the
## bullet layer's clock already is -- a fade driven by the frame delta lands
## at a different alpha every capture.
var clock: Callable = func() -> int: return Time.get_ticks_msec()

var _dim: ColorRect
var _label: Label
var _sprite: TextureRect
var _pips: HBoxContainer
var _difficulty: Label
var _started_at := 0
var _cover := 0.0
var _arrived_at := 0


func setup(realm_state: RealmState, game_data: GameData) -> void:
	state = realm_state
	content = game_data


func _ready() -> void:
	# Above the diagnostic overlay, below the login screen: this covers the
	# world, not the way back out of it.
	layer = 15
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.92)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(column)
	_label = HudWidgets.label("", 20, Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2.ONE * TransitionArt.SPRITE
	_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_sprite)
	_pips = TransitionArt.pip_row(column)
	_difficulty = HudWidgets.label("", 13, Color(0.8, 0.75, 0.75))
	_difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_difficulty)


## The line the splash shows.
##
## Named after the map only once we have landed in it: during the wait itself
## the client has not been told where it is going, which is why both
## references take the name from the server rather than guessing it.
static func caption(map_name: String) -> String:
	if map_name == "":
		return "Entering ..."
	return "Entering %s" % map_name.replace("_", " ")


## The server's own name for the realm if it has sent one, and the map's name
## otherwise. That order matters on the way out: the name arrives after the
## tiles, so by the time the cover is fading it is usually the better of the
## two, and it is the only one a dungeon has -- an assembled dungeon shares
## its parent's map id.
func _destination() -> String:
	if state.transition.zone != "":
		return state.transition.zone
	return "" if content == null else content.maps.name(state.tiles.map_id)


func _process(_delta: float) -> void:
	if state == null:
		visible = false
		return
	if state.transition_pending:
		if _cover <= 0.0:
			_started_at = clock.call()
		_cover = 1.0
		_arrived_at = 0
		# The server's own name for the realm if it has sent one, and nothing
		# otherwise. The map id is no help here: it still says where we came
		# FROM, so reading it would put "Entering <the realm you just left>"
		# on screen.
		_label.text = caption(state.transition.zone)
	elif _cover > 0.0:
		if _arrived_at == 0:
			_arrived_at = clock.call()
		var held := float(clock.call() - _arrived_at) / 1000.0
		_cover = clampf(1.0 - (held - HOLD_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		_label.text = caption(_destination())

	visible = _cover > 0.0 and state.settings.is_on("show_transition_screen")
	if visible:
		_dim.modulate.a = _cover
		_show_walker()


func _show_walker() -> void:
	var spd := int(state.local.stats.get("spd", TransitionArt.DEFAULT_SPD))
	var dye := int(state.entities.players.get(state.local.id, {}).get("dye_id", 0))
	_sprite.texture = null if content == null else content.classes_art.frame(state.local.class_id, "walk",
		TransitionArt.facing(content, state.local.class_id), TransitionArt.walk_frame(clock.call() - _started_at, spd), dye)
	TransitionArt.set_pips(_pips, state.transition_difficulty)
	_difficulty.text = TransitionArt.label(state.transition_difficulty)
