class_name StatusTint
extends RefCounted

## The colour a status effect washes over the character carrying it.
##
## The two references disagree on how rich this should be: the native client
## runs full colour matrices through a shader, mixing channels; the web client
## multiplies the sprite by a single colour. A multiply is exactly what a
## per-command `modulate` does, so this follows the web client -- and it needs
## no material, which means the entity layer stays one batched canvas item.
##
## Only one effect shows at a time. The order below is the order the web
## client tests them in, and its else-if chain makes the first match win, so
## a poisoned-and-invincible player reads as invincible.
##
## Ids are the server's StatusEffectType. Effects reach us only through
## PlayerStatePacket, which is keyed by player id -- NetEnemy carries none in
## v0.9.0, so enemy tints are wired but cannot fire until the server sends
## them.

const CLEAR := Color.WHITE

const INVINCIBLE := 6
const ARMOR_BROKEN := 22
const PARALYZED := 2
const STUNNED := 3
const STASIS := 15
const INVISIBLE := 0
const BERSERK := 19
const DAMAGING := 14
const ARMORED := 18
const HEALING := 1
const SPEEDY := 4
const DAZED := 11
const CURSED := 16
const POISONED := 17

## [effect id, tint], most significant first.
const PRIORITY := [
	[INVINCIBLE, Color(1.0, 1.0, 0.8)],
	[ARMOR_BROKEN, Color(0.44, 0.38, 0.8)],
	[PARALYZED, Color(0.53, 0.53, 0.53)],
	[STUNNED, Color(0.53, 0.67, 0.8)],
	[STASIS, Color(0.2, 0.2, 0.22)],
	[INVISIBLE, Color(0.8, 0.73, 0.53)],
	[BERSERK, Color(1.0, 0.4, 0.27)],
	[DAMAGING, Color(1.0, 0.67, 0.4)],
	[ARMORED, Color(0.53, 0.6, 0.8)],
	[HEALING, Color(1.0, 0.53, 0.53)],
	[SPEEDY, Color(0.73, 1.0, 0.53)],
	[DAZED, Color(0.6, 0.53, 0.67)],
	[CURSED, Color(0.6, 0.13, 0.33)],
	[POISONED, Color(0.25, 0.8, 0.25)],
]


static func of(effects: Array) -> Color:
	if effects.is_empty():
		return CLEAR
	for entry in PRIORITY:
		if int(entry[0]) in effects:
			return entry[1]
	return CLEAR
