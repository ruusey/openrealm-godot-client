class_name PanelFit
extends RefCounted

## A panel that would not fit the screen, shrunk until it does.
##
## The modal panels -- the options, the bag, the sheet, the shops, the
## forge, the market, a trade, the sign-in -- are laid out for 720 rows,
## and on a phone's 400 the options ran off the bottom with their Close
## button, and the bag its potions. Rather than a second layout for each,
## a panel taller or wider than the screen is scaled down, about a pivot
## that keeps it where its anchors put it: the centre for one in a
## CenterContainer, the top-right corner for the bag. Nothing changes on a
## screen with room; the scale is never over one.

const MARGIN := 12.0


## Called from the panel's own _process while it shows. `room` is the
## screen less the margins unless the panel has less to fill.
static func shrink(panel: Control, pivot := Vector2(0.5, 0.5), margin := MARGIN, room := Vector2.ZERO) -> void:
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	if room == Vector2.ZERO:
		room = TouchScale.view_size(panel) - Vector2.ONE * margin * 2.0
	panel.pivot_offset = panel.size * pivot
	panel.scale = Vector2.ONE * factor(panel.size, room)
	# A centring parent outgrown by the panel spreads both ways, or it grows down
	# off the screen and the shrink centres on a point below the middle.
	var centre := panel.get_parent() as CenterContainer
	if centre != null and centre.grow_vertical != Control.GROW_DIRECTION_BOTH:
		centre.grow_horizontal = Control.GROW_DIRECTION_BOTH
		centre.grow_vertical = Control.GROW_DIRECTION_BOTH


## The largest scale, up to one, at which `panel_size` fits `room`.
static func factor(panel_size: Vector2, room: Vector2) -> float:
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return 1.0
	return minf(1.0, minf(room.x / panel_size.x, room.y / panel_size.y))
