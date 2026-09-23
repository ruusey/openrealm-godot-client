class_name GodotHttpBackend
extends HttpBackend

## Production backend: a pool of HTTPRequest nodes, so several requests can
## be in flight at once.
##
## One node serves one request at a time. A request takes an idle node or
## adds one, up to MAX_IN_FLIGHT; past that it waits for a node to free.
## The sheet preload is what needs this -- 51 fetches started together --
## and a browser holds a handful of connections per host anyway.

const MAX_IN_FLIGHT := 8

signal freed

var _host: Node
var _idle: Array[HTTPRequest] = []
var _in_flight := 0


func _init(host: Node) -> void:
	_host = host


func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
	while _in_flight >= MAX_IN_FLIGHT:
		await freed
	var request: HTTPRequest = _idle.pop_back() if not _idle.is_empty() else _spawn()
	_in_flight += 1
	var result: Array
	if request.request(url, headers, method, body) != OK:
		result = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	else:
		var done: Array = await request.request_completed
		result = [done[0], done[1], done[3]]
	_idle.append(request)
	_in_flight -= 1
	freed.emit()
	return result


func _spawn() -> HTTPRequest:
	var request := HTTPRequest.new()
	_host.add_child(request)
	return request


## How many nodes the pool has grown to: the most that were ever in flight.
func pool_size() -> int:
	return _idle.size() + _in_flight
