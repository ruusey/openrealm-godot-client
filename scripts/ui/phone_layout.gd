class_name PhoneLayout
extends RefCounted

## Where the HUD goes with touch controls, in the panels' points
## (TouchFrame): the vitals top-left with the party, nearby and chat
## stacked under them, the map top-right with Menu, Bag and Chat in a
## column beside it, and the bottom left to the thumbs -- the move stick
## and the touch layer's Attack cluster. Main turns it on with the touch
## controls, before the layers are built.

const MARGIN := 8.0
const GAP := 6.0
const MAP_SIDE := 104.0
const BUTTON_SIZE := Vector2(60.0, 30.0)
const BUTTON_FONT := 13
const VITALS_WIDTH := 200.0
const CHAT_WIDTH := 300.0
const CHAT_LINES := 3

static var on := false
## Where the vitals end; PlayerHud keeps it up to date as it draws.
static var vitals_bottom := MARGIN
## The open bag and the open chat each fill the left column; the party and
## nearby lists give way to them.
static var bag_open := false
static var chat_open := false


static func column_taken() -> bool:
	return on and (bag_open or chat_open)


## Where the left column starts, under the vitals.
static func column_top() -> float:
	return vitals_bottom + GAP


## Where a left-column panel's fold chip goes: its usual corner, or the
## column's edge once folded, where the panel it would sit on is gone.
static func chip_x(panel_right: float, chip_width: float, folded: bool) -> float:
	return MARGIN if on and folded else panel_right - chip_width - 2.0


## The map's square in the top-right corner of `screen`.
static func map_rect(screen: Vector2) -> Rect2:
	return Rect2(screen.x - MARGIN - MAP_SIDE, MARGIN, MAP_SIDE, MAP_SIDE)


## The top-left corner of the Menu, Bag and Chat column, left of the map.
static func buttons_at(screen: Vector2) -> Vector2:
	return Vector2(map_rect(screen).position.x - GAP - BUTTON_SIZE.x, MARGIN)
