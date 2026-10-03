class_name PhantomWallet
extends RefCounted

## Phantom (Solana) wallet bridge for the WEB build. Phantom is a browser
## extension that injects `window.phantom.solana`, so this only works under a
## web export; every call is a no-op (returns {"ok": false}) off the web.
##
## Phantom's API is Promise-based, so each call hands its result back through a
## JavaScriptBridge callback installed on `window`. The callback objects are
## held on this instance -- let it be freed and the browser loses the callback,
## so whoever starts a flow must keep the PhantomWallet alive until it answers.
##
## Flow for "sign in with wallet": connect() to get the address, then
## sign_message(nonce) where the nonce comes from the server; the server then
## verifies the ed25519 signature against the address to prove ownership. The
## nonce + server-side verification are what make it safe -- never trust a
## client-reported "connected" address on its own.

var _window: JavaScriptObject
var _connect_cb: JavaScriptObject
var _sign_cb: JavaScriptObject
var _on_connect := Callable()
var _on_sign := Callable()


func _init() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	_connect_cb = JavaScriptBridge.create_callback(_connect_result)
	_sign_cb = JavaScriptBridge.create_callback(_sign_result)
	if _window != null:
		_window.godotPhantomConnected = _connect_cb
		_window.godotPhantomSigned = _sign_cb


## True only when running on web AND the Phantom extension is present.
static func is_available() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
		"!!(window.phantom && window.phantom.solana && window.phantom.solana.isPhantom) "
		+ "|| !!(window.solana && window.solana.isPhantom)", true))


## Prompts Phantom to connect. `on_done` receives {"ok": bool, "address": String}
## or {"ok": false, "error": String}.
func connect_wallet(on_done: Callable) -> void:
	_on_connect = on_done
	if not OS.has_feature("web") or _window == null:
		_answer(on_done, {"ok": false, "error": "not a web build"})
		return
	JavaScriptBridge.eval("""
		(async () => {
		  try {
			const p = (window.phantom && window.phantom.solana) || window.solana;
			if (!p) throw new Error('Phantom not found');
			const res = await p.connect();
			window.godotPhantomConnected(JSON.stringify({ok: true, address: res.publicKey.toString()}));
		  } catch (e) {
			window.godotPhantomConnected(JSON.stringify({ok: false, error: String((e && e.message) || e)}));
		  }
		})();
	""", true)


## Asks Phantom to sign `message` (a server nonce in real use). `on_done` gets
## {"ok": true, "address": String, "signature_b64": String, "message": String}
## or {"ok": false, "error": String}.
func sign_message(message: String, on_done: Callable) -> void:
	_on_sign = on_done
	if not OS.has_feature("web") or _window == null:
		_answer(on_done, {"ok": false, "error": "not a web build"})
		return
	# Hand the message over a window var so it never has to be escaped into the
	# eval'd source.
	_window.godotPhantomMessage = message
	JavaScriptBridge.eval("""
		(async () => {
		  try {
			const p = (window.phantom && window.phantom.solana) || window.solana;
			if (!p) throw new Error('Phantom not found');
			const bytes = new TextEncoder().encode(window.godotPhantomMessage || '');
			const res = await p.signMessage(bytes, 'utf8');
			const b64 = btoa(String.fromCharCode.apply(null, res.signature));
			window.godotPhantomSigned(JSON.stringify({
			  ok: true,
			  address: res.publicKey ? res.publicKey.toString() : '',
			  signature_b64: b64,
			  message: window.godotPhantomMessage
			}));
		  } catch (e) {
			window.godotPhantomSigned(JSON.stringify({ok: false, error: String((e && e.message) || e)}));
		  }
		})();
	""", true)


func _connect_result(args: Array) -> void:
	_answer(_on_connect, _parse(args))


func _sign_result(args: Array) -> void:
	_answer(_on_sign, _parse(args))


func _parse(args: Array) -> Dictionary:
	if args.is_empty():
		return {"ok": false, "error": "empty result"}
	var parsed: Variant = JSON.parse_string(String(args[0]))
	return parsed if parsed is Dictionary else {"ok": false, "error": "bad result"}


func _answer(cb: Callable, result: Dictionary) -> void:
	if cb.is_valid():
		cb.call(result)
