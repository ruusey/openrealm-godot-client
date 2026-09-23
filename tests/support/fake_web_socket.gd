class_name FakeWebSocket
extends RefCounted

## Scriptable stand-in for WebSocketPeer.
##
## Mirrors the real peer's semantics rather than a convenient subset: the
## handshake only advances when polled, packets are only readable after a
## poll, and a peer that never reached STATE_OPEN closes rather than erroring.
## A fake that is more permissive than the API it stands for hides the bugs it
## exists to catch.

var inbound_buffer_size := 0
var outbound_buffer_size := 0
var no_delay_set := false

var connect_error: Error = OK
var put_error: Error = OK
var last_url := ""
var poll_count := 0
var close_count := 0
## Whole messages the server has "sent", handed over one per get_packet.
var incoming: Array[PackedByteArray] = []
## Whole messages written, so a test can prove one frame became one message.
var sent: Array[PackedByteArray] = []
## The mode each of those was written in. WebSocketPeer has no write-mode
## property -- it is an argument to send -- so there is nothing to set once
## and forget, and a fake offering one would hide a frame sent as text.
var sent_modes: Array[int] = []

var _state := WebSocketPeer.STATE_CLOSED
## Messages only become readable on a poll, like the real peer.
var _ready: Array[PackedByteArray] = []


func connect_to_url(url: String, _tls: TLSOptions = null) -> Error:
	last_url = url
	if connect_error != OK:
		return connect_error
	_state = WebSocketPeer.STATE_CONNECTING
	return OK


## The handshake completing, the server hanging up, or a connect that never
## got there -- whichever the test needs next.
func become(state: int) -> void:
	_state = state


func poll() -> void:
	poll_count += 1
	if _state == WebSocketPeer.STATE_OPEN or _state == WebSocketPeer.STATE_CLOSING:
		_ready.append_array(incoming)
		incoming.clear()


func get_ready_state() -> int:
	return _state


func get_available_packet_count() -> int:
	return _ready.size()


func get_packet() -> PackedByteArray:
	if _ready.is_empty():
		return PackedByteArray()
	return _ready.pop_front()


func send(bytes: PackedByteArray, write_mode: int) -> Error:
	if put_error != OK:
		return put_error
	sent.append(bytes)
	sent_modes.append(write_mode)
	return OK


func set_no_delay(enabled: bool) -> void:
	no_delay_set = enabled


func close(_code := 1000, _reason := "") -> void:
	close_count += 1
	_state = WebSocketPeer.STATE_CLOSED
