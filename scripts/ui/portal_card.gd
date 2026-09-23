class_name PortalCard
extends RefCounted

## What is written under a portal: the minimal line by default, and the
## card the web client expands the portal you are standing on into.
##
## The badge is the tier for a tiered realm and the difficulty otherwise;
## the card adds the difficulty, how many are in the realm, how far its
## purification has come and its modifiers -- or, for a tiered realm that
## has not rolled them yet, that they are revealed on entry. Text and
## thresholds are the web client's renderPortal to the character.

## Standing on or beside the portal: centre to centre, in tiles.
const REACH_TILES := 1.3
const TIERED := Color("ff9a6b")
const PLAIN := Color("9fe6c0")


static func badge(portal: Dictionary) -> String:
	var tier := int(portal.get("tier", 0))
	var difficulty := float(portal.get("difficulty", 0.0))
	if tier > 1:
		return "T%d" % tier
	return "D%s" % number(difficulty) if difficulty > 0.0 else ""


## "2.5", or "3" for a whole number, as the web prints it.
static func number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, floorf(value)) else "%.1f" % value


## The line under a portal no one is standing on. Empty for a portal with
## no realm behind it, which gets no caption at all.
static func caption(portal: Dictionary) -> String:
	var label := String(portal.get("label", ""))
	var mark := badge(portal)
	if label == "" or mark == "":
		return label
	return "%s  -  %s" % [label, mark]


## The card, one line per fact.
static func card(portal: Dictionary) -> String:
	var label := String(portal.get("label", ""))
	if label == "":
		return ""
	var mark := badge(portal)
	var lines: Array = ["%s   [%s]" % [label, mark] if mark != "" else label]
	var facts: Array = []
	var difficulty := float(portal.get("difficulty", 0.0))
	if difficulty > 0.0:
		facts.append("Difficulty %s" % number(difficulty))
	facts.append("%d in realm" % int(portal.get("player_count", 0)))
	lines.append("  -  ".join(facts))
	var goal := int(portal.get("goal", 0))
	if goal > 0:
		lines.append("Purified %d%%" % clampi(roundi(int(portal.get("purified", 0)) * 100.0 / goal), 0, 100))
	var modifiers := String(portal.get("modifiers", "")).strip_edges()
	if modifiers != "":
		var badges: Array = []
		for part in modifiers.split(","):
			badges.append("[%s]" % part.strip_edges())
		lines.append(" ".join(badges))
	elif int(portal.get("tier", 0)) > 1:
		lines.append("Modifiers revealed on entry")
	return "\n".join(lines)


static func focused(portal_position: Vector2, local_centre: Vector2) -> bool:
	var tile := float(GameConstants.TILE_SIZE)
	var centre := portal_position + Vector2(tile, tile) * 0.5
	return centre.distance_squared_to(local_centre) <= (tile * REACH_TILES) * (tile * REACH_TILES)


static func colour(portal: Dictionary) -> Color:
	return TIERED if int(portal.get("tier", 0)) > 1 else PLAIN


## The card's backing: near-black at 0.82, a thin green-grey border, rounded
## at 6, padded 7.
static func box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a0f0c", 0.82)
	style.border_color = Color("3a5a48", 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(7.0)
	return style
