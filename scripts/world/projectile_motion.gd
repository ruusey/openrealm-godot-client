class_name ProjectileMotion
extends RefCounted

## The deterministic integrator -- the bandwidth trick the protocol is built on.
##
## Bullet positions are never streamed. NetBullet carries the full spawn
## parameter set once and both sides then run this same integration, so a
## bullet costs one packet instead of one packet per tick. That only holds if
## this matches com.openrealm.game.entity.Bullet exactly.
##
## Every step scales by `bullet_scale = dt * 64`, normalising motion to the
## server's fixed 64Hz tick regardless of client frame rate.

const TICK_RATE := 64.0
## Legacy wall-clock ceiling: no bullet outlives 10 seconds.
const MAX_LIFETIME_MS := 10_000
## Cap on how far a freshly received bullet is fast-forwarded to cover latency.
const MAX_CATCHUP_SECONDS := 0.25


static func step(bullet: Dictionary, bullet_scale: float, now_ms := -1) -> void:
	if ProjectileKind.is_orbital(bullet):
		_orbital(bullet, bullet_scale)
	elif ProjectileKind.is_parametric(bullet):
		_parametric(bullet, bullet_scale)
	else:
		# A LINE_SEGMENT wall with a frequency sweeps around its anchor: the
		# facing angle advances first, then it moves along the new heading.
		if ProjectileKind.spins(bullet):
			bullet["angle"] += deg_to_rad(bullet["frequency"] * bullet_scale)
		straight(bullet, bullet_scale, now_ms)


static func straight(bullet: Dictionary, bullet_scale: float, now_ms := -1) -> void:
	var speed: float = bullet["magnitude"]
	if ProjectileKind.has_speed_curve(bullet):
		speed *= ProjectileSpeed.multiplier(bullet,
			now_ms if now_ms >= 0 else Time.get_ticks_msec())
	var step_size: float = speed * bullet_scale
	bullet["pos"] += ProjectileAngle.direction(bullet["angle"]) * step_size
	# |(sin, cos)| == 1, so distance travelled is exactly the step size.
	bullet["traveled"] += absf(step_size)


## Straight travel plus a sinusoidal offset perpendicular to it. The wave is a
## position offset, so each tick applies the *change* in offset, not a velocity.
static func _parametric(bullet: Dictionary, bullet_scale: float) -> void:
	var amplitude: float = bullet["amplitude"]
	var previous: float = amplitude * sin(deg_to_rad(bullet["time_step"]))
	bullet["time_step"] = fmod(bullet["time_step"] + bullet["frequency"] * bullet_scale, 360.0)
	var current: float = amplitude * sin(deg_to_rad(bullet["time_step"]))
	var offset_delta := (current - previous) * (-1.0 if bullet["invert"] else 1.0)

	var angle: float = bullet["angle"]
	var forward: Vector2 = ProjectileAngle.direction(angle) * bullet["magnitude"] * bullet_scale
	bullet["pos"] += forward + ProjectileAngle.perpendicular(angle) * offset_delta
	# Range is spent on forward motion only, never on the oscillation.
	bullet["traveled"] += bullet["magnitude"] * bullet_scale


static func _orbital(bullet: Dictionary, bullet_scale: float) -> void:
	var delta := deg_to_rad(bullet["frequency"] * bullet_scale)
	bullet["orbit_phase"] += delta
	bullet["pos"] = bullet["orbit_centre"] + Vector2(
		cos(bullet["orbit_phase"]), sin(bullet["orbit_phase"])) * bullet["orbit_radius"]
	# Range is spent as arc length.
	bullet["traveled"] += bullet["orbit_radius"] * absf(delta)


static func is_expired(bullet: Dictionary, now_ms: int) -> bool:
	if bullet["traveled"] > bullet["range"]:
		return true
	return (now_ms - int(bullet["created_ms"])) > MAX_LIFETIME_MS


## Advances a newly received bullet to roughly where the server has it by now.
## Only plain straight bullets can be fast-forwarded: orbital, parametric and
## spinning motion depend on accumulated phase, homing on a target position and
## speed curves on elapsed lifetime, so guessing puts any of them out of step.
static func catch_up(bullet: Dictionary, one_way_latency_ms: float) -> void:
	if bullet["magnitude"] <= 0.0 or ProjectileKind.is_orbital(bullet) \
			or ProjectileKind.is_parametric(bullet) or ProjectileKind.spins(bullet) \
			or ProjectileKind.is_homing(bullet) or ProjectileKind.has_speed_curve(bullet):
		return
	var scale := minf(one_way_latency_ms / 1000.0, MAX_CATCHUP_SECONDS) * TICK_RATE
	if scale <= 0.5:
		return
	straight(bullet, scale)
	bullet["created_ms"] = int(bullet["created_ms"]) - int(one_way_latency_ms)
