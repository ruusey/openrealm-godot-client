class_name FxTrapPlaced
extends RefCounted

## TRAP_PLACED (7): a trap lying armed -- the snare ring of FxSnareRing,
## the same one a thrown trap becomes when it lands.


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, elapsed_ms: int) -> void:
	FxSnareRing.paint(canvas, fx["pos"], fx["radius"], progress, colour, elapsed_ms)
