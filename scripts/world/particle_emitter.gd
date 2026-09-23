class_name ParticleEmitter
extends RefCounted

## What a projectile's fx entries mean in particles: how many, from where,
## how fast, how big, for how long. Both references' numbers, to the digit.

const MAX_TRAIL_PER_FRAME := 4
## The web client's dispersion: spread x 0.02 px/ms at its 2x scale, so 20
## world units a second per unit of spread (the native says 22).
const SPREAD_TO_SPEED := 20.0
## Both references' fallbacks, and their "or" treats a zero as absent too.
const TRAIL_DEFAULTS := {"rate": 24.0, "lifeMs": 500.0, "size": 6.0, "spread": 0.2}
const BURST_DEFAULTS := {"count": 8.0, "lifeMs": 300.0, "size": 5.0, "speed": 50.0}
const TRAIL_TINT := Color(0.067, 0.067, 0.067)


## A trail is emitted from a fractional accumulator kept on the bullet, so
## a slow bullet emits as steadily as a fast one whatever the frame rate,
## and no frame emits more than four. Each particle starts within the
## bullet's size of its centre, drifts outward slowly, and grows.
static func trail(field: ParticleField, centre: Vector2, bullet: Dictionary, fx: Dictionary,
		delta: float) -> void:
	var accumulated: float = float(bullet.get("fx_acc", 0.0)) + number(fx, "rate", TRAIL_DEFAULTS) * delta
	var emitted := int(accumulated)
	bullet["fx_acc"] = accumulated - emitted
	var colour := ProjectileArt.colour(fx.get("color"), TRAIL_TINT)
	var seconds := number(fx, "lifeMs", TRAIL_DEFAULTS) * 0.001
	var base := number(fx, "size", TRAIL_DEFAULTS)
	var dispersion := number(fx, "spread", TRAIL_DEFAULTS) * SPREAD_TO_SPEED
	var rng := field.rng
	for k in mini(emitted, MAX_TRAIL_PER_FRAME):
		var direction := Vector2.from_angle(rng.randf() * TAU)
		var speed := dispersion * (0.4 + rng.randf() * 0.8)
		field.spawn(centre + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * base, direction * speed,
			seconds * (0.75 + rng.randf() * 0.5), base * 0.55, base * 1.5, colour)


## A radial burst from one point: big and bright, shrinking to nothing.
static func burst(field: ParticleField, centre: Vector2, fx: Dictionary) -> void:
	var colour := ProjectileArt.colour(fx.get("color"), Color.WHITE)
	var seconds := number(fx, "lifeMs", BURST_DEFAULTS) * 0.001
	var base := number(fx, "size", BURST_DEFAULTS)
	var speed := number(fx, "speed", BURST_DEFAULTS)
	var rng := field.rng
	for k in int(number(fx, "count", BURST_DEFAULTS)):
		var direction := Vector2.from_angle(rng.randf() * TAU)
		field.spawn(centre, direction * speed * (0.4 + rng.randf() * 0.7),
			seconds * (0.7 + rng.randf() * 0.6), base * 1.3, base * 0.25, colour)


static func number(fx: Dictionary, key: String, defaults: Dictionary) -> float:
	var value: Variant = fx.get(key)
	if value == null or ((value is float or value is int) and is_zero_approx(float(value))):
		return float(defaults[key])
	return float(value)
