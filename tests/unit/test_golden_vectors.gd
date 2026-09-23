extends GutTest

## Conformance against tests/golden/, produced by tools/gen_golden.py -- an
## independent Python implementation of the Java wire format read straight from
## the server source. Agreement between the two is the closest thing to a
## conformance test we can run without the Java server.

const FLOAT_TOLERANCE := 1e-5

var _manifest: Array = []
var _blob := PackedByteArray()


func before_all():
	_blob = FileAccess.get_file_as_bytes("res://tests/golden/frames.bin")
	var text := FileAccess.get_file_as_string("res://tests/golden/manifest.json")
	_manifest = JSON.parse_string(text) if text != "" else []


func test_golden_vectors_exist():
	assert_gt(_manifest.size(), 0, "run: python3 tools/gen_golden.py <java-src-root>")
	assert_gt(_blob.size(), 0)


func test_stream_decodes_frame_by_frame():
	var buffer := _blob.duplicate()
	var index := 0
	while buffer.size() > 0 and index < _manifest.size():
		var entry: Dictionary = _manifest[index]
		var decoded := NetFrame.try_decode(buffer)
		assert_false(decoded.is_empty(), "frame %d decodes" % index)
		assert_false(decoded.has("error"), "frame %d: %s" % [index, decoded.get("error", "")])
		assert_eq(decoded["id"], int(entry["id"]), "%s id" % entry["packet"])
		assert_eq(decoded["consumed"], int(entry["frame_size"]), "%s frame size" % entry["packet"])
		assert_eq(decoded["payload"].size(), int(entry["payload_size"]), "%s payload size" % entry["packet"])
		buffer = buffer.slice(decoded["consumed"])
		index += 1
	assert_eq(index, _manifest.size(), "every golden frame was consumed")
	assert_eq(buffer.size(), 0, "no trailing bytes")


func test_at_least_one_golden_frame_is_compressed():
	var compressed := 0
	for entry in _manifest:
		if entry["compressed"]:
			compressed += 1
	assert_gt(compressed, 0, "the vectors must exercise the deflate path")


func test_decoded_fields_match_python():
	for entry in _manifest:
		var payload := _hex(entry["payload_hex"])
		var decoded := NetCodec.decode_payload(entry["packet"], payload)
		_expect_equal(entry["packet"], entry["expected"], decoded)


func test_reencoding_reproduces_python_bytes():
	for entry in _manifest:
		var payload := _hex(entry["payload_hex"])
		var reencoded := NetCodec.encode_payload(entry["packet"], NetCodec.decode_payload(entry["packet"], payload))
		assert_eq(reencoded, payload, "%s re-encodes to identical bytes" % entry["packet"])


func _expect_equal(path: String, expected: Variant, actual: Variant) -> void:
	if expected is Dictionary:
		assert_true(actual is Dictionary, "%s should be a struct" % path)
		if not actual is Dictionary:
			return
		assert_eq(actual.size(), expected.size(), "%s field count" % path)
		for key in expected:
			if actual.has(key):
				_expect_equal("%s.%s" % [path, key], expected[key], actual[key])
			else:
				fail_test("%s.%s missing" % [path, key])
		return
	if expected is Array:
		assert_true(actual is Array, "%s should be an array" % path)
		if not actual is Array:
			return
		assert_eq(actual.size(), expected.size(), "%s length" % path)
		for i in mini(expected.size(), actual.size()):
			_expect_equal("%s[%d]" % [path, i], expected[i], actual[i])
		return
	if expected is float or actual is float:
		assert_almost_eq(float(actual), float(expected),
			maxf(FLOAT_TOLERANCE, absf(float(expected)) * FLOAT_TOLERANCE), path)
		return
	assert_eq(actual, expected, path)


func _hex(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(text.length() / 2)
	for i in out.size():
		out[i] = text.substr(i * 2, 2).hex_to_int()
	return out
