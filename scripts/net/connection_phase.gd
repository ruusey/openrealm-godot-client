class_name ConnectionPhase
extends RefCounted

## Maps a socket status onto the session transition it implies.
##
## Pure, so every branch of the connection state machine -- including the
## timeout and the server hangup -- is testable without a socket.

const ERROR := "error"
const HANGUP := "hangup"
const TIMED_OUT := "timed_out"
const WAITING := "waiting"
const OPENED := "opened"
const READY := "ready"


static func evaluate(status: int, awaiting_connect: bool, past_deadline: bool) -> String:
	if status == StreamPeerTCP.STATUS_ERROR:
		return ERROR
	if status == StreamPeerTCP.STATUS_NONE:
		# A socket that never came up is still connecting; one that went away
		# after connecting is a hangup.
		return WAITING if awaiting_connect else HANGUP
	if status == StreamPeerTCP.STATUS_CONNECTING:
		return TIMED_OUT if past_deadline else WAITING
	return OPENED if awaiting_connect else READY
