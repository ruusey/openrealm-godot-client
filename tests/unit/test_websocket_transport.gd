extends GutTest

## The browser transport. Everything above it is written against a byte stream
## and StreamPeerTCP's status values, so this is where message-shaped
## WebSocket traffic is translated into both.

var transport: WebSocketTransport
var socket: FakeWebSocket


func before_each():
	socket = FakeWebSocket.new()
	transport = WebSocketTransport.new()
	transport.open_socket = func() -> Object: return socket


func _open() -> void:
	transport.connect_to_host("127.0.0.1", WebSocketTransport.DEFAULT_PORT)
	socket.become(WebSocketPeer.STATE_OPEN)
	transport.poll()


# --- urls -------------------------------------------------------------------

func test_a_bare_host_gets_the_websocket_scheme():
	assert_eq(WebSocketTransport.url_for("127.0.0.1", 2223), "ws://127.0.0.1:2223")


func test_a_host_that_carries_its_own_scheme_keeps_it():
	# A deployment behind TLS is addressed as wss://, and prepending ws:// to
	# that produces a url that cannot connect.
	assert_eq(WebSocketTransport.url_for("wss://play.example", 443),
		"wss://play.example:443")


func test_connecting_uses_that_url():
	transport.connect_to_host("game.example", 2223)
	assert_eq(socket.last_url, "ws://game.example:2223")


func test_a_refused_connect_is_reported():
	socket.connect_error = ERR_CANT_CONNECT
	assert_eq(transport.connect_to_host("127.0.0.1", 2223), ERR_CANT_CONNECT)


# --- status translation -----------------------------------------------------

func test_an_untouched_transport_is_idle():
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE)


func test_a_handshake_in_flight_reads_as_connecting():
	transport.connect_to_host("127.0.0.1", 2223)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_CONNECTING)


func test_an_open_socket_reads_as_connected():
	_open()
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_CONNECTED)


func test_a_closing_socket_still_reads_as_connected():
	# There may be buffered frames left to drain; the next poll lands on
	# CLOSED and is reported as the hangup.
	_open()
	socket.become(WebSocketPeer.STATE_CLOSING)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_CONNECTED)


func test_a_handshake_that_never_completed_is_an_error():
	# ConnectionPhase turns STATUS_NONE while awaiting a connect into "still
	# waiting", so a failed handshake reported that way would hang until the
	# deadline instead of failing. TCP reports a refused connect as an error
	# and so does this.
	transport.connect_to_host("127.0.0.1", 2223)
	socket.become(WebSocketPeer.STATE_CLOSED)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_ERROR)
	assert_eq(ConnectionPhase.evaluate(transport.get_status(), true, false),
		ConnectionPhase.ERROR)


func test_a_socket_that_was_open_and_went_away_is_a_hangup():
	_open()
	socket.become(WebSocketPeer.STATE_CLOSED)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE)
	assert_eq(ConnectionPhase.evaluate(transport.get_status(), false, false),
		ConnectionPhase.HANGUP)


func test_disconnecting_returns_it_to_idle():
	_open()
	transport.disconnect_from_host()
	assert_eq(socket.close_count, 1)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE,
		"a socket we closed ourselves is not an error")


func test_reconnecting_starts_from_a_fresh_socket():
	_open()
	transport.disconnect_from_host()
	var second := FakeWebSocket.new()
	transport.open_socket = func() -> Object: return second
	transport.connect_to_host("127.0.0.1", 2223)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_CONNECTING)


# --- messages in, bytes out -------------------------------------------------

func test_messages_are_concatenated_into_one_stream():
	# Each message is a whole frame, but NetConnection reads bytes, so they
	# have to arrive as one run rather than as separate reads.
	_open()
	socket.incoming = [PackedByteArray([1, 2, 3]), PackedByteArray([4, 5])]
	transport.poll()
	assert_eq(transport.get_available_bytes(), 5)
	assert_eq(transport.get_data(5), [OK, PackedByteArray([1, 2, 3, 4, 5])])


func test_nothing_is_readable_before_a_poll():
	_open()
	socket.incoming = [PackedByteArray([1, 2, 3])]
	assert_eq(transport.get_available_bytes(), 0)


func test_reading_consumes_what_it_returns():
	_open()
	socket.incoming = [PackedByteArray([1, 2, 3, 4])]
	transport.poll()
	assert_eq(transport.get_data(2), [OK, PackedByteArray([1, 2])])
	assert_eq(transport.get_available_bytes(), 2)
	assert_eq(transport.get_data(2), [OK, PackedByteArray([3, 4])])
	assert_eq(transport.get_available_bytes(), 0)


func test_asking_for_more_than_arrived_fails_rather_than_short_reading():
	# A short read looks like a truncated frame to NetFrame, which desyncs the
	# stream rather than waiting for the rest.
	_open()
	socket.incoming = [PackedByteArray([1, 2])]
	transport.poll()
	assert_eq(transport.get_data(4), [ERR_UNAVAILABLE, PackedByteArray()])
	assert_eq(transport.get_available_bytes(), 2, "and consumes nothing")


func test_reading_nothing_is_not_an_error():
	_open()
	assert_eq(transport.get_data(0), [OK, PackedByteArray()])


func test_polling_before_connecting_does_nothing():
	transport.poll()
	assert_eq(socket.poll_count, 0)


# --- bytes in, messages out -------------------------------------------------

func test_one_frame_becomes_one_message():
	# The server reads a message as a whole frame. Splitting or coalescing
	# them here would desync it even though the bytes are identical.
	_open()
	transport.put_data(PackedByteArray([1, 2, 3]))
	transport.put_data(PackedByteArray([4, 5]))
	assert_eq(socket.sent, [PackedByteArray([1, 2, 3]), PackedByteArray([4, 5])])


func test_every_frame_is_written_as_binary():
	# WebSocketPeer takes the mode per send rather than as a property, so this
	# has to be passed on every write. A frame sent as text is mangled.
	_open()
	transport.put_data(PackedByteArray([1, 2, 3]))
	transport.put_data(PackedByteArray([4]))
	assert_eq(socket.sent_modes,
		[WebSocketPeer.WRITE_MODE_BINARY, WebSocketPeer.WRITE_MODE_BINARY])


func test_the_buffers_hold_a_whole_frame():
	# The peer's default is 64 KiB and a compressed LoadMapPacket is bigger;
	# anything that does not fit is dropped rather than split.
	transport.connect_to_host("127.0.0.1", 2223)
	assert_eq(socket.inbound_buffer_size, NetFrame.MAX_FRAME_SIZE)
	assert_eq(socket.outbound_buffer_size, NetFrame.MAX_FRAME_SIZE)


func test_a_write_error_is_reported():
	_open()
	socket.put_error = ERR_BUSY
	assert_eq(transport.put_data(PackedByteArray([1])), ERR_BUSY)


func test_writing_before_connecting_fails():
	assert_eq(transport.put_data(PackedByteArray([1])), ERR_UNAVAILABLE)


func test_disconnecting_before_connecting_is_harmless():
	transport.disconnect_from_host()
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE)


func test_no_delay_reaches_the_socket():
	# The peer has the same knob the TCP one does. A 64Hz movement packet must
	# not sit waiting for Nagle to fill a segment.
	_open()
	transport.set_no_delay(true)
	assert_true(socket.no_delay_set)


func test_no_delay_before_connecting_is_harmless():
	transport.set_no_delay(true)
	assert_false(socket.no_delay_set)


func test_no_delay_is_not_asked_of_a_browser():
	# The web export's peer has no such knob and prints an error when asked
	# ("'set_no_delay' is not supported in Web export"); the socket is the
	# page's own and Nagle is not ours to turn off there.
	transport.on_web = true
	_open()
	transport.set_no_delay(true)
	assert_false(socket.no_delay_set)
