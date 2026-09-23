extends GutTest

## NetFrame: [id][totalLength][payload], 0x80 id-bit marks a deflated payload.

func _payload(size: int, seed_value := 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(size)
	for i in size:
		out[i] = (i * 7 + seed_value) % 256
	return out


func test_encodes_header_with_total_length_including_header():
	var frame := NetFrame.encode(9, _payload(10))
	assert_eq(frame.size(), 15, "5-byte header + 10-byte payload")
	assert_eq(frame[0], 9, "packet id in the first byte")
	var declared := (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4]
	assert_eq(declared, 15, "totalLength counts the header")


func test_encodes_empty_payload():
	var frame := NetFrame.encode(5, PackedByteArray())
	assert_eq(frame.size(), NetFrame.HEADER_SIZE)
	var decoded := NetFrame.try_decode(frame)
	assert_eq(decoded["id"], 5)
	assert_eq(decoded["payload"].size(), 0)


func test_payload_at_threshold_stays_raw():
	var frame := NetFrame.encode(1, _payload(NetFrame.COMPRESSION_THRESHOLD))
	assert_false(NetFrame.is_compressed(frame[0]), "128 bytes is not above the threshold")


func test_payload_above_threshold_is_compressed():
	# Highly repetitive so deflate definitely wins.
	var payload := PackedByteArray()
	payload.resize(2000)
	payload.fill(7)
	var frame := NetFrame.encode(9, payload)
	assert_true(NetFrame.is_compressed(frame[0]), "compression flag set")
	assert_lt(frame.size(), payload.size(), "compressed frame is smaller")
	assert_eq(NetFrame.real_packet_id(frame[0]), 9, "id survives the flag")


func test_incompressible_payload_falls_back_to_raw():
	# Random-ish bytes: deflate cannot shrink them, so Java sends the raw frame.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var payload := PackedByteArray()
	payload.resize(300)
	for i in payload.size():
		payload[i] = rng.randi() % 256
	var frame := NetFrame.encode(2, payload)
	if NetFrame.is_compressed(frame[0]):
		assert_lt(frame.size(), payload.size() + NetFrame.HEADER_SIZE, "only compressed when it helps")
	else:
		assert_eq(frame.size(), payload.size() + NetFrame.HEADER_SIZE, "raw fallback keeps the plain framing")


func test_round_trips_compressed_payload():
	var payload := _payload(5000)
	var decoded := NetFrame.try_decode(NetFrame.encode(3, payload))
	assert_false(decoded.has("error"), "no decode error")
	assert_eq(decoded["payload"], payload, "payload survives deflate")


func test_returns_empty_for_every_short_prefix():
	var frame := NetFrame.encode(9, _payload(64))
	for n in frame.size():
		assert_true(NetFrame.try_decode(frame.slice(0, n)).is_empty(),
			"a %d-byte prefix of a %d-byte frame must not decode" % [n, frame.size()])


func test_reports_consumed_so_trailing_bytes_survive():
	var first := NetFrame.encode(1, _payload(8))
	var second := NetFrame.encode(2, _payload(8, 99))
	var decoded := NetFrame.try_decode(first + second)
	assert_eq(decoded["consumed"], first.size(), "consumes exactly one frame")
	var rest := NetFrame.try_decode((first + second).slice(decoded["consumed"]))
	assert_eq(rest["id"], 2, "the next frame is still intact")


func test_rejects_length_below_header():
	var bad := PackedByteArray([1, 0, 0, 0, 2])
	assert_true(NetFrame.try_decode(bad).has("error"), "a length under 5 is malformed")


func test_rejects_implausible_length():
	var bad := PackedByteArray([1, 0x7F, 0xFF, 0xFF, 0xFF])
	var result := NetFrame.try_decode(bad)
	assert_true(result.has("error"), "a 2GB frame is rejected rather than buffered")


func test_rejects_compressed_frame_shorter_than_size_prefix():
	var bad := PackedByteArray([0x80 | 9, 0, 0, 0, 7, 1, 2])
	assert_true(NetFrame.try_decode(bad).has("error"))


func test_rejects_implausible_decompressed_size():
	var bad := PackedByteArray([0x80 | 9, 0, 0, 0, 13, 0x7F, 0xFF, 0xFF, 0xFF, 1, 2, 3, 4])
	assert_true(NetFrame.try_decode(bad).has("error"))


func test_rejects_zero_decompressed_size():
	var bad := PackedByteArray([0x80 | 9, 0, 0, 0, 13, 0, 0, 0, 0, 1, 2, 3, 4])
	assert_true(NetFrame.try_decode(bad).has("error"))


func test_rejects_corrupt_deflate_stream():
	var payload := PackedByteArray()
	payload.resize(500)
	payload.fill(3)
	var frame := NetFrame.encode(9, payload)
	assert_true(NetFrame.is_compressed(frame[0]), "precondition: frame is compressed")
	frame[12] = frame[12] ^ 0xFF  # corrupt the deflate stream
	var result := NetFrame.try_decode(frame)
	assert_true(result.has("error"), "a corrupt deflate stream is a decode error, not a crash")


func test_is_compressed_and_real_packet_id():
	assert_true(NetFrame.is_compressed(0x80))
	assert_false(NetFrame.is_compressed(0x7F))
	assert_eq(NetFrame.real_packet_id(0x80 | 42), 42)
	assert_eq(NetFrame.real_packet_id(42), 42)
