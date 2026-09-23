class_name HttpContentSource
extends ContentSource

## Content fetched from the data service, which is what a web build has to do
## -- there is no filesystem in a browser.
##
## /game-data/<file> serves the JSON and the sprite sheets from one flat
## namespace, resolving each name against the live sprites directory and then
## the bundled entity/, ui/ and static/ copies. That is the same order
## FileContentSource walks, so a name means the same thing through either.
##
## No Authorization header, because the endpoint is public -- which is what
## lets content load before anyone has logged in.

const PATH := "/game-data/"

var base_url := ""
var backend: HttpBackend = null


func _init(url := "", http: HttpBackend = null) -> void:
	base_url = url
	backend = http


func read(name: String) -> Array:
	if backend == null:
		return [ERR_UNAVAILABLE, PackedByteArray()]
	var result: Array = await backend.perform(
		HTTPClient.METHOD_GET, url_for(name), PackedStringArray(), "")
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return [ERR_CANT_CONNECT, PackedByteArray()]
	if int(result[1]) != 200:
		return [ERR_FILE_NOT_FOUND, PackedByteArray()]
	return [OK, result[2]]


## The endpoint is one level deep, so a sheet key carrying its own directory
## has to be reduced to its filename or the request 404s.
func url_for(name: String) -> String:
	return base_url + PATH + name.get_file()


func describe() -> String:
	return base_url + PATH
