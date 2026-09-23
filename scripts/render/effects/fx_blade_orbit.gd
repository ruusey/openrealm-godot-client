class_name FxBladeOrbit
extends RefCounted

## BLADE_ORBIT (46): four shurikens circling the caster a quarter turn
## apart, each spinning on itself, at full strength for as long as it runs.
## The server re-sends it every ~250ms and only the newest draws, so the
## phase is taken from the clock (started + elapsed), not the effect's
## age: each refresh picks up where the last left off. The web client
## draws the tier's shuriken sprite; this is FxBladeShapes' vector star.

const BLADES := 4
## The web's 22 * SCALE screen pixels: 22 world units across.
const SIZE := 22.0


## The clock the phase runs on: when the effect started plus its age, the
## same instant whichever refresh packet is drawing it.
static func clock(fx: Dictionary, elapsed_ms: int) -> int:
	return int(fx.get("started", 0)) + elapsed_ms


## Never tighter than the web's 36 screen pixels.
static func orbit_radius(radius: float) -> float:
	return maxf(18.0, radius)


## Where blade `i` is on the circle: a turn every ~2.3 seconds.
static func orbit_angle(i: int, clock_ms: int) -> float:
	return float(i) / BLADES * TAU + clock_ms * 0.0028


## A blade's own spin: about two turns a second, each one set apart.
static func spin(i: int, clock_ms: int) -> float:
	return clock_ms * 0.012 + i * 0.7


static func draw(canvas: CanvasItem, fx: Dictionary, _progress: float, colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var now := clock(fx, elapsed_ms)
	var reach := orbit_radius(fx["radius"])
	for i in BLADES:
		var centre := Fx.polar(at, orbit_angle(i, now), reach)
		FxBladeShapes.shuriken(canvas, centre, spin(i, now), SIZE, colour, 1.0)
