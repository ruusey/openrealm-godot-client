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

var _library: ContentLibrary
var _sprites: SpriteCache
var _dyes: DyedSprites


func _init(library: ContentLibrary, sprites: SpriteCache) -> void:
	_library = library
	_sprites = sprites
	_dyes = DyedSprites.new(library)


## Picks a frame from a class animation set. `action` is idle/walk/attack,
## `facing` is side/front/back; `dye_id`, when a character has one, recolours
## its cloth (DyedSprites).
func frame(class_id: int, action: String, facing: String, frame: int, dye_id := 0) -> Texture2D:
	var set: Dictionary = _library.animations.get(class_id, {})
	if set.is_empty():
		return null
	var clips: Dictionary = set.get("animations", {})
	var clip: Dictionary = clips.get("%s_%s" % [action, facing], {})
	if clip.is_empty():
		clip = clips.get("idle_front", {})
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return null

	# An attack plays once and holds its last frame; a walk loops. Both
	# references clamp rather than wrap here, and the pose outlives the clip
	# on purpose -- a swing that looped would read as a stutter.
	var index := mini(frame, frames.size() - 1) if action == ATTACK \
		else frame % frames.size()
	var chosen: Dictionary = frames[index]
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


# --- weapons and projectiles ----------------------------------------------
