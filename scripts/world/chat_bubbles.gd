class_name ChatBubbles
extends RefCounted

## What each player last said, for the bubble over their head.
##
## Both references raise one on every player line: keyed by the sender's
## name (the web client looks the player up by name to get an id; the native
## keys on the name outright), clipped at 80 characters because long lines
## live in the log, alive 3.5s plus 40ms a character up to six seconds,
## fading over the last half second, and replaced outright by the next
## line. SYSTEM says nothing over anyone's head, and neither does a minimap
## marker wearing a chat packet's clothes.

const MAX_CHARS := 80
const BASE_MS := 3500
const PER_CHAR_MS := 40
const MAX_EXTRA_MS := 2500
const FADE_MS := 500

var _by_name := {}   # name -> {message, expires_ms}
var _clock: Callable


func _init(clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	_clock = clock


func apply_text(data: Dictionary) -> void:
	var from := String(data.get("from", ""))
	var message := String(data.get("message", ""))
	if from == "" or from == ChatLog.SYSTEM or from == ChatLog.EVENT_MARKER or message == "":
		return
	var clipped := message.substr(0, MAX_CHARS - 1) + "..." if message.length() > MAX_CHARS else message
	var life := BASE_MS + mini(MAX_EXTRA_MS, clipped.length() * PER_CHAR_MS)
	_by_name[from] = {"message": clipped, "expires_ms": int(_clock.call()) + life}


## The bubble to draw over a player, as {message, alpha}, or nothing.
func over(name: String) -> Dictionary:
	var bubble: Dictionary = _by_name.get(name, {})
	if bubble.is_empty():
		return {}
	var remaining: int = bubble["expires_ms"] - int(_clock.call())
	if remaining <= 0:
		_by_name.erase(name)
		return {}
	return {"message": bubble["message"],
		"alpha": 1.0 if remaining >= FADE_MS else float(remaining) / FADE_MS}


func clear() -> void:
	_by_name.clear()
