extends GutTest

## Buy Fame: the packages the data service sells, a Stripe Checkout opened
## outside the game, and the purchase polled until the fame is credited.

const CATALOGUE := {"enabled": true, "currency": "usd", "packages": [
	{"id": "fame_1k", "fame": 1000, "priceCents": 99, "label": "1,000 Fame"},
	{"id": "fame_5k", "fame": 5000, "priceCents": 499, "label": "5,000 Fame", "tag": "Popular"}]}
const CHECKOUT := {"sessionId": "cs_test_1", "url": "https://checkout.stripe.com/c/pay/cs_test_1"}


## Holds each answer until released, so the panel can change its mind mid-request.
class GatedBackend extends FakeHttpBackend:
	signal release

	func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
		await release
		return super.perform(method, url, headers, body)


var service: DataService
var backend: FakeHttpBackend
var panel: FamePurchasePanel
var opened: Array = []
var tab_opens := true


func before_each():
	backend = FakeHttpBackend.new()
	service = DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	service.token = "tok"
	service.account_guid = "guid-1"
	service.account = {"accountFame": 1200}
	add_child_autofree(service)
	opened = []
	tab_opens = true
	panel = FamePurchasePanel.new()
	panel.data_service = service
	panel.open_url = func(url: String) -> bool:
		opened.append(url)
		return tab_opens
	add_child_autofree(panel)
	# Stepped by hand, so a frame between tests cannot spend a scripted answer.
	panel.set_process(false)


func _start_checkout() -> void:
	panel.show_catalogue(CATALOGUE)
	panel.open()
	backend.requests.clear()
	backend.push_json(200, CHECKOUT)
	await panel.buy("fame_5k")


func test_prices_read_as_dollars_and_cents():
	assert_eq(FamePurchasePanel.price_text(499), "$4.99")
	assert_eq(FamePurchasePanel.price_text(1000), "$10.00")
	assert_eq(FamePurchasePanel.price_text(99), "$0.99")
	assert_eq(FamePurchasePanel.price_text(5), "$0.05")
	assert_eq(FamePurchasePanel.price_text(-3), "$0.00")


func test_a_package_without_a_label_is_named_by_its_fame():
	assert_eq(FamePurchasePanel.package_label({"fame": 25000}), "25,000 Fame")
	assert_eq(FamePurchasePanel.package_label({"fame": 25000, "label": "Big Pile"}), "Big Pile")


func test_the_packages_load_once_signed_in_and_fill_the_cards():
	backend.push_json(200, CATALOGUE)
	panel._process(0.0)
	assert_eq(backend.requests.size(), 1)
	assert_eq(backend.requests[0]["url"], "http://data.test/data/fame/packages")
	assert_true(panel.available())
	assert_eq(panel._buy_buttons.size(), 2)
	assert_eq(panel._buy_buttons[1].text, "Buy  $4.99")
	panel._process(0.0)
	assert_eq(backend.requests.size(), 1, "once per session")


func test_switched_off_or_unreachable_hides_the_entry():
	backend.push_json(200, {"enabled": false, "packages": CATALOGUE["packages"]})
	panel._process(0.0)
	assert_false(panel.available())
	var unreachable := FamePurchasePanel.new()
	unreachable.data_service = service
	add_child_autofree(unreachable)
	unreachable.set_process(false)
	unreachable._process(0.0)
	assert_false(unreachable.available(), "a failed request hides it too")


func test_a_failed_catalogue_is_asked_for_again_later():
	panel._process(0.0)
	assert_false(panel.available())
	backend.push_json(200, CATALOGUE)
	panel._process(FamePurchasePanel.RETRY_INTERVAL + 1.0)
	assert_true(panel.available())


func test_signing_out_hides_the_entry():
	backend.push_json(200, CATALOGUE)
	panel._process(0.0)
	service.sign_out()
	panel._process(0.0)
	assert_false(panel.available())


func test_buy_starts_a_checkout_and_opens_it_outside_the_game():
	await _start_checkout()
	var request: Dictionary = backend.requests[0]
	assert_eq(request["method"], HTTPClient.METHOD_POST)
	assert_eq(request["url"], "http://data.test/data/account/guid-1/fame/checkout")
	assert_eq(JSON.parse_string(request["body"]), {"packageId": "fame_5k"})
	assert_eq(opened, [CHECKOUT["url"]])
	assert_eq(panel.phase, FamePurchasePanel.Phase.WAITING)
	assert_string_contains(panel.message, "Waiting for payment")
	panel._show()
	assert_true(panel._continue.visible, "a way back to the checkout")
	assert_true(panel._buy_buttons[0].disabled, "one checkout at a time")


func test_a_blocked_tab_says_so_and_continue_tries_again():
	tab_opens = false
	await _start_checkout()
	assert_string_contains(panel.message, "blocked")
	tab_opens = true
	panel.continue_checkout()
	assert_eq(opened.size(), 2)
	assert_string_contains(panel.message, "Waiting for payment")


func test_a_disabled_service_turns_the_entry_off():
	panel.show_catalogue(CATALOGUE)
	backend.push_json(503, {"message": "Stripe disabled"})
	await panel.buy("fame_5k")
	assert_eq(panel.phase, FamePurchasePanel.Phase.BROWSING)
	assert_false(panel.available())
	assert_eq(opened, [])
	assert_string_contains(panel.message, "unavailable")


func test_a_refused_checkout_says_why():
	panel.show_catalogue(CATALOGUE)
	backend.push_json(400, {"reason": "unknown package"})
	await panel.buy("fame_5k")
	assert_eq(panel.phase, FamePurchasePanel.Phase.BROWSING)
	assert_string_contains(panel.message, "unknown package")


func test_the_purchase_is_polled_every_two_seconds_until_credited():
	await _start_checkout()
	backend.requests.clear()
	panel.tick(1.0)
	assert_eq(backend.requests.size(), 0, "not yet")
	backend.push_json(200, {"sessionId": "cs_test_1", "status": "CREATED"})
	panel.tick(1.0)
	assert_eq(backend.requests[0]["url"], "http://data.test/data/account/guid-1/fame/purchases/cs_test_1")
	assert_eq(panel.phase, FamePurchasePanel.Phase.WAITING)
	backend.push_json(200, {"sessionId": "cs_test_1", "status": "PAID", "fame": 5000})
	panel.tick(2.0)
	assert_string_contains(panel.message, "Payment received")
	backend.push_json(200, {"sessionId": "cs_test_1", "status": "CREDITED", "fame": 5000,
		"packageId": "fame_5k", "accountFame": 6200})
	panel.tick(2.0)
	assert_eq(panel.phase, FamePurchasePanel.Phase.FINISHED)
	assert_eq(panel.message, "+5,000 fame added!")
	assert_eq(panel.balance(), 6200)
	assert_eq(backend.requests[-1]["url"], "http://data.test/data/account/guid-1", "the account re-read")
	backend.requests.clear()
	panel.tick(2.0)
	assert_eq(backend.requests.size(), 0, "done polling")


func test_an_expired_checkout_stops_the_wait():
	await _start_checkout()
	backend.push_json(200, {"sessionId": "cs_test_1", "status": "EXPIRED"})
	panel.tick(2.0)
	assert_eq(panel.phase, FamePurchasePanel.Phase.FINISHED)
	assert_string_contains(panel.message, "Checkout expired")
	panel._show()
	assert_false(panel._buy_buttons[0].disabled, "free to try again")


func test_a_failed_check_keeps_waiting():
	await _start_checkout()
	backend.push_json(502, {"message": "gateway"})
	panel.tick(2.0)
	assert_eq(panel.phase, FamePurchasePanel.Phase.WAITING)


func test_the_wait_gives_up_after_ten_minutes():
	await _start_checkout()
	panel._waited = FamePurchasePanel.POLL_LIMIT - 1.0
	panel._polling = true
	panel.tick(2.0)
	assert_eq(panel.phase, FamePurchasePanel.Phase.FINISHED)
	assert_string_contains(panel.message, "Stopped checking")


func test_closing_stops_the_wait():
	await _start_checkout()
	panel.close()
	assert_false(panel.visible)
	assert_eq(panel.phase, FamePurchasePanel.Phase.BROWSING)
	backend.requests.clear()
	panel._process(5.0)
	var polls := backend.requests.filter(func(request: Dictionary) -> bool:
		return "/fame/purchases/" in request["url"])
	assert_eq(polls, [], "no polling while shut")


func test_a_status_answering_after_cancel_is_ignored():
	await _start_checkout()
	var gated := GatedBackend.new()
	service.backend = gated
	gated.push_json(200, {"sessionId": "cs_test_1", "status": "CREDITED", "fame": 5000})
	panel.poll()
	panel.cancel()
	gated.release.emit()
	assert_eq(panel.phase, FamePurchasePanel.Phase.BROWSING)
	assert_eq(panel.message, "")


func test_a_checkout_answering_after_close_opens_nothing():
	panel.show_catalogue(CATALOGUE)
	panel.open()
	var gated := GatedBackend.new()
	service.backend = gated
	gated.push_json(200, CHECKOUT)
	panel.buy("fame_5k")
	assert_eq(panel.phase, FamePurchasePanel.Phase.STARTING)
	panel.close()
	gated.release.emit()
	assert_eq(opened, [])
	assert_eq(panel.phase, FamePurchasePanel.Phase.BROWSING)


func test_the_balance_is_the_accounts_fame():
	panel.open()
	panel._show()
	assert_eq(panel._balance.text, "Your fame: 1,200")


func test_the_desktop_row_has_buy_fame_only_while_on_sale():
	var cluster: TouchCluster = autofree(TouchCluster.new(false))
	assert_false(cluster._buy_fame.visible)
	cluster.show_buy_fame(true)
	assert_true(cluster._buy_fame.visible)
	var pressed := [false]
	cluster.buy_fame.connect(func() -> void: pressed[0] = true)
	cluster._buy_fame.pressed.emit()
	assert_true(pressed[0])
