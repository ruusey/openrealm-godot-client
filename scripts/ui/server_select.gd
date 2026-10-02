class_name ServerSelect
extends VBoxContainer

## Server picker for the login screen. Fetches the registered game servers from
## the data service (GET /servers), lists them in a dropdown with a measured
## latency next to each, and applies the chosen one to the ClientConfig so the
## next connect dials it. Hidden (a no-op) when /servers is empty or unreachable,
## so the client falls back to its compiled-in default route.
##
## Latency is the WebSocket handshake round-trip to each server's own connect
## URL (wss via the nginx route on web, raw ws on native) — the real path the
## game traffic will take, not an ICMP ping the browser could not do anyway.

const PING_TIMEOUT_MS := 4000

var data_service: DataService
## Called with the chosen server Dictionary when the selection changes (and once
## for the default on load). The screen uses it to mutate its ClientConfig.
var apply_server: Callable

var _dropdown: OptionButton
var _servers: Array = []
# Parallel to _servers: {state: "pending"|"done"|"fail", socket, start_ms, ms}.
var _pings: Array = []


func _init(service: DataService, on_apply: Callable) -> void:
	data_service = service
	apply_server = on_apply


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	add_child(HudWidgets.label("Server", 12, PlayerHud.GOLD))
	_dropdown = OptionButton.new()
	_dropdown.item_selected.connect(_on_selected)
	add_child(_dropdown)
	visible = false
	set_process(false)
	_load()


func _load() -> void:
	var response: Dictionary = await data_service.send(HTTPClient.METHOD_GET, "/servers", "", false)
	if not response.get("ok", false):
		return
	var body: Variant = response.get("body")
	if not (body is Array) or (body as Array).is_empty():
		return
	_servers = body
	_dropdown.clear()
	_pings.clear()
	for server in _servers:
		_dropdown.add_item(_label(server, "..."))
		_pings.append({"state": "pending", "socket": null, "start_ms": 0, "ms": 0})
	visible = true
	_dropdown.select(0)
	_on_selected(0)
	_start_pings()


func _on_selected(index: int) -> void:
	if index >= 0 and index < _servers.size() and apply_server.is_valid():
		apply_server.call(_servers[index])


func _start_pings() -> void:
	for i in _servers.size():
		var url := _connect_url(_servers[i])
		var socket := WebSocketPeer.new()
		if socket.connect_to_url(url) != OK:
			_pings[i]["state"] = "fail"
			_dropdown.set_item_text(i, _label(_servers[i], "offline"))
			continue
		_pings[i]["socket"] = socket
		_pings[i]["start_ms"] = Time.get_ticks_msec()
	set_process(true)


func _process(_delta: float) -> void:
	var pending := 0
	for i in _pings.size():
		var ping: Dictionary = _pings[i]
		if ping["state"] != "pending":
			continue
		pending += 1
		var socket: WebSocketPeer = ping["socket"]
		socket.poll()
		var now := Time.get_ticks_msec()
		var state := socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			ping["ms"] = now - ping["start_ms"]
			ping["state"] = "done"
			socket.close()
			_dropdown.set_item_text(i, _label(_servers[i], "%d ms" % ping["ms"]))
		elif state == WebSocketPeer.STATE_CLOSED or now - ping["start_ms"] > PING_TIMEOUT_MS:
			ping["state"] = "fail"
			socket.close()
			_dropdown.set_item_text(i, _label(_servers[i], "offline"))
	if pending == 0:
		set_process(false)


## wss via the page's nginx route on TLS web; raw ws to the node otherwise.
func _connect_url(server: Dictionary) -> String:
	if data_service.base_url.begins_with("https"):
		var authority := data_service.base_url.substr(data_service.base_url.find("://") + 3)
		return "wss://%s%s" % [authority, str(server.get("route", ""))]
	return "ws://%s:%d" % [str(server.get("host", "")), int(server.get("webSocketPort", 2223))]


func _label(server: Dictionary, latency: String) -> String:
	var display := str(server.get("name", "server"))
	return "%s  -  %s" % [display, latency] if latency != "" else display
