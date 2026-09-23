extends GutTest

## DataService against scripted HTTP completions.

var service: DataService
var backend: FakeHttpBackend


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	add_child_autofree(service)
	watch_signals(service)


# --- interpret_response (pure) --------------------------------------------

func test_interprets_a_successful_json_body():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_SUCCESS, 200, '{"a":1}'.to_utf8_buffer(), "http://x")
	assert_true(result["ok"])
	assert_eq(int(result["body"]["a"]), 1)


func test_interprets_a_transport_failure():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray(), "http://x")
	assert_false(result["ok"])
	assert_string_contains(result["error"], "unreachable")


func test_interprets_an_error_body_with_a_reason():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_SUCCESS, 400, '{"reason":"bad password"}'.to_utf8_buffer(), "http://x")
	assert_false(result["ok"])
	assert_string_contains(result["error"], "bad password")
	assert_string_contains(result["error"], "400")


func test_interprets_an_error_body_with_a_message():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_SUCCESS, 500, '{"message":"boom"}'.to_utf8_buffer(), "http://x")
	assert_string_contains(result["error"], "boom")


func test_interprets_a_non_json_error_body():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_SUCCESS, 502, "<html>gateway</html>".to_utf8_buffer(), "http://x")
	assert_false(result["ok"])
	assert_string_contains(result["error"], "gateway")


func test_interprets_a_success_with_a_non_json_body():
	var result := DataService.interpret_response(
		HTTPRequest.RESULT_SUCCESS, 200, "plain".to_utf8_buffer(), "http://x")
	assert_true(result["ok"])
	assert_null(result["body"], "unparseable bodies come back as null, not a crash")


# --- login -----------------------------------------------------------------

func test_login_posts_credentials_and_stores_the_token():
	backend.push_json(200, {"accountGuid": "guid-1", "token": "tok-1"})
	var result: Dictionary = await service.login("me@example.com", "pw")
	assert_true(result["success"])
	assert_eq(service.token, "tok-1")
	assert_eq(service.account_guid, "guid-1")

	var request: Dictionary = backend.requests[0]
	assert_eq(request["method"], HTTPClient.METHOD_POST)
	assert_eq(request["url"], "http://data.test/admin/account/login")
	var body: Dictionary = JSON.parse_string(request["body"])
	assert_eq(body["email"], "me@example.com")
	assert_eq(body["password"], "pw")


func test_login_reports_a_rejection():
	backend.push_json(400, {"reason": "no such account"})
	var result: Dictionary = await service.login("a", "b")
	assert_false(result["success"])
	assert_string_contains(str(result["result"]), "no such account")
	assert_eq(service.token, "")


func test_login_reports_an_unexpected_body():
	backend.push_json(200, {"somethingElse": true})
	var result: Dictionary = await service.login("a", "b")
	assert_false(result["success"])
	assert_string_contains(str(result["result"]), "unexpected login response")


func test_login_reports_an_unreachable_service():
	backend.push_raw(HTTPRequest.RESULT_CANT_CONNECT, 0, "")
	var result: Dictionary = await service.login("a", "b")
	assert_false(result["success"])


# --- characters ------------------------------------------------------------

func test_fetch_characters_sends_the_bare_token():
	backend.push_json(200, {"accountGuid": "guid-1", "token": "tok-1"})
	await service.login("a", "b")

	backend.push_json(200, {"characters": [{"characterUuid": "c1", "characterClass": 2}]})
	var result: Dictionary = await service.fetch_characters()
	assert_true(result["success"])
	assert_eq(result["characters"].size(), 1)
	assert_eq(result["characters"][0]["characterUuid"], "c1")

	var request: Dictionary = backend.requests[1]
	assert_eq(request["url"], "http://data.test/data/account/guid-1")
	assert_has(request["headers"], "Authorization: tok-1", "raw token, no Bearer prefix")


func test_fetch_characters_without_a_session_fails_fast():
	var result: Dictionary = await service.fetch_characters()
	assert_false(result["success"])
	assert_eq(backend.requests.size(), 0, "no request is made without a token")


func test_fetch_characters_handles_an_error_response():
	service.token = "t"
	service.account_guid = "g"
	backend.push_json(401, {"reason": "expired"})
	var result: Dictionary = await service.fetch_characters()
	assert_false(result["success"])


func test_fetch_characters_handles_a_non_object_body():
	service.token = "t"
	service.account_guid = "g"
	backend.push_json(200, ["unexpected"])
	var result: Dictionary = await service.fetch_characters()
	assert_false(result["success"])


func test_account_without_characters_returns_an_empty_list():
	service.token = "t"
	service.account_guid = "g"
	backend.push_json(200, {"accountUuid": "g"})
	var result: Dictionary = await service.fetch_characters()
	assert_true(result["success"])
	assert_eq(result["characters"], [])


# --- create character --------------------------------------------------------

func test_create_character_posts_the_class_and_returns_the_account_list():
	service.token = "tok-1"
	service.account_guid = "guid-1"
	backend.push_json(200, {"accountUuid": "guid-1", "characters": [
		{"characterUuid": "c1", "characterClass": 0},
		{"characterUuid": "c2", "characterClass": 7},
	]})
	var result: Dictionary = await service.create_character(7)
	assert_true(result["success"])
	assert_eq(result["result"].size(), 2, "the whole account comes back, so no second fetch")
	assert_eq(result["result"][1]["characterUuid"], "c2")

	var request: Dictionary = backend.requests[0]
	assert_eq(request["method"], HTTPClient.METHOD_POST)
	assert_eq(request["url"], "http://data.test/data/account/guid-1/character?classId=7")
	assert_eq(request["body"], "", "the class travels as a query parameter")
	assert_has(request["headers"], "Authorization: tok-1")
	assert_signal_emitted_with_parameters(service, "character_created", [true, result["result"]])


func test_create_character_without_a_session_fails_fast():
	var result: Dictionary = await service.create_character(0)
	assert_false(result["success"])
	assert_eq(backend.requests.size(), 0)


func test_create_character_reports_the_services_reason():
	service.token = "t"
	service.account_guid = "g"
	backend.push_json(400, {"message": "Failed to create character", "reason": "Character limit reached (15 max)"})
	var result: Dictionary = await service.create_character(0)
	assert_false(result["success"])
	assert_string_contains(str(result["result"]), "Character limit reached (15 max)")


func test_create_character_handles_a_non_object_body():
	service.token = "t"
	service.account_guid = "g"
	backend.push_json(200, "ok")
	var result: Dictionary = await service.create_character(0)
	assert_false(result["success"])
	assert_string_contains(str(result["result"]), "unexpected")


func test_headers_include_content_type_and_optional_auth():
	service.token = "abc"
	assert_has(service.headers_for(false), "Content-Type: application/json")
	assert_does_not_have(service.headers_for(false), "Authorization: abc")
	assert_has(service.headers_for(true), "Authorization: abc")


func test_signals_are_emitted_alongside_the_return_value():
	backend.push_json(200, {"accountGuid": "g", "token": "t"})
	await service.login("a", "b")
	assert_signal_emitted_with_parameters(service, "login_completed", [true, {"accountGuid": "g", "token": "t"}])

	backend.push_json(200, {"characters": []})
	await service.fetch_characters()
	assert_signal_emitted_with_parameters(service, "characters_completed", [true, []])
