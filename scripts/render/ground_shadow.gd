class_name GroundShadow
extends RefCounted

## The soft ellipse a sprite stands on.
##
## Both references draw one and agree on its shape -- 0.4 of the sprite wide
## and 0.12 tall, in flat black -- and both lay every shadow down before any
## body, so a character never stands on its neighbour's shadow.
##
## Godot has no draw_ellipse, so this is a circle under a flattening
## transform: one draw command, and no polygon to rebuild every frame.

## Half-width as a fraction of the sprite, and the vertical squash that turns
## the circle into the 0.12-tall ellipse both clients use.
const HALF_WIDTH := 0.4
const FLATTEN := 0.3

## Where the ellipse centre sits, measured down from the sprite's top edge, and
## how dark it is. A character's falls just past its feet; a prop's sits a
## little higher and a little darker. These are the web client's numbers -- the
## native client's are within a few pixels of them.
const ENTITY_CENTRE := 1.08
const ENTITY_ALPHA := 0.3
const OBJECT_CENTRE := 0.9
const OBJECT_ALPHA := 0.35


## Under a player, enemy or portal.
##
## The web client narrows the ellipse for loot specifically (0.35 by 0.1). We
## still draw loot as a placeholder block rather than its sprite, so there is
## nothing yet for a distinct shape to sit under.
static func under_entity(canvas: CanvasItem, origin: Vector2, size: float) -> bool:
	return stamp(canvas, origin, size, ENTITY_CENTRE, ENTITY_ALPHA)


## Under a collision prop -- an anvil, a table, a torch.
static func under_object(canvas: CanvasItem, origin: Vector2, size: float) -> bool:
	return stamp(canvas, origin, size, OBJECT_CENTRE, OBJECT_ALPHA)


## Reports whether anything was drawn, so a caller counting shadows counts the
## draws rather than the entities it walked past.
static func stamp(canvas: CanvasItem, origin: Vector2, size: float,
		centre: float, alpha: float) -> bool:
	if size <= 0.0:
		return false
	canvas.draw_set_transform(origin + Vector2(size * 0.5, size * centre), 0.0,
		Vector2(1.0, FLATTEN))
	canvas.draw_circle(Vector2.ZERO, size * HALF_WIDTH, Color(0.0, 0.0, 0.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
