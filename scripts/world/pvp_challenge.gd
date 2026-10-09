class_name PvpChallengeState
extends RefCounted

## A PvP challenge waiting for an answer.
##
## The server sends the challenge as a TextPacket whose body is "<name>
## challenges you to a PvP battle! /pvpaccept or /pvpdecline (30s)" -- the
## web client sniffs that line for its Accept/Decline popup, so the prompt
## needs no new packet. The line's `from` is the CHALLENGER, not SYSTEM, so
## the name is read out of the message, not the envelope. It stands for the
## server's thirty seconds (PvpMatchManager.CHALLENGE_TTL_MS) and clears the
## moment the match starts or the challenge is declined.

const CHALLENGE_TTL_MS := 30_000
const CHALLENGE_MARK := " challenges you to a PvP battle"
## SYSTEM lines that mean the challenge is answered or gone.
const CHALLENGE_OVER := ["Challenge declined", "You are already in a PvP match"]
## The match-start line (sent to both players on accept) begins with this.
const MATCH_STARTED := "PvP match started"

var challenge_from := ""

var _clock: Callable
var _challenge_at := 0


func _init(clock: Callable = func() -> int: return Time.get_ticks_msec()) -> void:
	_clock = clock


func clear() -> void:
	challenge_from = ""


func apply_text(data: Dictionary) -> void:
	var message := String(data.get("message", ""))
	var mark := message.find(CHALLENGE_MARK)
	if mark > 0:
		challenge_from = message.left(mark)
		_challenge_at = _clock.call()
	elif message in CHALLENGE_OVER or message.begins_with(MATCH_STARTED):
		challenge_from = ""


func expire() -> void:
	if challenge_from != "" and _clock.call() - _challenge_at >= CHALLENGE_TTL_MS:
		challenge_from = ""
