class_name TransitionArt
extends RefCounted

## The moving parts of the transition splash: the web client's walking
## sprite, and the difficulty as a row of pips.
##
## The sprite walks at the character's own pace -- the web's FRAME_MS, a
## leg swap every 24 px at the server's speed formula, tiles a second
## 4 + 5.6 * SPD / 75 at 32 px a tile -- so it is the gait the player will
## have when they land. The difficulty is the portal's: the realm it leads
## to, seven pips with as many lit as the difficulty rounds to.

const SPRITE := 64
const PIPS := 7
const PIP := Vector2(12, 12)
const LIT := Color("c04040")
const UNLIT := Color("333333")
const DEFAULT_SPD := 30


## Milliseconds a walk frame is held, at a character's speed.
static func frame_ms(spd: int) -> float:
	var px_per_second := (4.0 + 5.6 * float(spd) / 75.0) * 32.0
	return 24000.0 / px_per_second


static func walk_frame(elapsed_ms: int, spd: int) -> int:
	return int(float(maxi(elapsed_ms, 0)) / frame_ms(spd))


## The web's walk_front, or walk_side for a class that has no front walk.
static func facing(content: GameData, class_id: int) -> String:
	var clips: Dictionary = content.library.animations.get(class_id, {}).get("animations", {})
	return "front" if clips.has("walk_front") or not clips.has("walk_side") else "side"


static func lit_pips(difficulty: float) -> int:
	return clampi(roundi(difficulty), 0, PIPS)


static func label(difficulty: float) -> String:
	return "Difficulty %.1f" % difficulty if difficulty > 0.0 else ""


## A row of PIPS squares, for set_pips to colour.
static func pip_row(into: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	into.add_child(row)
	for i in PIPS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row


static func set_pips(row: HBoxContainer, difficulty: float) -> void:
	row.visible = difficulty > 0.0
	var lit := lit_pips(difficulty)
	for i in row.get_child_count():
		(row.get_child(i) as ColorRect).color = LIT if i < lit else UNLIT
