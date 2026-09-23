extends GutTest

## The Terms of Use gate: the two calls (AccountTerms), where sign-in asks
## (AccountSignIn), the screen that asks (TermsGate) and the login screen
## putting them together. It fails closed at every step.

const NEEDS := {"currentVersion": 1, "acceptedVersion": 0, "needsAcceptance": true}
const ACCEPTED := {"currentVersion": 1, "acceptedVersion": 1, "needsAcceptance": false}

var service: DataService
var backend: FakeHttpBackend


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	add_child_autofree(service)


func _paths() -> Array:
	return backend.requests.map(func(r: Dictionary) -> String: return r["url"].trim_prefix("http://data.test"))


func _signed_in() -> void:
	service.token = "tok"
	service.account_guid = "g"


# --- AccountTerms -------------------------------------------------------------

func test_status_asks_with_the_session_and_reads_needs_acceptance():
	_signed_in()
	backend.push_json(200, NEEDS)
	var got: Dictionary = await AccountTerms.status(service)
	assert_eq(got, {"success": true, "needs": true})
	assert_eq(backend.requests[0]["method"], HTTPClient.METHOD_GET)
	assert_eq(_paths(), ["/admin/account/terms"])
	assert_true("Authorization: tok" in backend.requests[0]["headers"])
	backend.push_json(200, ACCEPTED)
	got = await AccountTerms.status(service)
	assert_eq(got, {"success": true, "needs": false})


func test_status_without_a_session_sends_nothing():
	var got: Dictionary = await AccountTerms.status(service)
	assert_false(got["success"])
	assert_eq(backend.requests.size(), 0)


func test_status_that_does_not_say_is_a_failure_not_a_pass():
	_signed_in()
	for body in [{"currentVersion": 1}, {"needsAcceptance": "false"}, [1, 2]]:
		backend.push_json(200, body)
		var got: Dictionary = await AccountTerms.status(service)
		assert_false(got["success"], "%s is no answer" % str(body))
	backend.push_json(401, {"reason": "expired"})
	var refused: Dictionary = await AccountTerms.status(service)
	assert_false(refused["success"])
	assert_string_contains(refused["result"], "expired")


func test_accept_posts_with_the_session():
	_signed_in()
	backend.push_json(200, {"ok": true, "acceptedVersion": 1})
	var got: Dictionary = await AccountTerms.accept(service)
	assert_true(got["success"])
	assert_eq(backend.requests[0]["method"], HTTPClient.METHOD_POST)
	assert_eq(_paths(), ["/admin/account/terms/accept"])
	assert_true("Authorization: tok" in backend.requests[0]["headers"])
	backend.push_json(500, {"reason": "Account not found"})
	got = await AccountTerms.accept(service)
	assert_false(got["success"])
	assert_string_contains(got["result"], "Account not found")
	service.sign_out()
	got = await AccountTerms.accept(service)
	assert_false(got["success"], "no session, no call")
	assert_eq(backend.requests.size(), 2)


# --- AccountSignIn ------------------------------------------------------------

func _login(terms: Dictionary) -> void:
	backend.push_json(200, {"accountGuid": "g", "token": "tok"})
	backend.push_json(200, terms)


func test_an_account_that_has_accepted_is_never_asked():
	_login(ACCEPTED)
	backend.push_json(200, {"characters": [{"characterUuid": "c1"}]})
	var asked := [0]
	var ask := func() -> bool:
		asked[0] += 1
		return false
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b", ask)
	assert_true(got["success"])
	assert_eq(asked[0], 0)
	assert_eq(_paths(), ["/admin/account/login", "/admin/account/terms", "/data/account/g"])


func test_agreeing_records_the_acceptance_then_lists():
	_login(NEEDS)
	backend.push_json(200, {"ok": true, "acceptedVersion": 1})
	backend.push_json(200, {"characters": [{"characterUuid": "c1"}]})
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b", func() -> bool: return true)
	assert_true(got["success"])
	assert_eq(got["characters"].size(), 1)
	assert_eq(_paths(), ["/admin/account/login", "/admin/account/terms",
		"/admin/account/terms/accept", "/data/account/g"])


func test_declining_signs_out_and_goes_no_further():
	_login(NEEDS)
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b", func() -> bool: return false)
	assert_false(got["success"])
	assert_eq(got["result"], AccountSignIn.DECLINED)
	assert_eq(_paths(), ["/admin/account/login", "/admin/account/terms"], "nothing accepted, nothing listed")
	assert_eq(service.token, "", "signed out")
	assert_eq(service.account_guid, "")


func test_no_one_to_ask_is_a_refusal():
	_login(NEEDS)
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b")
	assert_eq(got["result"], AccountSignIn.DECLINED)


func test_a_status_that_cannot_be_read_blocks_and_signs_out():
	_login({"weird": true})
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b", func() -> bool: return true)
	assert_eq(got["result"], AccountSignIn.UNVERIFIED)
	assert_eq(service.token, "")
	assert_eq(backend.requests.size(), 2, "no list fetched")


func test_an_acceptance_that_is_not_recorded_blocks_and_signs_out():
	_login(NEEDS)
	backend.push_json(500, {"reason": "database down"})
	var got: Dictionary = await AccountSignIn.sign_in(service, "a", "b", func() -> bool: return true)
	assert_eq(got["result"], AccountSignIn.UNRECORDED)
	assert_eq(service.token, "")
	assert_eq(backend.requests.size(), 3, "no list fetched")
