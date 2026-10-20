class_name FakeHttpBackend
extends HttpBackend

## Queue of scripted HTTP completions, plus a log of the requests made.

var responses: Array = []   # [[result, status, body_string], ...]
var requests: Array = []    # [{method, url, headers, body}]
## The login screen's server picker asks for /servers on its own schedule;
## it gets an empty registry here, outside the queue and the log, so the
## scripted answers stay in step with the requests a test is about.
var servers_requests := 0


func push_json(status: int, body: Variant) -> void:
	responses.append([HTTPRequest.RESULT_SUCCESS, status, JSON.stringify(body)])


func push_raw(result: int, status: int, body: String) -> void:
	responses.append([result, status, body])


## For a body that is not text -- a sprite sheet, say. Kept distinct from
## push_raw because round-tripping PNG bytes through a String corrupts them.
func push_bytes(status: int, body: PackedByteArray) -> void:
	responses.append([HTTPRequest.RESULT_SUCCESS, status, body])


func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
	if url.ends_with("/servers"):
		servers_requests += 1
		return [HTTPRequest.RESULT_SUCCESS, 200, "[]".to_utf8_buffer()]
	requests.append({"method": method, "url": url, "headers": headers, "body": body})
	if responses.is_empty():
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	var next: Array = responses.pop_front()
	if next[2] is PackedByteArray:
		return [next[0], next[1], next[2]]
	return [next[0], next[1], String(next[2]).to_utf8_buffer()]
