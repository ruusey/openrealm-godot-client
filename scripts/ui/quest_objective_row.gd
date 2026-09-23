class_name QuestObjectiveRow
extends RefCounted

## One objective of a quest card: "[x] label" or "[ ] label" with
## "progress / target" beside it, and a bar under both -- the web's q-obj.


static func add(into: Container, objective: Dictionary, width: float) -> ProgressBar:
	var target := maxi(1, int(objective.get("target", 1)))
	var progress := clampi(int(objective.get("progress", 0)), 0, target)
	var top := HBoxContainer.new()
	into.add_child(top)
	var label := HudWidgets.label("%s %s" % ["[x]" if progress >= target else "[ ]",
		String(objective.get("label", "Objective"))], 12, Color("cdd5e4"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	top.add_child(HudWidgets.label("%s / %s" % [Mastery.thousands(progress), Mastery.thousands(target)],
		12, Color("8a93a8")))
	var bar := ProgressBar.new()
	bar.max_value = float(target)
	bar.value = float(progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("0e1017")
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("4d8bff")
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	into.add_child(bar)
	return bar
