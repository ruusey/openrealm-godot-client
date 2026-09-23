class_name EntityRenderer
extends Node2D

## Draws the players, enemies, loot and portals EntityQueue hands it.
## Bullets are BulletRenderer's job -- they neither sort nor mirror.
##
## Its own canvas item, so an effect on the characters leaves the ground and
## the projectiles alone.

const EMPTY_COUNTS := {"players": 0, "enemies": 0, "containers": 0,
	"portals": 0, "shadows": 0}


var state: RealmState
var content: GameData
var queue := EntityQueue.new()
var counts := EMPTY_COUNTS.duplicate()


func _draw() -> void:
	if state == null or content == null:
		return
	counts = draw_ground(self, queue.build(state, content, ViewRect.of(self)))


## Shadows go down in a pass of their own, ahead of the bodies, so the
## ellipses batch instead of alternating with a texture draw per entity. The
## native client separates them for the same reason; the web client parents
## each shadow to its own entity and gets the same picture, because the queue
## is sorted on feet -- a later entity is always lower, so its shadow can
## never reach the body of one already drawn. Measured: interleaving the two
## loops renders byte-identical output.
func draw_ground(canvas: CanvasItem, items: Array) -> Dictionary:
	var counts := EMPTY_COUNTS.duplicate()
	# Every body on the pixel grid -- the same snap the overlay applies to
	# the name and bars under it, through the same transform, so the two
	# land on the same pixel and move together. Snapped after the sort,
	# which reads the true feet.
	for item in items:
		item["pos"] = PixelSnap.world(canvas, item["pos"])
	for item in items:
		if GroundShadow.under_entity(canvas, item["pos"], item["size"]):
			counts["shadows"] += 1
	for item in items:
		_draw_entity(canvas, item)
		counts[item["kind"]] += 1
	return counts


## Where a frame lands, given the body cell it belongs to.
##
## Anchored by the bottom of that cell rather than by the cell itself: a
## taller frame grows upward, and a wider one grows away from the body --
## rightward as authored, leftward once mirrored -- so the overhanging part of
## a swing always lands on the side the character is facing. Get the mirrored
## case wrong and the weapon sticks out of the character's back.
static func frame_rect(origin: Vector2, cell: float, draw: Vector2,
		flip: bool) -> Rect2:
	return Rect2(
		origin.x + (cell - draw.x if flip else 0.0),
		origin.y + cell - draw.y,
		draw.x, draw.y)


## Missing art becomes a solid block in the entity's fallback colour, so a
## content gap is visible on screen rather than silently absent.
##
## Mirroring goes through a scale transform. draw_texture_rect's last argument
## is `transpose`, which swaps the X and Y axes -- passing a flip there draws a
## side-facing sprite rotated onto its side, which reads as the character
## facing downward while it walks left. A negative-width Rect2 mirrors but
## also displaces the sprite, so neither shortcut works.
## Where an entity's body lands and which slice of its sheet shows.
##
## Everything a caller would otherwise have to read back off a canvas: a
## standing entity draws its whole frame, and one in a liquid sinks by three
## tenths and is clipped to its cell, so the legs go under the surface. Done
## to the rect and the slice rather than with a mask, because an
## immediate-mode layer has no per-command mask to do it with.
static func body_draw(item: Dictionary) -> Dictionary:
	var rect := frame_rect(item["pos"], float(item["size"]), item["draw"], item["flip"])
	var texture: Texture2D = item["texture"]
	if not item.get("wading", false) or texture == null:
		return {"rect": rect, "slice": Rect2()}

	var cell := Rect2(item["pos"], Vector2.ONE * float(item["size"]))
	var sunk := Wading.sunk(rect, float(item["size"]))
	var shown := Wading.shown(sunk, cell)
	return {"rect": shown, "slice": Wading.slice(texture, sunk, shown)}


func _draw_entity(canvas: CanvasItem, item: Dictionary) -> void:
	var flip: bool = item["flip"]
	var texture: Texture2D = item["texture"]
	var body := body_draw(item)
	var rect: Rect2 = body["rect"]
	var slice: Rect2 = body["slice"]
	if flip:
		# Origin at the sprite's right edge with x negated, so local x in
		# [0, size] covers the same cell right-to-left.
		canvas.draw_set_transform(rect.position + Vector2(rect.size.x, 0.0), 0.0,
			Vector2(-1.0, 1.0))
		rect = Rect2(Vector2.ZERO, rect.size)

	if texture != null:
		SpriteOutline.stamp(canvas, texture, rect, slice)
		if slice.size == Vector2.ZERO:
			canvas.draw_texture_rect(texture, rect, false, item["modulate"])
		else:
			canvas.draw_texture_rect_region(texture, rect, slice, item["modulate"])
	else:
		canvas.draw_rect(rect, item["tint"])

	if flip:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
