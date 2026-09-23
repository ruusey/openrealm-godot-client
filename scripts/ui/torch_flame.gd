class_name TorchFlame
extends RefCounted

## Fire, as particles: what a torch on the login screen burns with, and
## how it lights the stone around it.
##
## The flames are the projectile trails' own pool and drawing -- a
## ParticleField emitted into from a fractional accumulator per torch, so
## the rate is frame-rate independent, and the field's drag is what makes
## a spark slow as it rises. The light is the mock-up's rule at tile
## granularity: ambient, darker toward the bottom, plus a warm falloff
## from each flame that flickers.

## Particles a second from one torch; a candle burns at a fraction of it.
const RATE := 90.0
const LIFE := Vector2(0.35, 0.7)
## Upward speed before the drag takes it, and the sideways sway.
const RISE := Vector2(220.0, 300.0)
const SWAY := 25.0
## A spark starts this big and burns down to this.
const SIZE := Vector2(14.0, 4.0)
const COLOURS := [Color(1.0, 0.92, 0.35), Color(1.0, 0.62, 0.15), Color(0.95, 0.3, 0.08)]
const GLOW_ALPHA := 0.18
## A candle burns at this share of a torch.
const CANDLE := 0.45


## `delta` worth of flame from every tip, `scale` shrinking a candle's to a
## candle's size. `acc` carries each tip's fraction between frames.
static func emit(field: ParticleField, tips: Array, delta: float, acc: Dictionary, scale := 1.0) -> void:
	var rng := field.rng
	for i in tips.size():
		var pending: float = acc.get(i, 0.0) + RATE * scale * delta
		var count := int(pending)
		acc[i] = pending - count
		for k in count:
			var tip: Vector2 = tips[i]
			field.spawn(tip + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(0.0, 4.0)) * scale,
				Vector2(rng.randf_range(-SWAY, SWAY), -rng.randf_range(RISE.x, RISE.y)) * scale,
				rng.randf_range(LIFE.x, LIFE.y), SIZE.x * scale, SIZE.y * scale,
				COLOURS[rng.randi_range(0, COLOURS.size() - 1)])


## How bright a flame burns at `seconds`: two sines out of phase, so no two
## torches breathe together, between 0.7 and 1.0.
static func flicker(seconds: float, phase: float) -> float:
	return 0.85 + 0.1 * sin(seconds * 13.0 + phase) + 0.05 * sin(seconds * 31.0 + phase * 1.7)


## The light on a point: `ambient` scaled down by `depth` (0 at the top of
## the scene, 1 at the bottom), plus `warm` from every light in
## [{at, strength}] falling off as the square of the distance to `radius`.
static func light(point: Vector2, ambient: Color, depth: float, lights: Array,
		warm: Color, radius: float) -> Color:
	var lit := ambient * (1.0 - 0.25 * depth)
	for source in lights:
		var distance: float = point.distance_to(source["at"])
		if distance < radius:
			var k := 1.0 - distance / radius
			lit += warm * (k * k * float(source["strength"]))
	return Color(minf(lit.r, 1.0), minf(lit.g, 1.0), minf(lit.b, 1.0))


## Every flame as a light, {at, strength}: the torches, then the candle at
## its share, each flickering on its own phase.
static func lights(torches: Array, candle: Vector2, now: float) -> Array:
	var out: Array = []
	for i in torches.size():
		out.append({"at": torches[i], "strength": flicker(now, i * 1.9)})
	out.append({"at": candle, "strength": CANDLE * flicker(now, 7.3)})
	return out


## A soft warm halo at each flame, sized and faded by how hard it burns.
static func paint_glow(canvas: CanvasItem, sources: Array) -> void:
	var dot := ParticleRenderer.soft_dot()
	for source in sources:
		var radius: float = HallTiles.LIGHT_RADIUS * 0.5 * float(source["strength"])
		var colour := HallTiles.WARM
		colour.a = GLOW_ALPHA * float(source["strength"])
		canvas.draw_texture_rect(dot, Rect2(source["at"] - Vector2(radius, radius),
			Vector2(radius, radius) * 2.0), false, colour)
