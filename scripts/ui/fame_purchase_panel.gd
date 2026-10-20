class_name FamePurchasePanel
extends CanvasLayer

## Buy Fame: the data service's fame packages, paid through Stripe Checkout.
##
## Buy asks the service for a checkout session and opens its page outside the
## game -- a new browser tab on the web (the game's own tab would drop the
## session), the system browser on the desktop -- then polls the purchase
## until the service has credited the fame, the checkout expires, or ten
## minutes pass. The client never credits anything itself. The Buy Fame
## entries show only while the service says purchases are on.

enum Phase { BROWSING, STARTING, WAITING, FINISHED }

const TITLE := "BUY FAME"
const POLL_INTERVAL := 2.0
const POLL_LIMIT := 600.0
## After a failed package request; a "disabled" answer is not retried.
const RETRY_INTERVAL := 60.0
const COLUMNS := 2
const CARD_WIDTH := 160.0
const BUTTON_HEIGHT := 44.0
const PANEL_WIDTH := 360.0
const GOLD := Color("f0d890")
const TAG_COLOUR := Color("ffb347")
const BORDER := Color("8a6d3b")

var data_service: DataService
## Opens a checkout page and answers whether it opened; tests replace it.
var open_url: Callable = FamePurchasePanel.open_external

var enabled := false
var packages: Array = []
var phase := Phase.BROWSING
var message := ""
var session_id := ""
var checkout_url := ""

var _root: PanelContainer
var _balance: Label
var _cards: GridContainer
var _buy_buttons: Array[Button] = []
var _status: Label
var _continue: Button
var _cancel: Button
var _catalogue_token := ""
var _catalogue_pending := false
var _retry_in := 0.0
var _since_poll := 0.0
var _waited := 0.0
var _polling := false
## Bumped per Buy, so a checkout answer for an abandoned attempt is dropped.
var _attempt := 0
## Held so the browser's focus/visibility listener is not collected.
var _return_callback: JavaScriptObject


## The page, outside the game. On the web a new tab: false when a popup
## blocker refused it, so the panel's Continue button can try on a fresh click.
static func open_external(url: String) -> bool:
	if not OS.has_feature("web"):
		return OS.shell_open(url) == OK
	var opened: Variant = JavaScriptBridge.eval("""
		(function (url) {
			var tab = window.open(url, '_blank');
			if (!tab) return false;
			try { tab.opener = null; } catch (e) {}
			return true;
		})(%s)
	""" % JSON.stringify(url), true)
	return opened == true


@warning_ignore("integer_division")
static func price_text(cents: int) -> String:
	var whole := maxi(cents, 0)
	return "$%d.%02d" % [whole / 100, whole % 100]


static func package_label(package: Dictionary) -> String:
	var label := str(package.get("label", ""))
	if label != "":
		return label
	return "%s Fame" % Mastery.thousands(int(package.get("fame", 0)))


func _ready() -> void:
	layer = 22   # over the home screen (20), which opens it too
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_root.add_theme_stylebox_override("panel", _box(Color("14171f"), BORDER, 2, 8, 14))
	centre.add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_root.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := HudWidgets.label(TITLE, 18, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var close_button := TouchButtons.flat("Close", Vector2(72, BUTTON_HEIGHT), close)
	bar.add_child(close_button)
	_balance = HudWidgets.label("", 14, PlayerHud.GOLD)
	column.add_child(_balance)
	_cards = GridContainer.new()
	_cards.columns = COLUMNS
	_cards.add_theme_constant_override("h_separation", 10)
	_cards.add_theme_constant_override("v_separation", 10)
	column.add_child(_cards)
	_status = HudWidgets.label("", 14, Color.WHITE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.x = PANEL_WIDTH - 28.0
	column.add_child(_status)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_continue = _buy_button("Continue to checkout", continue_checkout)
	actions.add_child(_continue)
	_cancel = TouchButtons.flat("Cancel", Vector2(96, BUTTON_HEIGHT), cancel)
	actions.add_child(_cancel)
	var where := "a new tab" if OS.has_feature("web") else "your browser"
	var note := HudWidgets.label("Payments by Stripe. Checkout opens in %s." % where,
		11, InventoryLayout.HEADING_COLOUR)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.x = PANEL_WIDTH - 28.0
	column.add_child(note)
	_build_cards()
	_show()
	TouchFrame.adopt(self)
	if OS.has_feature("web"):
		_listen_for_return()


func _process(delta: float) -> void:
	_follow_session(delta)
	if not visible:
		return
	if phase == Phase.WAITING:
		tick(delta)
	_show()
	PanelFit.shrink(_root)


## Whether the Buy Fame entries should show.
func available() -> bool:
	return enabled and not packages.is_empty()


func open() -> void:
	if phase == Phase.FINISHED:
		phase = Phase.BROWSING
		message = ""
	visible = true
	if data_service != null:
		data_service.refresh_account()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Shut, and stop waiting: a purchase still completes, it is just not watched.
func close() -> void:
	visible = false
	if phase != Phase.FINISHED:
		cancel()


func cancel() -> void:
	phase = Phase.BROWSING
	message = ""
	session_id = ""
	checkout_url = ""


func captures_mouse() -> bool:
	return visible


## Fills the panel from a /data/fame/packages answer.
func show_catalogue(body: Dictionary) -> void:
	enabled = bool(body.get("enabled", false))
	packages = []
	for entry in body.get("packages", []):
		if entry is Dictionary and str(entry.get("id", "")) != "":
			packages.append(entry)
	if is_node_ready():
		_build_cards()


func buy(package_id: String) -> void:
	if phase == Phase.STARTING or phase == Phase.WAITING or data_service == null:
		return
	phase = Phase.STARTING
	message = "Opening checkout..."
	_attempt += 1
	var attempt := _attempt
	var result: Dictionary = await data_service.fame_checkout(package_id)
	if phase != Phase.STARTING or attempt != _attempt:
		return
	if not result["success"]:
		phase = Phase.BROWSING
		var reason := str(result["result"])
		if reason.begins_with("HTTP 503"):
			enabled = false
			message = "Fame purchases are unavailable right now."
		else:
			message = "Could not start checkout: %s" % reason
		return
	var checkout: Dictionary = result["result"]
	session_id = str(checkout.get("sessionId", ""))
	checkout_url = str(checkout.get("url", ""))
	if session_id == "" or checkout_url == "":
		phase = Phase.BROWSING
		message = "Could not start checkout. Please try again."
		return
	phase = Phase.WAITING
	_waited = 0.0
	_since_poll = 0.0
	_show_waiting(open_url.call(checkout_url))


## The Continue button: the checkout again, on a click the browser will honour.
func continue_checkout() -> void:
	if phase == Phase.WAITING and checkout_url != "":
		_show_waiting(open_url.call(checkout_url))


## The wait's clock: a status request every POLL_INTERVAL, until POLL_LIMIT.
func tick(delta: float) -> void:
	_waited += delta
	_since_poll += delta
	if _waited >= POLL_LIMIT:
		finish("Stopped checking. If you finished paying, your fame will be added shortly.")
	elif _since_poll >= POLL_INTERVAL and not _polling:
		poll()


func poll() -> void:
	if phase != Phase.WAITING or _polling or data_service == null:
		return
	_polling = true
	_since_poll = 0.0
	var asked := session_id
	var result: Dictionary = await data_service.fame_purchase_status(asked)
	_polling = false
	# A failed check is retried on the next tick; the checkout may still be open.
	if phase == Phase.WAITING and asked == session_id and result["success"]:
		apply_status(result["result"])


func apply_status(purchase: Dictionary) -> void:
	match str(purchase.get("status", "")):
		"CREDITED":
			var fame := int(purchase.get("fame", 0))
			if purchase.has("accountFame") and data_service != null:
				data_service.account["accountFame"] = int(purchase["accountFame"])
			finish("+%s fame added!" % Mastery.thousands(fame))
			Sfx.event("loot_untiered")
			if data_service != null:
				data_service.refresh_account()
		"PAID":
			message = "Payment received. Adding your fame..."
		"EXPIRED":
			finish("Checkout expired. Pick a package to try again.")
		"REFUNDED":
			finish("This payment was refunded.")
		"DISPUTED":
			finish("This payment is disputed.")


func finish(text: String) -> void:
	phase = Phase.FINISHED
	message = text
	session_id = ""
	checkout_url = ""


func balance() -> int:
	if data_service == null:
		return 0
	return int(data_service.account.get("accountFame", 0))


## Fetches the packages once per session, and again a while after a failure.
func _follow_session(delta: float) -> void:
	if data_service == null:
		return
	var token := data_service.token
	if token == "":
		if _catalogue_token != "":
			_catalogue_token = ""
			show_catalogue({})
			close()
		return
	if _retry_in > 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_catalogue_token = ""
	if token != _catalogue_token and not _catalogue_pending:
		_load_catalogue(token)


func _load_catalogue(token: String) -> void:
	_catalogue_token = token
	_catalogue_pending = true
	var body: Dictionary = await data_service.fame_packages()
	_catalogue_pending = false
	if token != data_service.token:
		return
	show_catalogue(body)
	if body.is_empty():
		_retry_in = RETRY_INTERVAL


func _show_waiting(opened: bool) -> void:
	if opened:
		message = "Waiting for payment... Finish checkout, then come back here."
	else:
		message = "Your browser blocked the checkout tab. Press Continue to checkout."


func _show() -> void:
	_balance.text = "Your fame: %s" % Mastery.thousands(balance())
	var busy := phase == Phase.STARTING or phase == Phase.WAITING
	for button in _buy_buttons:
		button.disabled = busy
	var text := message
	if text == "" and not available():
		text = "Fame purchases are unavailable right now."
	_status.text = text
	_status.visible = text != ""
	_continue.visible = phase == Phase.WAITING
	_cancel.visible = phase == Phase.WAITING


func _build_cards() -> void:
	for child in _cards.get_children():
		child.free()
	_buy_buttons.clear()
	var any_tag := packages.any(func(entry: Dictionary) -> bool: return str(entry.get("tag", "")) != "")
	for entry in packages:
		var package_id := str(entry["id"])
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
		card.add_theme_stylebox_override("panel", _box(Color("1d212c"), Color("3a3f4e"), 1, 6, 10))
		_cards.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		card.add_child(stack)
		# Untagged cards keep an empty tag line so the names line up.
		if any_tag:
			var tag := HudWidgets.label(str(entry.get("tag", "")), 11, TAG_COLOUR)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stack.add_child(tag)
		var caption := HudWidgets.label(package_label(entry), 17, Color.WHITE)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(caption)
		var button := _buy_button("Buy  %s" % price_text(int(entry.get("priceCents", 0))),
			func() -> void: buy(package_id))
		stack.add_child(button)
		_buy_buttons.append(button)


func _buy_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	button.add_theme_stylebox_override("normal", _box(Color("3d3015"), PlayerHud.GOLD, 1, 4, 6))
	button.add_theme_stylebox_override("hover", _box(Color("54421d"), GOLD, 1, 4, 6))
	button.add_theme_stylebox_override("pressed", _box(Color("6b5424"), GOLD, 1, 4, 6))
	button.add_theme_stylebox_override("disabled", _box(Color("24221e"), Color("4a4436"), 1, 4, 6))
	return button


## The player back from the checkout tab: check at once rather than on the clock.
func _listen_for_return() -> void:
	_return_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if phase == Phase.WAITING:
			_since_poll = POLL_INTERVAL)
	var document: Variant = JavaScriptBridge.get_interface("document")
	var window: Variant = JavaScriptBridge.get_interface("window")
	if document != null:
		document.addEventListener("visibilitychange", _return_callback)
	if window != null:
		window.addEventListener("focus", _return_callback)


static func _box(fill: Color, border: Color, border_width: int, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
