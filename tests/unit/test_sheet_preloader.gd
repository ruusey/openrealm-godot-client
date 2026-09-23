extends GutTest

## Every sheet asked for at once, and waited for together.

## A source that answers nothing until told to, so the order of asking and
## the order of answering can both be seen.
class LatchedSource extends ContentSource:
	signal answered(key: String)
	var asked: Array = []
	var bodies := {}

	func read(name: String) -> Array:
		asked.append(name)
		while true:
			var key: String = await answered
			if key == name:
				break
		return [OK, bodies[name]] if bodies.has(name) else [ERR_FILE_NOT_FOUND, PackedByteArray()]

	func answer(key: String) -> void:
		answered.emit(key)


var png: PackedByteArray
var cache: SpriteCache


func before_each():
	cache = SpriteCache.new()
	png = FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://tests/fixtures/datadir/entity/atlas.png"))
	assert_gt(png.size(), 0)


func test_every_sheet_is_asked_for_before_any_is_answered():
	var source := LatchedSource.new()
	source.bodies = {"a.png": png, "b.png": png, "c.png": png}
	var done: Array = []
	Callable(self, "_preload_into").call(cache, source, ["a.png", "b.png", "c.png"], done)
	assert_eq(source.asked, ["a.png", "b.png", "c.png"], "all three in flight at once")
	assert_eq(cache.sheet_count(), 0, "none landed yet")
	assert_true(cache.holds("b.png"), "but each is spoken for")
	assert_true(done.is_empty(), "and the preload is still waiting")

	# Answered out of order: each lands under its own key.
	source.answer("c.png")
	assert_eq(cache.sheet_count(), 1)
	assert_not_null(cache.texture("c.png"))
	assert_true(done.is_empty())
	source.answer("a.png")
	source.answer("b.png")
	await wait_process_frames(1)
	assert_eq(cache.sheet_count(), 3)
	assert_false(done.is_empty(), "the preload returned once the last landed")
	assert_eq(cache.errors, [])


func test_a_missing_sheet_lands_as_nothing_and_is_named():
	var source := LatchedSource.new()
	source.bodies = {"a.png": png}
	var done: Array = []
	Callable(self, "_preload_into").call(cache, source, ["a.png", "gone.png"], done)
	source.answer("gone.png")
	source.answer("a.png")
	await wait_process_frames(1)
	assert_false(done.is_empty())
	assert_null(cache.texture("gone.png"))
	assert_eq(cache.errors, ["sprite sheet not found: gone.png"])


func test_a_sheet_in_flight_is_not_asked_for_twice():
	var source := LatchedSource.new()
	source.bodies = {"a.png": png}
	var done: Array = []
	Callable(self, "_preload_into").call(cache, source, ["a.png", "a.png", ""], done)
	Callable(self, "_preload_into").call(cache, source, ["a.png"], done)
	assert_eq(source.asked, ["a.png"], "once, across both preloads and the empty key")
	source.answer("a.png")
	await wait_process_frames(1)
	assert_eq(done.size(), 2, "both preloads returned")


func test_off_disk_the_whole_preload_finishes_inside_the_call():
	# Nothing suspends against a file source, so a caller that does not
	# await sees every sheet in place already -- the desktop's path.
	var source := FileContentSource.new(ProjectSettings.globalize_path("res://tests/fixtures/datadir"))
	var done: Array = []
	Callable(self, "_preload_into").call(cache, source, ["atlas.png", "portal-sheet.png"], done)
	assert_eq(cache.sheet_count(), 2)
	assert_false(done.is_empty())


func _preload_into(target: SpriteCache, source: ContentSource, keys: Array, done: Array) -> void:
	await target.preload_sheets(source, keys)
	done.append(true)
