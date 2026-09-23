class_name FrameSampler
extends RefCounted

## What the frames cost over a stretch of seconds: wall time per frame,
## draw calls, and what the world renderer drew -- one dictionary a live
## test can judge and one line it can print.
##
## Wall time is measured here, frame to frame, rather than read off the
## engine: its delta is smoothed, and Performance.TIME_PROCESS reads well
## above the frame itself (44.9 ms at 89 fps), so neither is the number.


## Samples until `seconds` have passed.
static func sample(tree: SceneTree, seconds: float, renderer: WorldRenderer) -> Dictionary:
	var frame_ms: Array[float] = []
	var draw_calls := 0
	var drawn := {}
	var started := Time.get_ticks_usec()
	var last := started
	while (Time.get_ticks_usec() - started) < int(seconds * 1_000_000.0):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		draw_calls = maxi(draw_calls, FrameCounts.draw_calls())
		drawn = renderer.draw_stats if renderer != null else {}
	return summarise(frame_ms, draw_calls, drawn)


## {frames, total_ms, fps, mean_ms, p95_ms, max_ms, draw_calls, drawn}, or
## {} for no frames. p95 is the frame 95% of the way up the sorted list.
static func summarise(frame_ms: Array[float], draw_calls: int, drawn: Dictionary) -> Dictionary:
	if frame_ms.is_empty():
		return {}
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for ms in frame_ms:
		total += ms
	return {
		"frames": frame_ms.size(),
		"total_ms": total,
		"fps": frame_ms.size() / (total / 1000.0),
		"mean_ms": total / frame_ms.size(),
		"p95_ms": sorted[mini(int(floor(sorted.size() * 0.95)), sorted.size() - 1)],
		"max_ms": sorted[-1],
		"draw_calls": draw_calls,
		"drawn": drawn,
	}


static func describe(label: String, s: Dictionary) -> String:
	if s.is_empty():
		return "[perf] %s: no frames" % label
	var drawn: Dictionary = s["drawn"]
	return "[perf] %-14s %4d frames in %.2fs = %6.1f fps   frame mean %.2f ms  p95 %.2f  max %.2f   draw calls %d   drew %d enemies, %d bullets, %d players, %d tiles" % [
		label, s["frames"], s["total_ms"] / 1000.0, s["fps"], s["mean_ms"], s["p95_ms"], s["max_ms"],
		s["draw_calls"], int(drawn.get("enemies", 0)), int(drawn.get("bullets", 0)),
		int(drawn.get("players", 0)), int(drawn.get("tiles", 0))]
