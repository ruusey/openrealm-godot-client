class_name HttpBackend
extends RefCounted

## Request seam for DataService, so account/character flows can be tested
## against scripted responses (including transport failures and error bodies)
## without a running data service.
##
## Returns [result, status, body_bytes] mirroring HTTPRequest.request_completed.

func perform(_method: int, _url: String, _headers: PackedStringArray, _body: String) -> Array:
	return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
