class_name FxQuestComplete
extends RefCounted

## QUEST_COMPLETE (65): a quest done, around the player who did it. A
## white-gold flash and a shock ring at the start, a ring of sparks
## bursting outwards, and a fountain of sparks thrown up from the player
## that arc over and fall back trailing, cooling from white to gold to
## ember, with a few twinkles drifting up through it. Every spark is seeded
## by its index, so a scripted render draws the same frame twice. Each
## spark sits on a dark ember outline so it reads on gold sand as on stone.

const GOLD := Color("ffd040")
const EMBER := Color("ff7a28")
const WHITE_HOT := Color("fff6d0")
const OUTLINE := Color("4a1e06")
const FOUNTAIN_SPARKS := 64
const BURST_SPARKS := 20
const TWINKLES := 10
## World pixels a second squared, pulling the fountain back down.
const GRAVITY := 320.0
## Seconds: how long the fountain keeps throwing, a spark's life, its trail.
const LAUNCH_WINDOW := 0.8
const SPARK_LIFE := 0.9
const TRAIL := 0.05
const BURST_TIME := 0.55
const FLASH := 0.16
## Where the fountain leaves the player, above their centre.
const MOUTH := Vector2(0.0, -6.0)


## A steady 0..1 for spark `i`, a different one per `salt`.
static func noise(i: int, salt: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)


## Fountain spark `i` as [launched at (s), heading, speed (px/s), life (s)]:
## thrown up within a cone, launched evenly over the window.
static func fountain_spark(i: int) -> Array:
	var launch := LAUNCH_WINDOW * float(i) / FOUNTAIN_SPARKS + noise(i, 1) * 0.02
	var heading := -PI / 2.0 + (noise(i, 2) - 0.5) * 1.7
	var speed := 115.0 + noise(i, 3) * 95.0
	var life := SPARK_LIFE * (0.75 + noise(i, 4) * 0.5)
	return [launch, heading, speed, life]


## Where a spark thrown along `heading` at `speed` is `age` seconds on.
static func arc_point(at: Vector2, heading: float, speed: float, age: float) -> Vector2:
	return at + MOUTH + Vector2(cos(heading), sin(heading)) * speed * age + Vector2(0.0, 0.5 * GRAVITY * age * age)


## White-hot at the throw, gold through the arc, ember as it dies.
static func spark_colour(t: float) -> Color:
	return WHITE_HOT.lerp(GOLD, minf(1.0, t * 1.8)).lerp(EMBER, maxf(0.0, t - 0.6) * 2.5)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, _colour: Color, elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	var seconds := elapsed_ms / 1000.0
	var fade := 1.0 - progress
	CircleStamp.disc(canvas, at + Vector2(0.0, 6.0), radius * 0.55, Color(GOLD, 0.16 * fade))
	if seconds < FLASH:
		var k := seconds / FLASH
		CircleStamp.disc(canvas, at, radius * 0.5 * (1.0 - k * 0.5), Color(WHITE_HOT, 0.55 * (1.0 - k)))
	if seconds < FLASH * 3.0:
		var k := seconds / (FLASH * 3.0)
		Fx.ring(canvas, at, radius * 1.15 * sqrt(k), 4.0, Color(GOLD, 0.9 * (1.0 - k)))
	_burst(canvas, at, radius, seconds)
	_fountain(canvas, at, seconds)
	_twinkles(canvas, at, radius, progress)


static func _burst(canvas: CanvasItem, at: Vector2, radius: float, seconds: float) -> void:
	var t := seconds / BURST_TIME
	if t >= 1.0:
		return
	var reach := radius * (1.0 - pow(1.0 - t, 3.0))
	for i in BURST_SPARKS:
		var heading := i * TAU / BURST_SPARKS + noise(i, 5) * 0.25
		var far := reach * (0.8 + noise(i, 6) * 0.35)
		var colour := Color(spark_colour(t), 1.0 - t)
		var tip := Fx.polar(at, heading, far)
		Fx.line(canvas, Fx.polar(at, heading, far * 0.7), tip, 4.5, Color(OUTLINE, colour.a * 0.55))
		Fx.line(canvas, Fx.polar(at, heading, far * 0.72), tip, 2.5, colour)
		Fx.dot(canvas, tip, 2.6, colour)


static func _fountain(canvas: CanvasItem, at: Vector2, seconds: float) -> void:
	for i in FOUNTAIN_SPARKS:
		var spark := fountain_spark(i)
		var age: float = seconds - spark[0]
		var life: float = spark[3]
		if age <= 0.0 or age >= life:
			continue
		var t := age / life
		var colour := Color(spark_colour(t), 1.0 - t * t)
		var head := arc_point(at, spark[1], spark[2], age)
		var tail := arc_point(at, spark[1], spark[2], maxf(0.0, age - TRAIL))
		var size := 2.4 if i % 3 else 3.2
		Fx.line(canvas, tail, head, 4.0, Color(OUTLINE, colour.a * 0.45))
		Fx.dot(canvas, head, size + 1.4, Color(OUTLINE, colour.a * 0.6))
		Fx.line(canvas, tail, head, 2.2, Color(colour, colour.a * 0.75))
		Fx.dot(canvas, head, size, colour)


static func _twinkles(canvas: CanvasItem, at: Vector2, radius: float, progress: float) -> void:
	for i in TWINKLES:
		var start := noise(i, 7) * 0.45
		var t := (progress - start) / 0.5
		if t <= 0.0 or t >= 1.0:
			continue
		var heading := noise(i, 8) * TAU
		var point := Fx.polar(at, heading, radius * (0.45 + noise(i, 9) * 0.55)) + Vector2(0.0, -18.0 * t)
		var arm := 3.5 * sin(t * PI)
		var colour := Color(WHITE_HOT, sin(t * PI))
		Fx.dot(canvas, point, 3.0, Color(OUTLINE, colour.a * 0.4))
		Fx.line(canvas, point - Vector2(arm, 0.0), point + Vector2(arm, 0.0), 1.6, colour)
		Fx.line(canvas, point - Vector2(0.0, arm), point + Vector2(0.0, arm), 1.6, colour)
