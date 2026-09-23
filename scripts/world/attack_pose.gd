class_name AttackPose
extends RefCounted

## The swing a character plays while shooting.
##
## Unlike the walk cycle this runs on the wall clock, not on distance
## travelled. Both references say so, and the native client records why:
## routing attack frames through the pace path leaves a standing-still attack
## stuck on frame 0 -- the same trap the walk cycle already cost us here.
##
## The clip plays once and holds its last frame for the rest of the window
## rather than looping; a new shot restarts it from the beginning. ClassSprites
## does that clamping, since it is what knows how many frames the clip has.
##
## The facing tokens are "side", "up" and "down" -- deliberately not the walk
## cycle's "front" and "back". The content really is named `attack_down` and
## `walk_front`, so handing this a walk token resolves to a clip that does not
## exist and falls back to idle without a word.

## How long the swing lasts. This is the web client's shootingAnimTimer; the
## native client holds it for 350ms instead, and the web client is the one
## version-locked to the server we talk to.
const DURATION := 0.3
## Seconds per frame. Both references agree to the millisecond.
const FRAME_SECONDS := 0.08

## "side" / "up" / "down" while swinging, "" when idle.
var facing := ""
## Counts up without bound; the content layer decides where the clip ends.
var frame := 0
var facing_left := false

var _remaining := 0.0
var _frame_timer := 0.0


## Starts, or restarts, a swing aimed along `direction` in world space.
func begin(direction: Vector2) -> void:
	facing = clip_for(direction)
	if facing == "side":
		facing_left = direction.x < 0.0
	frame = 0
	_frame_timer = 0.0
	_remaining = DURATION


## Which of the three clips a direction picks: the dominant axis decides, and
## +Y is downward on screen. A direction with no dominant axis at all takes
## the front-facing clip, which is what the web client's cast path does.
static func clip_for(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "side"
	return "up" if direction.y < 0.0 else "down"


func tick(delta: float) -> void:
	if not is_active():
		return
	_remaining -= delta
	if _remaining <= 0.0:
		reset()
		return

	_frame_timer += delta
	# `while`, not `if`: one long frame after a hitch should advance the frames
	# it covers rather than swallowing them. The native client does the same.
	while _frame_timer >= FRAME_SECONDS:
		_frame_timer -= FRAME_SECONDS
		frame += 1


func is_active() -> bool:
	return facing != ""


func reset() -> void:
	facing = ""
	frame = 0
	_frame_timer = 0.0
	_remaining = 0.0
