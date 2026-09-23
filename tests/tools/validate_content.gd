extends SceneTree

## Loads the real game content and reports anything it refers to but cannot
## resolve. Exits non-zero on the first problem, so CI can gate on it.
##
## The unit suite runs against a fixture directory, by design -- it has to be
## deterministic and to contain a deliberately broken sheet. That leaves the
## actual shipped content unchecked, which is how a sprite sheet referenced by
## the enemy table but never shipped stayed invisible: nothing drew that enemy,
## so nothing asked for the sheet.
##
##   godot --headless --script tests/tools/validate_content.gd            # disk
##   godot --headless --script tests/tools/validate_content.gd -- --http=URL

const TABLES := ["tiles", "enemies", "classes", "items", "projectile_groups",
	"portals", "animations", "abilities"]


func _init() -> void:
	var url := ""
	var root := ClientConfig.new().resolved_data_root()
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		var value: String = pair[1] if pair.size() > 1 else ""
		match pair[0]:
			"http": url = value
			"data-root": root = value

	# HTTPRequest needs a node that is actually in the tree, and at
	# SceneTree._init the tree has not started yet.
	await process_frame
	var source: ContentSource = HttpContentSource.new(url, _backend()) if url != "" \
		else FileContentSource.new(root)
	var data := GameData.new()
	var loaded: bool = await data.load_from(source)
	print("[content] %s\n          from %s" % [data.summary(), source.describe()])

	if not loaded:
		_fail(data.errors)
		return
	var missing := _unresolvable(data)
	var named := data.library.sheet_keys()
	var stale := ContentGaps.stale(named, func(key: String) -> bool: return data.sprites.texture(key) != null)
	for key in ContentGaps.sheets:
		if named.has(key):
			print("[known] %s -- %s" % [key, ContentGaps.reason(key)])
	for line in stale:
		print("[stale] %s" % line)
	missing.append_array(Array(stale))
	if not missing.is_empty():
		_fail(missing)
		return
	print("[ok] every sheet the content names resolves, or is a known gap")
	quit(0)


## Content errors say *what* is missing; this says what refers to it, which is
## the part that decides whether it matters.
func _unresolvable(data: GameData) -> Array:
	var problems: Array = []
	for key in data.library.sheet_keys():
		if data.sprites.texture(key) != null or ContentGaps.is_known(key):
			continue
		problems.append("%s <- %s" % [key, ", ".join(_referrers(data, key))])
	return problems


func _referrers(data: GameData, key: String) -> Array:
	var who: Array = []
	for name in TABLES:
		var table: Dictionary = data.library.get(name)
		for id in table:
			if String(table[id].get("spriteKey", "")) == key:
				who.append("%s %s (%s)" % [name, id,
					table[id].get("name", table[id].get("className",
						table[id].get("portalName", "?")))])
	return who


func _fail(problems: Array) -> void:
	for problem in problems:
		printerr("  %s" % problem)
	printerr("[fail] %d content problem(s)" % problems.size())
	quit(1)


## One HTTPRequest per call, which is all a one-shot check needs.
func _backend() -> HttpBackend:
	var host := Node.new()
	root.add_child(host)
	return LiveBackend.new(host)


class LiveBackend extends HttpBackend:
	var _host: Node

	func _init(host: Node) -> void:
		_host = host

	func perform(method: int, url: String, headers: PackedStringArray, body: String) -> Array:
		var request := HTTPRequest.new()
		_host.add_child(request)
		var err := request.request(url, headers, method, body)
		if err != OK:
			request.queue_free()
			return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
		var result: Array = await request.request_completed
		request.queue_free()
		return [result[0], result[1], result[3]]
