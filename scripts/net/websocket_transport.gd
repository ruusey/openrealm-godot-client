class_name WebSocketTransport
extends NetTransport

## Transport for the browser, where a raw TCP socket is not available.
##
## The game server speaks the identical protocol on both ports -- same frame
## header, same packet ids, same compression flag -- so nothing above this
## file changes. The one real difference is shape: TCP is a byte stream that
## NetFrame has to reassemble across reads, while WebSocket delivers whole
## messages. Each message the server sends is exactly one frame, so this
## appends them into a buffer and hands NetConnection the same byte stream it
## already knows how to read; the reassembly becomes a no-op rather than
## something that has to be reimplemented.
##
## Sending goes the other way: NetConnection.send writes one complete frame per
## put_data call, so one call is one message, which is what the server and the
## bundled web client both expect.

## The server's WebSocket listener. Its TCP listener is on 2222.
const DEFAULT_PORT := 2223
## Matches NetFrame's ceiling: a compressed LoadMapPacket is far larger than
## the peer's default 64 KiB, and anything that does not fit is dropped.
const BUFFER_SIZE := NetFrame.MAX_FRAME_SIZE

## Replaceable so the state machine can be driven without a server. Anything
## with WebSocketPeer's methods will do.
var open_socket := func() -> Object: return WebSocketPeer.new()
## In a browser the socket is the page's WebSocket, which has no Nagle knob
## to turn: the engine's peer prints an error for set_no_delay there. A
## member so the desktop suite can cover the browser's path.
var on_web := OS.has_feature("web")

var _peer: Object = null
var _inbox := PackedByteArray()
## How we reached a closed socket: a handshake that never completed is a failed
## connect, one that had been open is a hangup. TCP distinguishes them by
## status and ConnectionPhase reads that difference, so we have to keep it.
var _connecting := false
var _opened := false


## `host` may carry its own scheme, for a deployment behind TLS.
##
## A scheme *and* a path is a complete address -- the proxy's route, on the
## proxy's own port -- so nothing is appended. Appending there would land the
## port after the path and produce wss://play.example/ws:2223, which resolves
## to nothing.
static func url_for(host: String, port: int) -> String:
	if not host.contains("://"):
		return "ws://%s:%d" % [host, port]
	if host.split("://", true, 1)[1].contains("/"):
		return host
	return "%s:%d" % [host, port]


func connect_to_host(host: String, port: int) -> Error:
	_peer = open_socket.call()
	_peer.inbound_buffer_size = BUFFER_SIZE
	_peer.outbound_buffer_size = BUFFER_SIZE
	_inbox = PackedByteArray()
	_opened = false
	var err: Error = _peer.connect_to_url(url_for(host, port))
	_connecting = err == OK
	return err


func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_opened = true
	while _peer.get_available_packet_count() > 0:
		_inbox.append_array(_peer.get_packet())


## Reported as StreamPeerTCP status values, which is what NetTransport's
## contract is written in and what ConnectionPhase matches on.
func get_status() -> int:
	if _peer == null:
		return StreamPeerTCP.STATUS_NONE
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return StreamPeerTCP.STATUS_CONNECTING
		WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CLOSING:
			# Still connected while closing: there may be buffered frames left
			# to drain, and the next poll lands on CLOSED as a clean hangup.
			return StreamPeerTCP.STATUS_CONNECTED
	if _connecting and not _opened:
		return StreamPeerTCP.STATUS_ERROR
	return StreamPeerTCP.STATUS_NONE


func get_available_bytes() -> int:
	return _inbox.size()


## Mirrors StreamPeer.get_data, which is all-or-nothing. It cannot block here,
## so asking for more than has arrived is an error rather than a short read --
## a short read would look like a truncated frame to NetFrame.
func get_data(count: int) -> Array:
	if count <= 0:
		return [OK, PackedByteArray()]
	if count > _inbox.size():
		return [ERR_UNAVAILABLE, PackedByteArray()]
	var chunk := _inbox.slice(0, count)
	_inbox = _inbox.slice(count)
	return [OK, chunk]


## Explicitly binary. There is no write-mode property to set once -- the mode
## is an argument to each send -- and a frame written as text is mangled.
func put_data(bytes: PackedByteArray) -> Error:
	if _peer == null:
		return ERR_UNAVAILABLE
	return _peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)


func disconnect_from_host() -> void:
	if _peer != null:
		_peer.close()
	_inbox = PackedByteArray()
	_connecting = false
	_opened = false


## The peer exposes the same knob the TCP one does, and NetConnection.open
## sets it on every connect for the same reason: a 64Hz movement packet must
## not wait for Nagle to fill a segment. Not in a browser, where there is no
## such knob and asking is an error on the console.
func set_no_delay(enabled: bool) -> void:
	if _peer != null and not on_web:
		_peer.set_no_delay(enabled)
