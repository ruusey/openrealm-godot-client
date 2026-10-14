class_name ClassSprites
extends RefCounted

## Resolves a character class's artwork: which animation frame to draw, and
## what the class is called.
##
## Its own file because the clip lookup is the fiddliest content mapping we
## have -- action and facing name a clip, the frame index wraps within it, and
## attack frames are wider than the cell they sit in.

## The one action whose frames hold rather than loop.
const ATTACK := "attack"

## Every frame and every entity on screen asks for its sprite, and resolving one
## formats two or three string keys, so clips are kept by (class, action and
## facing) and sliced frames by those plus the frame and dye. Cleared when the
## animations reload.
const ACTION_CODES := {"idle": 0, "walk": 1, "attack": 2}
const FACING_CODES := {"front": 0, "side": 1, "back": 2}

var _library: ContentLibrary
var _sprites: SpriteCache
var _dyes: DyedSprites
const NO_FRAMES: Array = []
var _frames := {}
var _clips := {}
var _frames_source: Dictionary


func _init(library: ContentLibrary, sprites: SpriteCache) -> void:
	_library = library
	_sprites = sprites
	_dyes = DyedSprites.new(library)


## Picks a frame from a class animation set. `action` is idle/walk/attack,
## `facing` is side/front/back; `dye_id`, when a character has one, recolours
## its cloth (DyedSprites).
func frame(class_id: int, action: String, facing: String, frame: int, dye_id := 0) -> Texture2D:
	if not is_same(_frames_source, _library.animations):
		_frames_source = _library.animations
		_frames.clear()
		_clips.clear()
	var code: int = ACTION_CODES.get(action, -1) * 4 + FACING_CODES.get(facing, -1)
	var known_codes := ACTION_CODES.has(action) and FACING_CODES.has(facing)
	var clip_key := Vector2i(class_id, code)
	var frames: Array = _clips.get(clip_key, NO_FRAMES) if known_codes else NO_FRAMES
	if frames.is_empty():
		frames = _clip_frames(class_id, action, facing)
		if frames.is_empty():
			return null
		if known_codes:
			_clips[clip_key] = frames
	# An attack plays once and holds its last frame; a walk loops. Both
	# references clamp rather than wrap here, and the pose outlives the clip
	# on purpose -- a swing that looped would read as a stutter.
	var index := mini(frame, frames.size() - 1) if action == ATTACK \
		else frame % frames.size()
	var key := Vector4i(class_id, code, index, dye_id)
	var known: Texture2D = _frames.get(key)
	if known != null:
		return known
	var resolved := _slice(class_id, frames[index], dye_id)
	# A frame whose sheet has not arrived yet is asked again next time.
	if resolved != null and known_codes:
		_frames[key] = resolved
	return resolved


func _clip_frames(class_id: int, action: String, facing: String) -> Array:
	var set: Dictionary = _library.animations.get(class_id, {})
	if set.is_empty():
		return NO_FRAMES
	var clips: Dictionary = set.get("animations", {})
	var clip: Dictionary = clips.get("%s_%s" % [action, facing], {})
	if clip.is_empty():
		clip = clips.get("idle_front", {})
	return clip.get("frames", NO_FRAMES)


func _slice(class_id: int, chosen: Dictionary, dye_id: int) -> Texture2D:
	var set: Dictionary = _library.animations.get(class_id, {})
	var size := int(set.get("spriteSize", SpriteCache.DEFAULT_SPRITE_SIZE))
	var row := int(chosen.get("row", 0))
	var col := int(chosen.get("col", 0))
	var slice := _sprites.atlas(set.get("spriteKey", ""), row, col, size, int(chosen.get("spriteWidth", size)))
	return _dyes.apply(slice, class_id, row, col, dye_id)


## The cell a class's frames are sliced at. A frame may be wider or taller
## than this -- an attack frame whose weapon overhangs the body -- and the
## ratio between the two is what the draw rect has to be scaled by.
func cell_size(class_id: int) -> int:
	return int(_library.animations.get(class_id, {}).get(
		"spriteSize", SpriteCache.DEFAULT_SPRITE_SIZE))


func display_name(class_id: int) -> String:
	return _library.classes.get(class_id, {}).get("className", "Class_%d" % class_id)


## Every known class id, ascending — used to populate pickers.
func class_ids() -> Array:
	var ids := _library.classes.keys()
	ids.sort()
	return ids


# --- weapons and projectiles ----------------------------------------------
