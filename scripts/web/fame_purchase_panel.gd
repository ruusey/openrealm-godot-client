class_name FamePurchasePanel
extends CanvasLayer

## "Add Fame" — buy in-game fame with SOL via Phantom (web build only).
##
## Flow: pick an amount, see the SOL quote, pay with Phantom (a SystemProgram
## transfer to the recipient, using a blockhash the data service proxies so the
## browser never calls a public RPC), then hand the txid to the data service,
## which verifies the transfer on-chain and credits the fame. The client never
## credits anything itself; the txid is just a receipt the server checks.

const RECIPIENT := "J9ZGigjmaKYcriwvjZGYqeaB9arofYMHtRorZfu3FQJj"
const LAMPORTS_PER_FAME := 100000  # 0.0001 SOL per fame (1 SOL = 1e9 lamports)
const SOL_PER_FAME := 0.0001

## Set by Main after construction; used to fetch the blockhash + submit the txid.
var data_service

var _wallet := PhantomWallet.new()
var _modal: Control
var _amount: SpinBox
var _quote: Label
var _status: Label
var _buy_btn: Button
var _pending := false


func _ready() -> void:
	layer = 55
	var open_btn := Button.new()
	open_btn.text = "Add Fame"
	open_btn.position = Vector2(12, 12)
	open_btn.pressed.connect(_open)
	add_child(open_btn)
	_build_modal()


func _build_modal() -> void:
	# A full-screen dim backdrop with the dialog centred on top, so the panel is
	# never buried under the HUD / inventory.
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
	dialog.custom_minimum_size = Vector2(360, 0)
	center.add_child(dialog)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)

	var title := Label.new()
	title.text = "Buy Fame with SOL"
	box.add_child(title)

	var row := HBoxContainer.new()
	box.add_child(row)
	var lbl := Label.new()
	lbl.text = "Fame:"
	row.add_child(lbl)
	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.max_value = 10000000
	_amount.step = 1
	_amount.value = 100
	_amount.value_changed.connect(_on_amount_changed)
	row.add_child(_amount)

	_quote = Label.new()
	box.add_child(_quote)

	_buy_btn = Button.new()
	_buy_btn.text = "Pay with Phantom"
	_buy_btn.pressed.connect(_on_buy)
	box.add_child(_buy_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(340, 48)
	box.add_child(_status)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	box.add_child(close)

	_update_quote()


func _open() -> void:
	_modal.visible = true
	if not PhantomWallet.is_available():
		_status.text = "Phantom not detected. Install the extension and reload."
	else:
		_status.text = ""
	_update_quote()


func _close() -> void:
	_modal.visible = false


func _on_amount_changed(_value: float) -> void:
	_update_quote()


func _update_quote() -> void:
	var fame := int(_amount.value)
	_quote.text = "%d fame  =  %s SOL" % [fame, String.num(fame * SOL_PER_FAME, 4)]


func _on_buy() -> void:
	if _pending:
		return
	var fame := int(_amount.value)
	if fame < 1:
		return
	if data_service == null:
		_finish("No data service available.")
		return
	_pending = true
	_buy_btn.disabled = true
	_status.text = "Preparing transaction..."
	var blockhash: String = await data_service.solana_blockhash()
	if blockhash == "":
		_finish("Could not get a blockhash (are you signed in?).")
		return
	_status.text = "Approve the transaction in Phantom..."
	_wallet.buy_fame(fame * LAMPORTS_PER_FAME, RECIPIENT, blockhash, _on_paid.bind(fame))


func _on_paid(res: Dictionary, fame: int) -> void:
	if not res.get("ok", false):
		_finish("Payment failed: " + String(res.get("error", "?")))
		return
	var txid := String(res.get("txid", ""))
	_status.text = "Paid (tx %s...). Verifying + crediting fame..." % txid.substr(0, 8)
	_verify(txid, fame)


func _verify(txid: String, fame: int) -> void:
	var result: Dictionary = await data_service.purchase_fame(txid, fame)
	if result.get("success", false):
		_finish("Success! +%d fame credited." % fame)
	else:
		_finish("Payment sent but crediting failed: %s\nKeep this TX: %s" % [
			String(result.get("result", "?")), txid])


func _finish(msg: String) -> void:
	_status.text = msg
	_pending = false
	_buy_btn.disabled = false
