class_name ExperienceLevels
extends RefCounted

## What a character's experience means: its level, and past the last
## level, its fame.
##
## The server's ExperienceModel over exp-levels.json, whose
## `levelExperienceMap` is level -> "min-max". A total past the highest
## max is one level more than the table holds -- level 20 on the shipped
## table -- and every 2500 beyond it is a point of fame, which is what the
## character banks on death. The web client's getPlayerLevel and
## getBaseFame are the same reading, and the HUD's XP bar is built on it.

const FAME_PER := 2500

var ranges := {}   # level -> [min, max]
var max_level := 1
var max_experience := 0


func parse(table: Dictionary) -> void:
	ranges.clear()
	max_level = 1
	max_experience = 0
	for key in table.get("levelExperienceMap", {}):
		var bounds: PackedStringArray = str(table["levelExperienceMap"][key]).split("-")
		if bounds.size() != 2 or not str(key).is_valid_int():
			continue
		var level := int(key)
		ranges[level] = [int(bounds[0]), int(bounds[1])]
		max_level = maxi(max_level, level)
		max_experience = maxi(max_experience, int(bounds[1]))


func loaded() -> bool:
	return not ranges.is_empty()


func level_for(experience: int) -> int:
	if not loaded():
		return 1
	if experience > max_experience:
		return max_level + 1
	var level := 1
	for candidate in ranges:
		if ranges[candidate][0] <= experience and experience <= ranges[candidate][1]:
			level = candidate
	return level


func fame_for(experience: int) -> int:
	if not loaded() or experience <= max_experience:
		return 0
	return (experience - max_experience) / FAME_PER


## How far into its level a total is, as [into, span]: zero over zero
## when the table is missing or the level has no range.
func progress_for(experience: int) -> Array:
	var bounds: Array = ranges.get(level_for(experience), [])
	if bounds.is_empty():
		return [0, 0]
	return [experience - bounds[0], bounds[1] - bounds[0]]
