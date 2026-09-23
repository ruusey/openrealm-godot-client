extends SceneTree

## Golden-image comparison for the captured scenarios.
##
## Screenshots on their own only prove something rendered. Comparing them to
## accepted references is what turns them into a regression test: a change
## that moves sprites, breaks depth ordering or loses a tile shows up as a
## pixel delta instead of going unnoticed.
##
##   godot --headless --path . --script tests/visual/compare.gd -- <ref_dir> <candidate_dir> [tolerance]
##
## Runs fine headless: this only loads and compares PNGs, it renders nothing.

## Per-channel difference below this is treated as identical, absorbing the
## odd rounding difference between drivers.
const CHANNEL_EPSILON := 0.02
## Fraction of differing pixels tolerated before a scenario fails. Rendering
## is deterministic on a given driver, so unchanged code compares exactly;
## this only absorbs a handful of stray pixels. It has to stay tight -- at
## 0.2% a whole sprite can reorder inside the budget and still "pass".
const DEFAULT_TOLERANCE := 0.0001


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var reference_dir: String = args[0] if args.size() > 0 else "tests/visual/reference"
	var candidate_dir: String = args[1] if args.size() > 1 else "reports/visual"
	var tolerance: float = float(args[2]) if args.size() > 2 else DEFAULT_TOLERANCE

	var names := _reference_names(reference_dir)
	if names.is_empty():
		print("no reference images in %s -- run ./capture-visuals.sh --update first" % reference_dir)
		quit(1)
		return

	# A capture with no accepted reference compares against nothing, and
	# silence reads exactly like a pass -- a new scenario landed that way and
	# went unchecked for a whole run. Name it as a failure instead.
	var orphans := _unreferenced(names, candidate_dir)
	var failures := orphans.size()
	for name in orphans:
		print("  %-5s %-16s %s" % ["FAIL", name, "captured but never accepted; run --update"])
	for name in names:
		var result := _compare(reference_dir.path_join(name), candidate_dir.path_join(name))
		var passed: bool = result["ok"] and result["ratio"] <= tolerance
		if not passed:
			failures += 1
		print("  %-5s %-16s %s" % ["ok" if passed else "FAIL", name, result["detail"]])

	var checked: int = names.size() + orphans.size()
	print("\n%d of %d scenarios matched" % [checked - failures, checked])
	quit(1 if failures > 0 else 0)


func _reference_names(directory: String) -> Array:
	var names: Array = []
	var handle := DirAccess.open(directory)
	if handle == null:
		return names
	for file in handle.get_files():
		if file.ends_with(".png"):
			names.append(file)
	names.sort()
	return names


## Captured PNGs with no reference of the same name. Diff images are the
## script's own output, not captures, so they are not candidates.
func _unreferenced(names: Array, candidate_dir: String) -> Array:
	var extra: Array = []
	var handle := DirAccess.open(candidate_dir)
	if handle == null:
		return extra
	for file in handle.get_files():
		if file.ends_with(".png") and not file.ends_with(".diff.png") and not names.has(file):
			extra.append(file)
	extra.sort()
	return extra


func _compare(reference_path: String, candidate_path: String) -> Dictionary:
	var reference := Image.load_from_file(reference_path)
	var candidate := Image.load_from_file(candidate_path)
	if reference == null:
		return {"ok": false, "ratio": 1.0, "detail": "reference unreadable"}
	if candidate == null:
		return {"ok": false, "ratio": 1.0, "detail": "no capture at %s" % candidate_path}
	if reference.get_size() != candidate.get_size():
		return {"ok": false, "ratio": 1.0, "detail": "size %s != %s"
			% [candidate.get_size(), reference.get_size()]}

	var differing := 0
	var total := reference.get_width() * reference.get_height()
	var diff := Image.create(reference.get_width(), reference.get_height(), false, Image.FORMAT_RGBA8)
	for x in reference.get_width():
		for y in reference.get_height():
			var a := reference.get_pixel(x, y)
			var b := candidate.get_pixel(x, y)
			if absf(a.r - b.r) > CHANNEL_EPSILON or absf(a.g - b.g) > CHANNEL_EPSILON \
					or absf(a.b - b.b) > CHANNEL_EPSILON or absf(a.a - b.a) > CHANNEL_EPSILON:
				differing += 1
				diff.set_pixel(x, y, Color.MAGENTA)
			else:
				diff.set_pixel(x, y, Color(b.r, b.g, b.b, 0.25))

	var ratio := float(differing) / float(maxi(total, 1))
	if differing > 0:
		var diff_path := candidate_path.get_basename() + ".diff.png"
		diff.save_png(diff_path)
		return {"ok": true, "ratio": ratio,
			"detail": "%.3f%% differ, diff at %s" % [ratio * 100.0, diff_path]}
	return {"ok": true, "ratio": 0.0, "detail": "identical"}
