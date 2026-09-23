class_name SpriteOutline
extends RefCounted

## A dark silhouette behind a sprite, so characters and shots stay legible
## against terrain of any colour.
##
## Drawn as offset copies of the sprite itself rather than through a shader.
## The native client uses a shader because LibGDX can swap one per sprite; we
## cannot -- a material belongs to a canvas item, not a draw command -- and
## the web client does it this way too, sharing one texture so the copies
## batch.
##
## Eight offsets, not four: the diagonals fill the corner pixels that a
## cardinal-only stroke leaves as a missing sliver on concave edges, like the
## notches of a plus-shaped projectile.
##
## One world unit, not a screen pixel. The web client's note is worth keeping:
## at a fractional device pixel the stroke antialiases into near-invisibility
## on some edges and appears to flicker as the camera moves.

const OFFSET := 1.0
## The options' "Sprite outlines"; GameSettings.apply sets it.
static var enabled := true
const TINT := Color(0.0, 0.0, 0.0, 0.85)

const OFFSETS := [
	Vector2(OFFSET, 0.0), Vector2(-OFFSET, 0.0),
	Vector2(0.0, OFFSET), Vector2(0.0, -OFFSET),
	Vector2(OFFSET, OFFSET), Vector2(OFFSET, -OFFSET),
	Vector2(-OFFSET, OFFSET), Vector2(-OFFSET, -OFFSET),
]


## Stamps the silhouette for a sprite occupying `rect`. Offsets are applied in
## whatever space the caller is drawing in; the set is symmetric, so a
## mirrored or rotated frame produces the same ring.
##
## `slice` names part of a sheet to draw instead of the whole texture, for a
## sprite that is clipped rather than drawn entire -- a body standing in
## water. The outline has to be clipped with it or the silhouette keeps the
## legs the body just lost.
static func stamp(canvas: CanvasItem, texture: Texture2D, rect: Rect2,
		slice := Rect2()) -> void:
	if not enabled:
		return
	for offset in OFFSETS:
		var at := Rect2(rect.position + offset, rect.size)
		if slice.size == Vector2.ZERO:
			canvas.draw_texture_rect(texture, at, false, TINT)
		else:
			canvas.draw_texture_rect_region(texture, at, slice, TINT)
