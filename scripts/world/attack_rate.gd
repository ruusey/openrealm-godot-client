class_name AttackRate
extends RefCounted

## How fast the server will let you shoot.
##
## The client has to agree with this or it lies to the player: fire faster and
## the shots are dropped server-side *after* the local bullet has already been
## spawned and drawn, fire slower and the weapon under-performs its own stats.
## The placeholder this replaces was a flat quarter-second, which is both at
## once -- too fast at low DEX, too slow at high.
##
## The arithmetic is the server's, and the two references disagree with it in
## two places, so neither is followed blindly:
##
##   * the truncation happens ONCE, before the archetype multiplier. The web
##     client floors again afterwards, which makes a hammer fire at 1010ms
##     where the server demands more than 1090.
##   * BERSERK beats DAZED. The server's branch is an else-if; the web client
##     tests them independently with DAZED last, so DAZED wins there.

const BASE := 6.5
const DEX_OFFSET := 17.3
const DEX_DIVISOR := 75.0
## BERSERK is +50% fire rate. SPEEDY is movement only -- both references say
## so, having once had it here.
const BERSERK_MULTIPLIER := 1.5
## DAZED pins you to one shot a second whatever your stats say.
const DAZED_SHOTS := 1.0
## A margin over the interval itself, which both references add for the same
## reason: the server checks an absolute clock, and arriving exactly on the
## boundary loses the race. Its own gate is looser still (SHOT_RATE_TOLERANCE
## 0.6), but that slack is for jitter, not for us to spend.
const MARGIN_MS := 10.0
## What the web client assumes when stats have not arrived yet.
const DEFAULT_DEX := 10

## Effect ids, named where StatusTint names them.
const STUNNED := 3
const DAZED := 11
const BERSERK := 19


## Shots per second the server will accept.
static func per_second(dex: int, attack_speed_mul: float, effects: Array) -> float:
	var shots := float(int((BASE * (dex + DEX_OFFSET)) / DEX_DIVISOR))
	if attack_speed_mul > 0.0:
		shots *= attack_speed_mul
	if effects.has(BERSERK):
		shots *= BERSERK_MULTIPLIER
	elif effects.has(DAZED):
		shots = DAZED_SHOTS
	return maxf(shots, 0.001)


## Seconds to wait between shots.
static func interval(dex: int, attack_speed_mul: float, effects: Array) -> float:
	return (1000.0 / per_second(dex, attack_speed_mul, effects) + MARGIN_MS) / 1000.0


## Stunned, you cannot shoot at all -- and the server does not even refresh
## your last-shot time, so nothing is banked while it lasts.
static func blocked(effects: Array) -> bool:
	return effects.has(STUNNED)
