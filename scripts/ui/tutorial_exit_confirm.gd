class_name TutorialExitConfirm
extends CanvasLayer

## "You haven't finished the tutorial quests!", with Exit anyway / Keep playing.
##
## PortalInput asks this before any exit that leaves the tutorial while its
## onboarding quests are still open (via the confirm_exit hook it is handed in
## main). The button the player picks is passed back as the answer, and only
## "Exit anyway" lets the transition fire.

var _root: PanelContainer
var _on_result: Callable
var _showing := false


func _ready() -> void:
	layer = 17
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_root = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171f")
	style.border_color = Color("8a6d3b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_root.add_theme_stylebox_override("panel", style)
	centre.add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)
	var line := HudWidgets.label(
		"You haven't finished the tutorial quests!\nAre you sure you want to exit?",
		15, Color("f0d890"))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	InventoryLayout.button(buttons, "Exit anyway", func() -> void: _answer(true))
	InventoryLayout.button(buttons, "Keep playing", func() -> void: _answer(false))


## Show the prompt and remember who to tell. A second request while one stands
## is ignored, so a held exit key cannot stack dialogs.
func request(on_result: Callable) -> void:
	if _showing:
		return
	_showing = true
	_on_result = on_result
	visible = true


func _answer(exit_anyway: bool) -> void:
	if not _showing:
		return
	_showing = false
	visible = false
	if _on_result.is_valid():
		_on_result.call(exit_anyway)


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
