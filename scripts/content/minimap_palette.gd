class_name MinimapPalette
extends RefCounted

## What colour a tile is from above.
##
## The web client's TILE_COLORS and its _getTileColor, which the native
## client copies pixel for pixel: the collision layer wins and is grey (light
## for a wall, dark for anything else solid), a liquid is blue and a
## damaging floor red by flag, and everything else is keyed off the tile's
## NAME -- the content carries no biome, so "sand", "grass" and "stone" in
## the name are the only record of what a floor looks like. A name that
## matches nothing gets a brown hashed from its id, so two unknown floors
## still tell apart.
##
## One deliberate difference: the flags are tested damaging FIRST. Both
## references test the liquid flag first, and every shipped lava tile also
## slows, so their minimaps paint lava as water. The red exists for the
## floor that burns you, and that is the one to warn about.

const VOID := Color.BLACK
const WALL := Color("#aaaaaa")
const SAND := Color("#c8b888")
const GRASS := Color("#4a7a45")
const STONE := Color("#606068")
const WATER := Color("#3060a0")
const LAVA := Color("#c04020")
const DARK := Color("#2a2030")
const DEFAULT := Color("#3a3a38")

## In the web client's order, so a name that matches two keeps its colour.
const BY_NAME := [
	[["sand", "beach", "desert"], SAND],
	[["grass", "forest", "green"], GRASS],
	[["stone", "grey", "rock", "cobble"], STONE],
	[["dark", "void", "obsidian"], DARK],
	[["water", "ocean", "sea"], WATER],
]


## The pixel for one cell, given what each layer holds there (-1 or 0 for
## nothing). Solid beats floor, and a cell with neither is a hole.
static func for_cell(content: GameData, base_id: int, collision_id: int) -> Color:
	if collision_id > 0:
		return WALL if content != null and content.tile_is_wall(collision_id) else STONE
	return for_base(content, base_id)


static func for_base(content: GameData, tile_id: int) -> Color:
	if tile_id <= 0:
		return VOID
	if content == null or not content.tiles.has(tile_id):
		return DEFAULT
	var data := content.tile_data(tile_id)
	if int(data.get("damaging", 0)) != 0:
		return LAVA
	if content.tile_slows(tile_id) and not content.tile_has_collision(tile_id):
		return WATER
	var name := content.tile_name(tile_id).to_lower()
	for entry in BY_NAME:
		for keyword in entry[0]:
			if name.contains(keyword):
				return entry[1]
	return hashed(tile_id)


## The web client's fallback: hsl((id * 37) % 60 + 20, 30%, 35%), a hue
## between orange and yellow at low saturation -- a dirt brown.
static func hashed(tile_id: int) -> Color:
	return from_hsl(float((tile_id * 37) % 60 + 20) / 360.0, 0.3, 0.35)


## Godot has HSV and CSS has HSL; the conversion between the two.
static func from_hsl(hue: float, saturation: float, lightness: float) -> Color:
	var value := lightness + saturation * minf(lightness, 1.0 - lightness)
	var hsv_saturation := 0.0 if value == 0.0 else 2.0 * (1.0 - lightness / value)
	return Color.from_hsv(hue, hsv_saturation, value)
