class_name ProjectileKind
extends RefCounted

## Projectile flags and the motion-type predicates derived from them.
##
## Flag ids are the server's ProjectileFlag enum. Orbital and parametric
## motion are selected the way the working web client does it -- by the
## presence of the parameters, not only the flag -- because content sets
## amplitude/frequency on projectiles that omit the flag.

const PLAYER_PROJECTILE := 10
## A player-owned ally's bullet (a Codex summon): server-authoritative, but it carries
## the owner's id for kill credit, so this flag is what tells the client it is NOT a local
## prediction to claim/cull. Must match ProjectileFlag.ALLY_PROJECTILE on the server.
const ALLY_PROJECTILE := 11
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

## Everything the per-frame loops ask of a bullet, derived once from its flags and
## motion parameters (neither changes in flight) and cached on it as "traits".
const TRAIT_ORBITAL := 1
const TRAIT_PARAMETRIC := 2
const TRAIT_SPINS := 4
const TRAIT_SPEED_CURVE := 8
const TRAIT_HOMING := 16
const TRAIT_ANCHORED := 32
const TRAIT_LINE_SEGMENT := 64
const TRAIT_STOPS_AT_WALLS := 128
const TRAIT_PIERCES := 256
const TRAIT_MELEE_SWING := 512
const TRAIT_ALLY := 1024
const TRAIT_PLAYER_SHOT := 2048
const TRAIT_PREDICTED := 4096
## Set by ProjectileSystem, which knows who the local player is.
const TRAIT_OWNER_RESOLVED := 8192
const TRAIT_OWN := 16384
const TRAIT_CONSUMED := 32768


## Flags are packed into an int bitmask at construction (flag_bits), so every
## motion/ownership predicate is a bit test rather than a linear Array scan --
## this runs ~15-20 times per bullet per frame. Falls back to the flags Array
## for the construction-time temp dicts that are built before flag_bits exists.
static func has_flag(bullet: Dictionary, flag: int) -> bool:
	if bullet.has("flag_bits"):
		return (int(bullet["flag_bits"]) & (1 << flag)) != 0
	return flag in bullet.get("flags", [])


static func traits(bullet: Dictionary) -> int:
	var cached: int = bullet.get("traits", -1)
	if cached >= 0:
		return cached
	var bits := 0
	if is_orbital(bullet):
		bits |= TRAIT_ORBITAL
	elif is_parametric(bullet):
		bits |= TRAIT_PARAMETRIC
	if spins(bullet):
		bits |= TRAIT_SPINS
	if has_speed_curve(bullet):
		bits |= TRAIT_SPEED_CURVE
	if is_homing(bullet):
		bits |= TRAIT_HOMING
	if is_anchored(bullet):
		bits |= TRAIT_ANCHORED
	if has_flag(bullet, LINE_SEGMENT):
		bits |= TRAIT_LINE_SEGMENT
	if not has_flag(bullet, PASS_THROUGH_TERRAIN):
		bits |= TRAIT_STOPS_AT_WALLS
	if has_flag(bullet, PASS_THROUGH_ENEMIES):
		bits |= TRAIT_PIERCES
	if has_flag(bullet, MELEE_SWING):
		bits |= TRAIT_MELEE_SWING
	if has_flag(bullet, ALLY_PROJECTILE):
		bits |= TRAIT_ALLY
	if is_player_shot(bullet):
		bits |= TRAIT_PLAYER_SHOT
	if bool(bullet.get("predicted", false)):
		bits |= TRAIT_PREDICTED
	bullet["traits"] = bits
	return bits


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
