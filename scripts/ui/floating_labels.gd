class_name FloatingLabels
extends RefCounted

## The labels pinned to the world that belong to no character: portal
## captions, and the combat numbers that float off a hit.
##
## Pooled Labels under the overlay's root -- captions by portal id, numbers
## by slot, as the web client's `_damageTextSlots` -- placed on whole screen
## pixels. A number is centred on the hit, fading and shrinking as it goes,
## which is what both references do: alpha from the life left, scale
## 0.8 + 0.4 of it.

const DAMAGE_SIZE := 24
const CAPTION_SIZE := 14

var captions := 0
var texts := 0

var _captions: ControlPool
var _numbers: ControlPool


func _init(root: Control) -> void:
	_captions = ControlPool.new(root, func() -> Control: return _label(TagStyles.caption_label()))
	_numbers = ControlPool.new(root, func() -> Control: return _label(TagStyles.damage_label()))


func show_all(state: RealmState, to_screen: Transform2D, view: Rect2) -> void:
	captions = 0
	texts = 0
	if state != null:
		_show_captions(state, to_screen, view)
		_show_numbers(state, to_screen, view)
	_captions.sweep()
	_numbers.sweep()


static func number_scale(fade: float) -> float:
	return 0.8 + 0.4 * fade


## What a portal leads to, under it: the realm's name and its badge, and
## for the one you are standing on the web client's whole card, boxed.
## targetLabel is empty on a portal with no realm behind it (the vault, an
## exit), and those get no caption at all.
func _show_captions(state: RealmState, to_screen: Transform2D, view: Rect2) -> void:
	var tile := float(GameConstants.TILE_SIZE) * to_screen.get_scale().x
	for id in state.entities.portals:
		var portal: Dictionary = state.entities.portals[id]
		var position := state.entities.render_position(portal)
		var focused := state.local.is_present() and PortalCard.focused(position, state.local.render_centre())
		var caption := PortalCard.card(portal) if focused else PortalCard.caption(portal)
		if caption == "" or not view.has_point(position):
			continue
		var label: Label = _captions.acquire(id)
		label.text = caption
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.label_settings.font_color = PortalCard.colour(portal)
		if focused:
			label.add_theme_stylebox_override("normal", PortalCard.box())
		else:
			label.remove_theme_stylebox_override("normal")
		label.reset_size()
		var at := EntityOverlay.screen(to_screen, position)
		label.position = Vector2(at.x + tile * 0.5 - label.size.x * 0.5, at.y + tile + 4.0).round()
		captions += 1


func _show_numbers(state: RealmState, to_screen: Transform2D, view: Rect2) -> void:
	if not state.settings.is_on("show_damage_numbers"):
		return
	var slot := 0
	for text in state.texts.texts:
		var at := DamageText.render_position(text)
		if not view.has_point(at):
			continue
		var label: Label = _numbers.acquire(slot)
		slot += 1
		label.text = text["text"]
		label.reset_size()
		var fade := DamageText.alpha_of(text)
		label.modulate = Color(text["colour"], fade)
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE * number_scale(fade)
		label.position = (EntityOverlay.screen(to_screen, at) - label.size * 0.5).round()
		texts += 1


static func _label(style: LabelSettings) -> Label:
	var label := Label.new()
	label.label_settings = style
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
