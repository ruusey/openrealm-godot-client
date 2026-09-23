class_name WireBuffer
extends RefCounted

## The scalar layer of the protocol: buffers and the seven primitive types.
##
## Everything is big-endian, because the server writes with
## java.io.DataOutputStream. Strings are [int32 utf8-byte-length][bytes] --
## the prefix counts BYTES, not characters, so multibyte names stay aligned.
##
## Separate from NetCodec so that walking the schema and encoding a scalar
## stay two jobs: NetCodec decides what comes next, this decides how it looks
## on the wire.


static func make_reader(payload: PackedByteArray) -> StreamPeerBuffer:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = true
	buf.data_array = payload
	return buf


static func make_writer() -> StreamPeerBuffer:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = true
	return buf


static func read_primitive(buf: StreamPeerBuffer, wire_type: String) -> Variant:
	match wire_type:
		"byte":
			return buf.get_8()
		"bool":
			return buf.get_8() != 0
		"short":
			return buf.get_16()
		"int":
			return buf.get_32()
		"long":
			return buf.get_64()
		"float":
			return buf.get_float()
		"string":
			var length := buf.get_32()
			if length <= 0:
				return ""
			return buf.get_data(length)[1].get_string_from_utf8()
	push_error("NetCodec: unknown primitive wire type '%s'" % wire_type)
	return null


static func write_primitive(buf: StreamPeerBuffer, wire_type: String, value: Variant) -> void:
	match wire_type:
		"byte":
			buf.put_8(int(value if value != null else 0))
		"bool":
			buf.put_8(1 if value else 0)
		"short":
			buf.put_16(int(value if value != null else 0))
		"int":
			buf.put_32(int(value if value != null else 0))
		"long":
			buf.put_64(int(value if value != null else 0))
		"float":
			buf.put_float(float(value if value != null else 0.0))
		"string":
			var bytes := String(value if value != null else "").to_utf8_buffer()
			buf.put_32(bytes.size())
			if bytes.size() > 0:
				buf.put_data(bytes)
		_:
			push_error("NetCodec: unknown primitive wire type '%s'" % wire_type)
