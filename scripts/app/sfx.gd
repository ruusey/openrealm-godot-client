extends Node

## Plays the game's sound effects.
##
## Data-driven, like the rest of the content: sounds.json (served from the data
## service alongside the JSON and sprites) maps weapon archetypes, ability tags
## and events to ogg files under audio/, and this preloads every referenced file
## once the content lands. The whole mapping and the files are editable in the
## web editor; the client owns only the trigger points and the on/off switches.
##
## An autoload, so any script can reach it. Until configure() has run (tests, a
## headless render) every trigger is a no-op, and a headless display skips the
## voice pool entirely.

const FLAT_VOICES := 8
const POSITIONAL_VOICES := 10
## A remote player's multishot loads many bullets at once; one swing is one sound.
const REMOTE_ATTACK_THROTTLE_MS := 150
const POSITIONAL_MAX_DISTANCE := 1400.0
## textEffectId 0 is a damage number, 2 an armor-break hit (COLORS in DamageText);
## both are a hit landing. Heals/environment/info make no hit sound.
const DAMAGE_EFFECT := 0
const ARMOR_BREAK_EFFECT := 2
## WeaponArchetype ids -> the `attack` key they sound as. Fixed by the enum, not data.
const ARCHETYPE_NAMES := {
	1: "sword", 2: "axe", 3: "hammer",
	10: "dagger", 11: "bow", 12: "throwing_knife",
	20: "tome", 21: "staff", 22: "wand",
}

var _content: GameData
var _settings: GameSettings
var _streams := {}                     # filename -> AudioStream
var _flat: Array[AudioStreamPlayer] = []
var _positional: Array[AudioStreamPlayer2D] = []
var _flat_voice := 0
var _positional_voice := 0
var _remote_attack_at := {}            # shooter id -> last ms its swing played
var _ready_to_play := false


func _ready() -> void:
	if _headless():
		return
	for i in FLAT_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_flat.append(voice)
	for i in POSITIONAL_VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = POSITIONAL_MAX_DISTANCE
		add_child(voice)
		_positional.append(voice)
	# Every button anywhere clicks, without touching each call site: catch each
	# BaseButton as it enters the tree and play the UI click on its press.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	event("ui_click")


## Reads every referenced ogg through the same source the sprites came from, then
## arms playback. Awaited: over HTTP each file is a request. Leaves the system off
## if sounds.json set enabled to false.
func configure(content: GameData, settings: GameSettings, source: ContentSource) -> void:
	_content = content
	_settings = settings
	if _headless():
		return
	for filename in content.library.sound_files():
		if _streams.has(filename):
			continue
		var result: Array = await source.read(filename)
		if int(result[0]) != OK:
			continue
		var stream := AudioStreamOggVorbis.load_from_buffer(result[1])
		if stream != null:
			_streams[filename] = stream
	_ready_to_play = bool(_sounds().get("enabled", true))


## The local player's basic attack, by the archetype of the weapon in hand.
func attack(archetype_id: int) -> void:
	_play_flat(_attack_file(archetype_id))


## The local player's ability cast, resolved from the ability's tags (or name).
func ability(definition: Dictionary) -> void:
	_play_flat(_ability_file(definition))


## A non-positional own event: "item_use", "player_hurt".
func event(key: String) -> void:
	_play_flat(_event_file(key))


## A remote player's swing, placed at the shot's origin. Throttled so a multishot
## volley reads as one sound, and gated by the "other players" switch.
func remote_attack(shooter_id: int, at: Vector2) -> void:
	if not _can_play() or not _on("sound_others"):
		return
	var now := Time.get_ticks_msec()
	if now - int(_remote_attack_at.get(shooter_id, -REMOTE_ATTACK_THROTTLE_MS * 10)) < REMOTE_ATTACK_THROTTLE_MS:
		return
	_remote_attack_at[shooter_id] = now
	_play_positional(_attack_file(0), at)   # the archetype is not on the wire -> the default swing


## A damage number landing on an enemy -- anyone's hit. Positional, gated by the
## "hit sounds" switch (the one that gets noisy in a crowd).
## A hit landing on an enemy -- anyone's. Flat, not positional: the camera is on
## the player and hits happen at the player, so a world-anchored 2D voice only
## risked inaudibility. Gated by the "hit sounds" switch (noisy in a crowd).
func hit(key: String) -> void:
	if not _can_play() or not _on("sound_hits"):
		return
	_play_flat(_event_file(key))


func _attack_file(archetype_id: int) -> String:
	var table: Dictionary = _sounds().get("attack", {})
	return String(table.get(ARCHETYPE_NAMES.get(archetype_id, "default"), table.get("default", "")))


func _ability_file(definition: Dictionary) -> String:
	var sounds := _sounds()
	var by_name: Dictionary = sounds.get("abilityByName", {})
	if by_name.has(String(definition.get("name", ""))):
		return String(by_name[String(definition.get("name", ""))])
	var by_tag: Dictionary = sounds.get("abilityByTag", {})
	for tag in definition.get("tags", []):
		if by_tag.has(String(tag)):
			return String(by_tag[String(tag)])
	return String(sounds.get("abilityDefault", ""))


func _event_file(key: String) -> String:
	return String(_sounds().get("event", {}).get(key, ""))


func _sounds() -> Dictionary:
	return _content.library.sounds if _content != null else {}


func _play_flat(filename: String) -> void:
	if not _can_play():
		return
	var stream: AudioStream = _streams.get(filename)
	if stream == null or _flat.is_empty():
		return
	var voice := _flat[_flat_voice]
	_flat_voice = (_flat_voice + 1) % _flat.size()
	voice.stream = stream
	voice.volume_db = _volume_db()
	voice.play()


func _play_positional(filename: String, at: Vector2) -> void:
	var stream: AudioStream = _streams.get(filename)
	if stream == null or _positional.is_empty():
		return
	var voice := _positional[_positional_voice]
	_positional_voice = (_positional_voice + 1) % _positional.size()
	voice.stream = stream
	voice.global_position = at
	voice.volume_db = _volume_db()
	voice.play()


## Playable at all: armed, a settings object present, the master switch on and the
## volume above silent.
func _can_play() -> bool:
	return _ready_to_play and _settings != null and _on("sound") and _settings.sound_volume > 0.0


func _on(key: String) -> bool:
	return _settings == null or _settings.is_on(key)


func _volume_db() -> float:
	return linear_to_db(maxf(0.0001, clampf(_settings.sound_volume if _settings != null else 1.0, 0.0, 1.0)))


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"
