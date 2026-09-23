class_name ProjectileSpeed
extends RefCounted

## The SPEED_DECAY / SPEED_RAMP curve, mirroring Bullet.speedCurveMult.
##
## Both flags scale magnitude by an exponential over the projectile's
## lifetime: DECAY eases magnitude -> 0 so the shot stalls at the end of its
## life, RAMP eases 0 -> magnitude so it accelerates away. `frequency` doubles
## as the curve sharpness k, which is why a speed-curved bullet is never also
## parametric.
##
## This is wall-clock driven, not step-accumulated, so it stays correct
## regardless of frame rate -- and has to match the server exactly or the
## bullet drifts from where the server says it is.

## The server's fallback when a projectile carries no explicit lifetime.
const DEFAULT_LIFETIME_TICKS := 192
const DEFAULT_SHARPNESS := 4.0


static func multiplier(bullet: Dictionary, now_ms: int) -> float:
	if not ProjectileKind.has_speed_curve(bullet):
		return 1.0

	var ticks: float = float(bullet.get("lifetime_ticks", 0))
	if ticks <= 0.0:
		ticks = DEFAULT_LIFETIME_TICKS
	var life_ms := ticks * 1000.0 / GameConstants.TICK_RATE
	var progress := clampf((now_ms - int(bullet.get("created_ms", now_ms))) / life_ms, 0.0, 1.0)

	var sharpness: float = float(bullet.get("frequency", 0))
	if sharpness <= 0.0:
		sharpness = DEFAULT_SHARPNESS

	if ProjectileKind.has_flag(bullet, ProjectileKind.SPEED_RAMP):
		return (exp(sharpness * progress) - 1.0) / (exp(sharpness) - 1.0)
	return (exp(-sharpness * progress) - exp(-sharpness)) / (1.0 - exp(-sharpness))
