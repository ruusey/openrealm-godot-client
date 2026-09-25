class_name LeaderboardWindow
extends CanvasLayer

## The leaderboard in a realm: Menu's "Leaderboard", a window in the middle
## of the screen with a Close button.
##
## It used to stand beside the character select, where it took the room a
## thumb needed for the characters; now it is fetched each time it opens,
## as the web client fetches it each time its screen is shown, and a reply
## that lands after it is closed is dropped (`LeaderboardPanel.forget`).

var state: RealmState
var data_service: DataService
var shown := false

var panel := LeaderboardPanel.new()


func _init(realm_state: RealmState = null, game_data: GameData = null, service: DataService = null) -> void:
	state = realm_state
	data_service = service
	panel.game_data = game_data


func _ready() -> void:
	layer = 13
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.add_child(panel)
	# Opaque over the world, as the quest log is; the sign-in's was not.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171f")
	style.border_color = Color("3a4152")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	TouchSize.grow(InventoryLayout.button(panel.head, "Close", close), 14).custom_minimum_size.x = 72


## The layer itself polls, as every panel's does; nothing under it runs.
func _process(_delta: float) -> void:
	visible = shown and state != null and state.local.is_present()
	if visible:
		PanelFit.shrink(panel)


func toggle() -> void:
	if shown:
		close()
	else:
		shown = true
		panel.refresh(data_service)


func close() -> void:
	shown = false
	panel.forget()


func captures_mouse() -> bool:
	return visible and panel.visible and panel.get_global_rect().has_point(panel.get_global_mouse_position())
