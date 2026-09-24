class_name MotionTrace
extends RefCounted

## How evenly the local player moves across rendered frames.
##
## A stutter that a screenshot cannot show -- the sprite at one place on
## this frame and another on the next, fused by the eye into a ghost -- is
## a per-frame measurement: how far the drawn position moved each frame,
## and how many 64Hz ticks ran in it. Started from the screenshot key, it
## samples the next FRAMES frames and prints one summary line. Even motion
## reads as a displacement that barely varies; the ghost reads as a
## displacement alternating between nothing and a whole step.

const FRAMES := 120

var _frames: Array = []   # [frame_ms, ticks, displacement_px]
var _last_position := Vector2.INF
var _last_seq := -1
var _corrections_at_start := 0
var _wanted := 0
## The numbers behind the last summary line, for a test to judge.
var last := {}
## How far the local sprite sat from the camera's centre at draw time, at
## worst, in screen pixels. The camera follows the player exactly, so any
## distance here is the frame drawn with a transform the player has since
## moved away from -- a sub-pixel gap that changes every frame and reads as
## a wobble against the ground.
var off_centre := 0.0


func start(corrections: int, frames := FRAMES) -> void:
	_frames.clear()
	_last_position = Vector2.INF
	_last_seq = -1
	_corrections_at_start = corrections
	_wanted = frames
	off_centre = 0.0


func active() -> bool:
	return _wanted > 0


## One rendered frame. Returns the summary line on the frame that completes
## the trace, and "" otherwise.
func sample(delta: float, position: Vector2, seq: int, corrections: int) -> String:
	if not active():
		return ""
	if _last_position != Vector2.INF:
		_frames.append([delta * 1000.0, seq - _last_seq, position.distance_to(_last_position)])
	_last_position = position
	_last_seq = seq
	if _frames.size() < _wanted:
		return ""
	_wanted = 0
	last = measure(_frames, corrections - _corrections_at_start)
	last["off_centre"] = off_centre
	return summary(last)


## Where the local sprite is about to be drawn, against where the camera
## says it should be: the viewport's centre. The worse axis, since the
## camera sits on the pixel grid (PixelSnap.camera) and is up to half a
## pixel off the player on each.
func sample_draw(to_screen: Transform2D, world_centre: Vector2, viewport_size: Vector2) -> void:
	if active():
		var off := (to_screen * world_centre - viewport_size * 0.5).abs()
		off_centre = maxf(off_centre, maxf(off.x, off.y))


## The frame as the realm state has it, printed when the trace completes.
func observe(delta: float, state: RealmState) -> void:
	var line := sample(delta, state.local.render_position(), state.movement.input_seq,
		state.movement.corrections)
	if line != "":
		print(line)


## A frame that moved less than this much of the mean is a stall.
const STALL_FRACTION := 0.25


## What the frames add up to: {frames, total_ms, ticks: {n: count}, mean,
## sd, min, max, stalls, corrections}, or {} for none. A stall is a frame
## that barely moved; one is the frame a one-step correction lands on, many
## in a row is the sprite standing still while it should walk.
static func measure(frames: Array, corrections: int) -> Dictionary:
	if frames.is_empty():
		return {}
	var total_ms := 0.0
	var ticks := {}
	var moved: Array[float] = []
	for frame in frames:
		total_ms += frame[0]
		ticks[frame[1]] = ticks.get(frame[1], 0) + 1
		moved.append(frame[2])
	var mean := _mean(moved)
	var stalls := 0
	for m in moved:
		if m < mean * STALL_FRACTION:
			stalls += 1
	return {"frames": frames.size(), "total_ms": total_ms, "ticks": ticks, "mean": mean,
		"sd": _stddev(moved, mean), "min": moved.min(), "max": moved.max(), "stalls": stalls,
		"corrections": corrections}


static func summary(measured: Dictionary) -> String:
	if measured.is_empty():
		return "[trace] no frames"
	var keys: Array = measured["ticks"].keys()
	keys.sort()
	var by_ticks := PackedStringArray()
	for k in keys:
		by_ticks.append("%d:%d" % [k, measured["ticks"][k]])
	return "[trace] %d frames in %.0f ms (%.1f ms each)   ticks/frame %s   moved/frame %.2f px (sd %.2f, min %.2f, max %.2f)   stalls %d   corrections %d   off-centre %.2f px" % [
		measured["frames"], measured["total_ms"], measured["total_ms"] / measured["frames"], " ".join(by_ticks),
		measured["mean"], measured["sd"], measured["min"], measured["max"], measured["stalls"],
		measured["corrections"], measured.get("off_centre", 0.0)]


static func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


static func _stddev(values: Array[float], mean: float) -> float:
	var total := 0.0
	for v in values:
		total += (v - mean) * (v - mean)
	return sqrt(total / values.size())
