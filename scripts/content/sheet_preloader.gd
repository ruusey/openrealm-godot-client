class_name SheetPreloader
extends RefCounted

## Reads every sheet the content names, all at once, and waits for the last.
##
## Over HTTP a sheet is a request, and 51 of them one after another took six
## seconds on loopback: each waited for the previous one's round trip. Every
## fetch is started before any is waited on, so the browser's cost is the
## slowest sheet rather than the sum; the backend bounds how many are in
## flight. Off disk nothing suspends and the whole thing finishes inside
## the call, exactly as before.

signal landed

var _cache: SpriteCache
var _in_flight := 0


func _init(cache: SpriteCache) -> void:
	_cache = cache


func run(source: ContentSource, keys: Array) -> void:
	for key in keys:
		if key == "" or _cache.holds(key):
			continue
		_cache.expect(key)
		_in_flight += 1
		# Started, not awaited: the fetch runs to its first suspension and
		# this loop goes on to start the next. A Callable, because the
		# analyzer refuses a bare un-awaited coroutine call.
		Callable(self, "_fetch").call(source, key)
	while _in_flight > 0:
		await landed


func _fetch(source: ContentSource, key: String) -> void:
	var texture := await read_sheet(source, key)
	_cache.store(key, texture)
	# A gap already recorded in ContentGaps is not news every launch; the
	# sprite still resolves to nothing and draws as a fallback block.
	if texture == null and not ContentGaps.is_known(key):
		_cache.errors.append("sprite sheet not found: %s" % key)
	_in_flight -= 1
	landed.emit()


static func read_sheet(source: ContentSource, key: String) -> Texture2D:
	var result: Array = await source.read(key)
	if result[0] != OK:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(result[1]) != OK:
		return null
	return ImageTexture.create_from_image(image)
