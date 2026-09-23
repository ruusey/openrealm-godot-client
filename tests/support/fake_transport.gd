class_name FakeTransport
extends NetTransport

## Scriptable socket. Tests push bytes in, inspect bytes out, and control how
## the stream is chunked -- which is the only way to exercise frame reassembly
## across partial reads and mid-frame disconnects.

var status: int = StreamPeerTCP.STATUS_NONE
var incoming := PackedByteArray()
var sent := PackedByteArray()
var connect_error: Error = OK
var put_error: Error = OK
var read_error: Error = OK
## Maximum bytes surfaced per poll; -1 delivers everything available.
var chunk_size := -1
var poll_count := 0
var disconnect_count := 0
var no_delay_set := false
var last_host := ""
var last_port := 0


func connect_to_host(host: String, port: int) -> Error:
	last_host = host
	last_port = port
	if connect_error != OK:
		return connect_error
	# StreamPeerTCP refuses to connect unless it is STATUS_NONE. Mirroring
	# that here is what makes a missing reset show up as a test failure
	# instead of only in a real session.
	if status != StreamPeerTCP.STATUS_NONE:
		return ERR_ALREADY_IN_USE
	status = StreamPeerTCP.STATUS_CONNECTING
	return OK


func poll() -> void:
	poll_count += 1


func get_status() -> int:
	return status


func get_available_bytes() -> int:
	if chunk_size < 0:
		return incoming.size()
	return mini(chunk_size, incoming.size())


func get_data(count: int) -> Array:
	if read_error != OK:
		return [read_error, PackedByteArray()]
	var take := mini(count, incoming.size())
	var bytes := incoming.slice(0, take)
	incoming = incoming.slice(take)
	return [OK, bytes]


func put_data(bytes: PackedByteArray) -> Error:
	if put_error != OK:
		return put_error
	sent.append_array(bytes)
	return OK


func disconnect_from_host() -> void:
	disconnect_count += 1
	status = StreamPeerTCP.STATUS_NONE


func set_no_delay(enabled: bool) -> void:
	no_delay_set = enabled


# --- helpers ---------------------------------------------------------------

func deliver(bytes: PackedByteArray) -> void:
	incoming.append_array(bytes)


func become_connected() -> void:
	status = StreamPeerTCP.STATUS_CONNECTED


## Decodes everything the client has written so far into [{id, name, data}].
func sent_packets() -> Array:
	var out: Array = []
	var buffer := sent.duplicate()
	while true:
		var frame := NetFrame.try_decode(buffer)
		if frame.is_empty() or frame.has("error"):
			break
		var name: String = NetSchema.PACKET_NAMES.get(frame["id"], "")
		out.append({
			"id": frame["id"],
			"name": name,
			"data": NetCodec.decode_payload(name, frame["payload"]) if name != "" else {},
		})
		buffer = buffer.slice(frame["consumed"])
	return out


func clear_sent() -> void:
	sent = PackedByteArray()
