class_name EconomyPanel
extends CanvasLayer

## The REALM economy hub (web build): link a Solana wallet, buy the weekly SOL
## membership, and cash earned points out as a REALM payout.
##
## Everything here is a request the server verifies: wallet ownership by an
## ed25519 signature over a server nonce, membership by on-chain SOL receipt,
## and a withdrawal is only queued (an admin settles it manually from their own
## wallet). The client holds no keys and credits nothing itself.

const RECIPIENT := "J9ZGigjmaKYcriwvjZGYqeaB9arofYMHtRorZfu3FQJj"
const DEFAULT_MEMBERSHIP_LAMPORTS := 50000000  # 0.05 SOL fallback if config is slow

## Set by Main after construction.
var data_service
var state: RealmState

var _wallet := PhantomWallet.new()
var _modal: Control
var _wallet_label: Label
var _membership_label: Label
var _points_label: Label
var _amount: SpinBox
var _status: Label
var _link_btn: Button
var _buy_btn: Button
var _cashout_btn: Button
var _open_app_btn: Button
var _config := {}
var _pending := false
var _drawn := -1


func _ready() -> void:
	layer = 56
	_build_modal()


func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(380, 0)
	center.add_child(dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)

	var title := Label.new()
	title.text = "REALM Economy"
	box.add_child(title)

	# Wallet
	_wallet_label = Label.new()
	box.add_child(_wallet_label)
	_link_btn = Button.new()
	_link_btn.text = "Link Solana Wallet"
	_link_btn.pressed.connect(_on_link)
	box.add_child(_link_btn)

	box.add_child(_separator())

	# Membership
	_membership_label = Label.new()
	box.add_child(_membership_label)
	_buy_btn = Button.new()
	_buy_btn.text = "Buy 1 Week Membership"
	_buy_btn.pressed.connect(_on_buy_membership)
	box.add_child(_buy_btn)

	_open_app_btn = Button.new()
	_open_app_btn.text = "Open in Phantom app"
	_open_app_btn.visible = false
	_open_app_btn.pressed.connect(PhantomWallet.open_in_phantom)
	box.add_child(_open_app_btn)

	box.add_child(_separator())

	# Cash out
	_points_label = Label.new()
	box.add_child(_points_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	var lbl := Label.new()
	lbl.text = "Cash out (REALM):"
	row.add_child(lbl)
	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.max_value = 1000000000
	_amount.step = 1000
	_amount.value = 50000
	row.add_child(_amount)
	_cashout_btn = Button.new()
	_cashout_btn.text = "Request Payout"
	_cashout_btn.pressed.connect(_on_cashout)
	box.add_child(_cashout_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 40)
	box.add_child(_status)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _modal.visible = false)
	box.add_child(close)


func _separator() -> HSeparator:
	return HSeparator.new()


func open() -> void:
	_modal.visible = true
	_status.text = ""
	# Seed wallet/membership/points from the account DTO fetched at login; live
	# point changes then arrive via SendPointsPacket.
	if state != null and data_service != null and data_service.account is Dictionary:
		state.progress.seed_from_account(data_service.account)
	var available := PhantomWallet.is_available()
	_link_btn.visible = available
	_buy_btn.visible = available
	_open_app_btn.visible = not available and PhantomWallet.is_mobile_web()
	if not available:
		if PhantomWallet.is_mobile_web():
			_status.text = "On mobile, open this page in the Phantom app to link + pay."
		else:
			_status.text = "Phantom not detected. Install the extension and reload."
	if data_service != null:
		_config = await data_service.economy_config()
	_refresh()


func _process(_delta: float) -> void:
	if not _modal.visible or state == null:
		return
	# Keep labels live as points/membership change (SendPointsPacket bumps version).
	if state.progress.version != _drawn:
		_refresh()


func _refresh() -> void:
	if state != null:
		_drawn = state.progress.version
		var wallet: String = state.progress.linked_wallet
		_wallet_label.text = "Wallet: " + (_short(wallet) if wallet != "" else "not linked")
		_link_btn.text = "Re-link Wallet" if wallet != "" else "Link Solana Wallet"
		var expiry: int = state.progress.membership_expires_ms
		var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
		if expiry > now_ms:
			_membership_label.text = "Membership: active until " + Time.get_datetime_string_from_unix_time(expiry / 1000, true)
		else:
			_membership_label.text = "Membership: inactive (needed to cash out)"
		_points_label.text = "Banked: %d REALM" % state.progress.earned_points
	var lamports := int(_config.get("membershipLamports", DEFAULT_MEMBERSHIP_LAMPORTS))
	_buy_btn.text = "Buy 1 Week (%s SOL)" % String.num(lamports / 1e9, 4)
	var minp := int(_config.get("minWithdrawPoints", 50000))
	_amount.min_value = minp
	if _amount.value < minp:
		_amount.value = minp


func _short(w: String) -> String:
	return w if w.length() <= 10 else (w.substr(0, 4) + "..." + w.substr(w.length() - 4))


# --- Wallet link -------------------------------------------------------------

func _on_link() -> void:
	if _pending:
		return
	_pending = true
	_status.text = "Approve the connection in Phantom..."
	_wallet.connect_wallet(_after_connect)


func _after_connect(res: Dictionary) -> void:
	if not res.get("ok", false):
		_finish("Connect failed: " + str(res.get("error", "?")))
		return
	_status.text = "Fetching challenge..."
	var nonce: String = await data_service.wallet_nonce()
	if nonce == "":
		_finish("Couldn't get a link challenge (signed in?).")
		return
	_status.text = "Sign the challenge in Phantom..."
	_wallet.sign_message(nonce, _after_sign)


func _after_sign(sres: Dictionary) -> void:
	if not sres.get("ok", false):
		_finish("Sign failed: " + str(sres.get("error", "?")))
		return
	var r: Dictionary = await data_service.wallet_link(
		str(sres.get("address", "")), str(sres.get("message", "")), str(sres.get("signature_b64", "")))
	if r.get("success", false):
		if state != null and r.get("result") is Dictionary:
			state.progress.seed_from_account(r["result"])
		_finish("Wallet linked.")
	else:
		_finish("Link failed: " + str(r.get("result", "?")))


# --- Membership --------------------------------------------------------------

func _on_buy_membership() -> void:
	if _pending:
		return
	_pending = true
	_status.text = "Preparing transaction..."
	var lamports := int(_config.get("membershipLamports", DEFAULT_MEMBERSHIP_LAMPORTS))
	var blockhash: String = await data_service.solana_blockhash()
	if blockhash == "":
		_finish("Couldn't get a blockhash.")
		return
	_status.text = "Approve the payment in Phantom..."
	_wallet.buy_fame(lamports, RECIPIENT, blockhash, _after_membership_paid)


func _after_membership_paid(res: Dictionary) -> void:
	if not res.get("ok", false):
		_finish("Payment failed: " + str(res.get("error", "?")))
		return
	_status.text = "Verifying payment + activating membership..."
	var r: Dictionary = await data_service.purchase_membership(str(res.get("txid", "")))
	if r.get("success", false):
		if state != null and r.get("result") is Dictionary:
			state.progress.seed_from_account(r["result"])
		_finish("Membership active!")
	else:
		_finish("Paid, but activation failed: " + str(r.get("result", "?")))


# --- Cash out ----------------------------------------------------------------

func _on_cashout() -> void:
	if _pending:
		return
	if state != null and state.progress.linked_wallet == "":
		_finish("Link a wallet first.")
		return
	_pending = true
	_status.text = "Queuing payout request..."
	var points := int(_amount.value)
	var r: Dictionary = await data_service.request_withdrawal(points)
	if r.get("success", false):
		_finish("Requested %d REALM. Payouts are reviewed + sent manually." % points)
	else:
		_finish("Request failed: " + str(r.get("result", "?")))


func _finish(msg: String) -> void:
	_status.text = msg
	_pending = false
	_drawn = -1
