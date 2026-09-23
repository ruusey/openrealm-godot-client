class_name ItemTooltip
extends PanelContainer

## The card that opens over an item: what it is, what it does, what it adds.
##
## The web client's tooltip: what it says is ItemCard's, and this is the
## card that shows it beside the cursor. A panel hands it the content and
## the realm once, so the card can say whether you can wear the item and
## what a weapon would do in your hands; without them those lines go.

const RARITY_NAMES := ["Mundane", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
## style.css `.it-rarity-N`.
const RARITY_COLOURS := [Color("8a8a8a"), Color("b8b8b8"), Color("4fc85a"),
	Color("3f8cff"), Color("b04fe0"), Color("ff9418")]
const WIDTH := 220
const PADDING := 8
const FONT_SIZE := 12
const CURSOR_GAP := Vector2(16, 12)
## Near-black, so the coloured names and the body text read over any
## ground; the default theme's grey panel washed them out.
const BACKGROUND := Color(0.05, 0.04, 0.07, 0.96)
const EDGE := Color(0.45, 0.38, 0.55)

## Set by the panel that owns the card, for the viewer-dependent lines.
var content: GameData
var state: RealmState

var _lines: VBoxContainer


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	add_child(margin)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_lines)


## What the card says, as [text, colour] pairs -- the words without the
## controls, so they can be checked without a viewport.
static func describe(item: Dictionary, game_data: GameData = null, viewer := {}) -> Array:
	return ItemCard.lines(item, game_data, viewer)


## A card that knows the realm and the content, for a panel to own.
static func of(realm_state: RealmState, game_data: GameData) -> ItemTooltip:
	var card := ItemTooltip.new()
	card.state = realm_state
	card.content = game_data
	return card


## Who is looking: their class and stats, once there is a player.
func viewer() -> Dictionary:
	if state == null or not state.local.is_present():
		return {}
	return {"class_id": state.local.class_id, "stats": state.local.stats}


func show_for(item: Dictionary, at: Vector2) -> void:
	show_lines(describe(item, content, viewer()), at)


## Any card at all, as [text, colour] pairs -- the ability bar's, for one.
##
## A wrapping label's minimum height comes from its width at the moment it
## is measured, and a label just made is 0 wide: it wraps a character per
## line, the card grows to fit that, and a container never shrinks on its
## own. So each line is given its width before it enters the tree, and the
## card is reset to its minimum once the lines are in.
func show_lines(lines: Array, at: Vector2) -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.free()
	var line_width := float(WIDTH - 2 * PADDING)
	for line in lines:
		var label := Label.new()
		label.text = line[0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = line_width
		label.size.x = line_width
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_color", line[1])
		_lines.add_child(label)
	reset_size()
	visible = true
	follow(at)


## Beside the cursor, flipped back inside the viewport at the edges.
func follow(at: Vector2) -> void:
	var bounds := get_viewport_rect().size
	var wanted := at + CURSOR_GAP
	if wanted.x + size.x > bounds.x:
		wanted.x = at.x - CURSOR_GAP.x - size.x
	if wanted.y + size.y > bounds.y:
		wanted.y = bounds.y - size.y
	position = wanted.max(Vector2.ZERO)


func hide_card() -> void:
	visible = false
