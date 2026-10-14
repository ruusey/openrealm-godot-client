class_name LockOnRing
extends RefCounted

## The ring under the enemy the phone's Attack will hit
## (EntityRegistry.lock_on). Touch controls only: a mouse aims itself.
## Drawn in the shadow pass, so it sits under the body like its shadow, an
## ellipse the same shape a little wider, in gold.

const HALF_WIDTH := 0.55
const WIDTH_PX := 1.5
const COLOUR := Color(1.0, 0.82, 0.3, 0.9)


static func draw(canvas: CanvasItem, origin: Vector2, size: float) -> void:
	var radius := size * HALF_WIDTH
	if radius <= 0.0:
		return
	# CircleStamp's unit ring under the shadow's flattened transform; the stroke is
	# widened by the flatten as draw_arc's was, so it reads as WIDTH_PX all round.
	canvas.draw_set_transform(origin + Vector2(size * 0.5, size * GroundShadow.ENTITY_CENTRE), 0.0,
		Vector2(radius, radius * GroundShadow.FLATTEN))
	canvas.draw_multiline(CircleStamp.unit_ring(32), COLOUR, WIDTH_PX / GroundShadow.FLATTEN / radius)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
