class_name PacketStream
extends RefCounted

## Turns a byte stream into decoded packets.
##
## TCP gives no frame boundaries, so bytes accumulate here until a whole frame
## is available. A frame that cannot be parsed means the stream has desynced
## and the connection is no longer trustworthy -- that surfaces as an error
## rather than a skipped packet.

var bytes_buffered: int:
	get: return _buffer.size()

var _buffer := PackedByteArray()


func feed(chunk: PackedByteArray) -> void:
	_buffer.append_array(chunk)


func clear() -> void:
	_buffer.clear()


## Pulls every complete frame currently buffered.
##
## Returns {"packets": [{id, name, data}], "error": String}. `error` is empty
## unless the stream desynced, in which case packets decoded before the bad
## frame are still returned.
func drain() -> Dictionary:
	var packets: Array = []
	var consumed := 0

	while true:
		var view := _buffer.slice(consumed) if consumed > 0 else _buffer
		var frame := NetFrame.try_decode(view)
		if frame.is_empty():
			break
		if frame.has("error"):
			_trim(consumed)
			return {"packets": packets, "error": frame["error"]}

		consumed += frame["consumed"]
		var id: int = frame["id"]
		var name: String = NetSchema.PACKET_NAMES.get(id, "")
		packets.append({
			"id": id,
			"name": name,
			"data": NetCodec.decode_payload(name, frame["payload"]) if name != "" else {},
		})

	_trim(consumed)
	return {"packets": packets, "error": ""}


## Re-slicing once per drain rather than once per frame keeps the first-world
## burst, which can be hundreds of frames, from being quadratic.
func _trim(consumed: int) -> void:
	if consumed > 0:
		_buffer = _buffer.slice(consumed)
