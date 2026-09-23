extends GutTest

## The transport seams: the abstract defaults, and the real implementations
## against genuine loopback sockets.

# --- abstract defaults -----------------------------------------------------

func test_base_transport_defaults_are_inert():
	var transport := NetTransport.new()
	assert_eq(transport.connect_to_host("h", 1), ERR_UNAVAILABLE)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE)
	assert_eq(transport.get_available_bytes(), 0)
	assert_eq(transport.get_data(4)[0], ERR_UNAVAILABLE)
	assert_eq(transport.put_data(PackedByteArray([1])), ERR_UNAVAILABLE)
	transport.poll()
	transport.disconnect_from_host()
	transport.set_no_delay(true)
	pass_test("the base class is safe to call but does nothing")


func test_base_http_backend_reports_a_failure():
	var backend := HttpBackend.new()
	var result: Array = await backend.perform(HTTPClient.METHOD_GET, "http://x", PackedStringArray(), "")
	assert_eq(result[0], HTTPRequest.RESULT_CANT_CONNECT)


# --- TcpTransport over loopback -------------------------------------------

func test_tcp_transport_connects_and_exchanges_bytes():
	var server := TCPServer.new()
	assert_eq(server.listen(0, "127.0.0.1"), OK, "bound an ephemeral port")
	var port := server.get_local_port()

	var transport := TcpTransport.new()
	assert_eq(transport.connect_to_host("127.0.0.1", port), OK)
	transport.set_no_delay(true)

	var peer: StreamPeerTCP = null
	for i in 200:
		transport.poll()
		if server.is_connection_available():
			peer = server.take_connection()
			break
		await wait_process_frames(1)
	assert_not_null(peer, "the server accepted the connection")

	for i in 200:
		transport.poll()
		if transport.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await wait_process_frames(1)
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_CONNECTED)

	assert_eq(transport.put_data(PackedByteArray([1, 2, 3])), OK)
	for i in 200:
		peer.poll()
		if peer.get_available_bytes() >= 3:
			break
		await wait_process_frames(1)
	assert_eq(peer.get_data(3)[1], PackedByteArray([1, 2, 3]), "bytes reached the server")

	peer.put_data(PackedByteArray([9, 8]))
	for i in 200:
		transport.poll()
		if transport.get_available_bytes() >= 2:
			break
		await wait_process_frames(1)
	assert_eq(transport.get_available_bytes(), 2)
	assert_eq(transport.get_data(2)[1], PackedByteArray([9, 8]), "bytes came back")

	transport.disconnect_from_host()
	assert_eq(transport.get_status(), StreamPeerTCP.STATUS_NONE)
	peer.disconnect_from_host()
	server.stop()


func test_tcp_transport_has_nothing_to_read_while_closed():
	# A peer that is not open answers -1 and prints an engine error; the
	# server closing on us after a death ack is the ordinary way to get here.
	assert_eq(TcpTransport.new().get_available_bytes(), 0)


func test_tcp_transport_reports_a_bad_host():
	var transport := TcpTransport.new()
	assert_ne(transport.connect_to_host("", 2222), OK, "an empty host is refused outright")


# --- GodotHttpBackend against a minimal loopback HTTP server --------------

func test_godot_http_backend_performs_a_real_request():
	var server := TCPServer.new()
	assert_eq(server.listen(0, "127.0.0.1"), OK)
	var port := server.get_local_port()

	var host := Node.new()
	add_child_autofree(host)
	var backend := GodotHttpBackend.new(host)

	# The call has to be kicked off without awaiting it (we need to serve the
	# response first), and GDScript forbids calling a coroutine without await --
	# so it goes through a Callable, which defers that check to runtime.
	var completed: Array = []
	Callable(self, "_request_into").call(backend, "http://127.0.0.1:%d/ping" % port, completed)

	var peer: StreamPeerTCP = null
	for i in 400:
		if server.is_connection_available():
			peer = server.take_connection()
			break
		await wait_process_frames(1)
	assert_not_null(peer, "the backend opened a connection")

	for i in 400:
		peer.poll()
		if peer.get_available_bytes() > 0:
			break
		await wait_process_frames(1)
	var request := peer.get_utf8_string(peer.get_available_bytes())
	assert_string_contains(request, "GET /ping")

	var body := '{"pong":true}'
	peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
		% [body.length(), body]).to_utf8_buffer())

	for i in 400:
		if not completed.is_empty():
			break
		await wait_process_frames(1)
	assert_false(completed.is_empty(), "the request completed")
	var result: Array = completed[0]
	assert_eq(result[0], HTTPRequest.RESULT_SUCCESS)
	assert_eq(result[1], 200)
	assert_eq(JSON.parse_string(result[2].get_string_from_utf8())["pong"], true)

	peer.disconnect_from_host()
	server.stop()


func test_godot_http_backend_reports_a_malformed_url():
	var host := Node.new()
	add_child_autofree(host)
	var backend := GodotHttpBackend.new(host)
	var result: Array = await backend.perform(HTTPClient.METHOD_GET, "not a url", PackedStringArray(), "")
	assert_eq(result[0], HTTPRequest.RESULT_CANT_CONNECT, "a bad url fails before any I/O")


func _request_into(backend: HttpBackend, url: String, out: Array) -> void:
	out.append(await backend.perform(HTTPClient.METHOD_GET, url,
		PackedStringArray(["Accept: application/json"]), ""))


func test_heartbeat_fires_on_the_interval_and_resets():
	var beat := Heartbeat.new(1.0)
	assert_false(beat.tick(0.5))
	assert_true(beat.tick(0.6), "due once the interval elapses")
	assert_false(beat.tick(0.5), "the timer restarts after firing")
	beat.tick(0.4)
	beat.reset()
	assert_false(beat.tick(0.9), "reset clears accumulated time")


func test_unhandled_command_ids_are_ignored():
	var result := LoginHandshake.interpret({
		"commandId": LoginHandshake.SERVER_COMMAND,
		"command": JSON.stringify({"command": "/tp 1 1"}),
	})
	assert_eq(result["kind"], "ignored")


func test_json_int64_survives_a_full_precision_player_id():
	# A double has 53 bits of mantissa, so this id rounds to ...272 if it is
	# read through JSON.parse_string. The server then disconnects the session
	# for a player-id mismatch.
	var raw := '{"playerId":3088558154868086650,"classId":2,"success":true}'
	assert_ne(int(JSON.parse_string(raw)["playerId"]), 3088558154868086650,
		"precondition: the plain parse really does lose precision")
	assert_eq(JsonInt64.read_field(raw, "playerId"), 3088558154868086650)


func test_json_int64_handles_absent_and_negative_fields():
	assert_eq(JsonInt64.read_field('{"a":1}', "missing", -7), -7)
	assert_eq(JsonInt64.read_field('{"realmId":-722330971493458551}', "realmId"),
		-722330971493458551)


func test_json_int64_repair_leaves_other_fields_alone():
	var raw := '{"playerId":3088558154868086650,"classId":2}'
	var repaired: Dictionary = JsonInt64.repair(raw, JSON.parse_string(raw), ["playerId"])
	assert_eq(repaired["playerId"], 3088558154868086650)
	assert_eq(int(repaired["classId"]), 2)


func test_json_int64_repair_passes_through_non_objects():
	assert_eq(JsonInt64.repair("[1,2]", [1, 2], ["playerId"]), [1, 2])


func test_login_response_keeps_full_player_id_precision():
	var result := LoginHandshake.interpret({
		"commandId": LoginHandshake.LOGIN_RESPONSE,
		"command": '{"playerId":3088558154868086650,"classId":2,"success":true,'
			+ '"spawnX":2048.0,"spawnY":2048.0}',
	})
	assert_eq(result["kind"], "login_ok")
	assert_eq(int(result["body"]["playerId"]), 3088558154868086650,
		"the id the server will validate our input packets against")


func test_godot_http_backend_runs_requests_side_by_side():
	# Two requests started together open two connections, on two nodes; a
	# third, after both landed, reuses one rather than adding a third.
	var server := TCPServer.new()
	assert_eq(server.listen(0, "127.0.0.1"), OK)
	var port := server.get_local_port()
	var host := Node.new()
	add_child_autofree(host)
	var backend := GodotHttpBackend.new(host)
	var completed: Array = []
	Callable(self, "_request_into").call(backend, "http://127.0.0.1:%d/one" % port, completed)
	Callable(self, "_request_into").call(backend, "http://127.0.0.1:%d/two" % port, completed)

	var peers: Array = []
	for i in 400:
		if server.is_connection_available():
			peers.append(server.take_connection())
		if peers.size() == 2:
			break
		await wait_process_frames(1)
	assert_eq(peers.size(), 2, "both connections were opened before either was answered")
	assert_eq(host.get_child_count(), 2, "one HTTPRequest node each")
	assert_eq(backend.pool_size(), 2)

	for peer in peers:
		for i in 400:
			peer.poll()
			if peer.get_available_bytes() > 0:
				break
			await wait_process_frames(1)
		peer.get_utf8_string(peer.get_available_bytes())
		peer.put_data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".to_utf8_buffer())
	for i in 400:
		if completed.size() == 2:
			break
		await wait_process_frames(1)
	assert_eq(completed.size(), 2, "both completed")

	Callable(self, "_request_into").call(backend, "http://127.0.0.1:%d/three" % port, completed)
	for i in 400:
		if server.is_connection_available():
			peers.append(server.take_connection())
			break
		await wait_process_frames(1)
	assert_eq(peers.size(), 3, "the third connected")
	assert_eq(host.get_child_count(), 2, "on a node from the pool")
	peers[2].put_data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".to_utf8_buffer())
	for i in 400:
		if completed.size() == 3:
			break
		await wait_process_frames(1)
	assert_eq(completed.size(), 3)
