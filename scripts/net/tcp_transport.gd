class_name TcpTransport
extends NetTransport

## Production transport: a direct pass-through to StreamPeerTCP.

var _peer := StreamPeerTCP.new()


func connect_to_host(host: String, port: int) -> Error:
	# StreamPeerTCP only accepts a connect from STATUS_NONE; starting from a
	# fresh peer makes reconnecting reliable regardless of prior state.
	_peer = StreamPeerTCP.new()
	return _peer.connect_to_host(host, port)


func poll() -> void:
	_peer.poll()


func get_status() -> int:
	return _peer.get_status()


## Nothing to read from a socket that is not open -- asking the peer errors
## instead, which is what the frame after the server hangs up on us (as it
## does in answer to a death ack) used to print.
func get_available_bytes() -> int:
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return 0
	return _peer.get_available_bytes()


func get_data(count: int) -> Array:
	return _peer.get_data(count)


func put_data(bytes: PackedByteArray) -> Error:
	return _peer.put_data(bytes)


func disconnect_from_host() -> void:
	_peer.disconnect_from_host()


func set_no_delay(enabled: bool) -> void:
	_peer.set_no_delay(enabled)
