class_name PhantomPocOverlay
extends CanvasLayer

## A throwaway demo panel for the Phantom wallet POC. Main attaches it only on
## web with ?phantom=1 in the URL. Two buttons: Connect (get the address) and
## Sign (sign a login nonce) -- the output is shown in the panel and printed to
## the browser console. This is the client half of a "sign in with wallet"
## flow; the nonce would come from the server and the signature go back to it
## for ed25519 verification.

var _wallet := PhantomWallet.new()
var _out: Label
var _address := ""


func _ready() -> void:
	layer = 60
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Phantom Wallet POC"
	box.add_child(title)

	var connect_btn := Button.new()
	connect_btn.text = "Connect Phantom"
	connect_btn.pressed.connect(_on_connect)
	box.add_child(connect_btn)

	var sign_btn := Button.new()
	sign_btn.text = "Sign Login Nonce"
	sign_btn.pressed.connect(_on_sign)
	box.add_child(sign_btn)

	_out = Label.new()
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.custom_minimum_size = Vector2(360, 96)
	box.add_child(_out)

	if PhantomWallet.is_available():
		_show("Phantom detected. Click Connect.")
	else:
		_show("Phantom NOT detected. Install the extension and reload (web build only).")


func _on_connect() -> void:
	_show("Connecting...")
	_wallet.connect_wallet(_connect_done)


func _connect_done(res: Dictionary) -> void:
	if res.get("ok", false):
		_address = String(res.get("address", ""))
		_show("Connected:\n" + _address)
	else:
		_show("Connect failed: " + String(res.get("error", "?")))


func _on_sign() -> void:
	# In production this nonce comes from the server so the signature can't be replayed.
	var nonce := "openrealm-login:%d" % int(Time.get_unix_time_from_system())
	_show("Signing nonce:\n" + nonce)
	_wallet.sign_message(nonce, _sign_done)


func _sign_done(res: Dictionary) -> void:
	if res.get("ok", false):
		_show("Signed OK\naddr: %s\nsig(b64): %s" % [
			String(res.get("address", "")), String(res.get("signature_b64", ""))])
	else:
		_show("Sign failed: " + String(res.get("error", "?")))


func _show(msg: String) -> void:
	print("[PhantomPOC] ", msg)
	if _out != null:
		_out.text = msg
