class_name VaultPanel
extends CanvasLayer

## A small control shown only while standing in the vault: the chest count and an
## "Add Vault Chest" button. The chest is created through the data service, which
## caps it (1 for a guest, 10 otherwise); it's written to the account and appears
## on the next vault entry -- re-entering to use a just-added chest is standard.

var state: RealmState
var content: GameData
var data_service: DataService

var _root: PanelContainer
var _count: Label
var _status: Label
var _button: Button
var _adding := false
## So the account is re-read once on each entry, not every frame.
var _was_in_vault := false


func setup(realm_state: RealmState, game_data: GameData, service: DataService) -> void:
	state = realm_state
	content = game_data
	data_service = service


func _ready() -> void:
	layer = 11
	visible = false
	_root = PanelContainer.new()
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.offset_top = 72.0
	add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_root.add_child(column)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_count)
	_button = Button.new()
	_button.text = "Add Vault Chest"
	_button.pressed.connect(_on_add)
	column.add_child(_button)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92))
	column.add_child(_status)


func _process(_delta: float) -> void:
	var in_vault := state != null and content != null and state.local.is_present() \
		and state.tiles.width > 0 and content.maps.is_vault(state.tiles.map_id)
	visible = in_vault
	if in_vault and not _was_in_vault:
		# Entered: re-read the account so the count reflects the seeded/saved vault.
		_status.text = ""
		_refresh()
		_reload_count()
	_was_in_vault = in_vault


func _reload_count() -> void:
	await data_service.refresh_account()
	if visible:
		_refresh()


func _refresh() -> void:
	_count.text = "Vault Chests: %d" % data_service.chest_count()
	_button.disabled = _adding


func _on_add() -> void:
	if _adding or data_service == null:
		return
	_adding = true
	_refresh()
	var result := await data_service.create_chest()
	_adding = false
	_refresh()
	if result["success"]:
		_status.text = "Chest added (now %d). Re-enter the vault to use it." % data_service.chest_count()
	else:
		_status.text = str(result["result"])


func captures_mouse() -> bool:
	return visible and _root.get_global_rect().has_point(_root.get_global_mouse_position())
