class_name ProjectileKind
extends RefCounted

## Projectile flags and the motion-type predicates derived from them.
##
## Flag ids are the server's ProjectileFlag enum. Orbital and parametric
## motion are selected the way the working web client does it -- by the
## presence of the parameters, not only the flag -- because content sets
## amplitude/frequency on projectiles that omit the flag.

const PLAYER_PROJECTILE := 10
const PARAMETRIC := 12
const INVERTED_PARAMETRIC := 13
const ORBITAL := 20
const ARMOR_PIERCING := 23
const PASS_THROUGH_TERRAIN := 24
const PASS_THROUGH_ENEMIES := 25
## v0.9.0 added these. LINE_SEGMENT and ANCHORED are the common ones -- 101
## and 56 projectiles in the shipped content -- so leaving them unmodelled
## visibly desyncs a realm rather than being an edge case.
const LINE_SEGMENT := 30
const ANCHORED := 31
const SPEED_DECAY := 32
const SPEED_RAMP := 33
const HOMING := 34
const MELEE_SWING := 40
const CRITICAL := 50


static func has_flag(bullet: Dictionary, flag: int) -> bool:
	return flag in bullet.get("flags", [])


static func is_orbital(bullet: Dictionary) -> bool:
	return has_flag(bullet, ORBITAL)


static func is_parametric(bullet: Dictionary) -> bool:
	if is_orbital(bullet):
		return false
	if has_flag(bullet, PARAMETRIC) or has_flag(bullet, INVERTED_PARAMETRIC):
		return true
	# The flag is not required: 16 projectiles in the shipped content set
	# amplitude and frequency without it, and the web client waves those too.
	return float(bullet.get("amplitude", 0)) != 0.0 and float(bullet.get("frequency", 0)) != 0.0


## A LINE_SEGMENT wall given a frequency sweeps around its anchor instead of
## travelling, so its angle advances every tick.
static func spins(bullet: Dictionary) -> bool:
	return has_flag(bullet, LINE_SEGMENT) and float(bullet.get("frequency", 0)) != 0.0


static func is_anchored(bullet: Dictionary) -> bool:
	return has_flag(bullet, ANCHORED)


static func is_homing(bullet: Dictionary) -> bool:
	return has_flag(bullet, HOMING)


static func has_speed_curve(bullet: Dictionary) -> bool:
	return has_flag(bullet, SPEED_DECAY) or has_flag(bullet, SPEED_RAMP)


static func is_player_shot(bullet: Dictionary) -> bool:
	return has_flag(bullet, PLAYER_PROJECTILE)
