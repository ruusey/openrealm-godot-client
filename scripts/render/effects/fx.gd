class_name Fx
extends RefCounted

## The effect drawers by type, and what they share.
##
## Each type is one file with one `draw(canvas, fx, progress, colour,
## elapsed_ms)`, a port of the web client's case for it, registered below
## under its EffectType name (generated from the server's constants).
##
## A drawer is a pure function of its arguments and keeps nothing between
## frames: no member state, no static var, no node. An effect that changes
## over its life -- a throw that lands and becomes a ring, a trap that arms
## then snaps -- switches on `progress` or `elapsed_ms`; one that varies by
## caster or archetype reads `fx` (`tier`, `target`, `radius`, `owner`).
## Randomness comes from rng_for, never randf(). That is what lets a
## scripted render draw the same frame twice and a golden image hold. The web draws in
## screen space at twice world scale, so its pixel constants -- a 5px rim,
## a 2.2px mote -- are halved here (S), while anything derived from the
## effect's radius carries over as it is. Anything without a drawer gets
## FxGeneric, the native client's generic form in the type's own hue.

## The web client's SCALE, inverted: its pixels to our world units.
const S := 0.5


static func for_type(kind: int) -> Callable:
	match kind:
		EffectType.HEAL_RADIUS: return FxHealRadius.draw
		EffectType.VAMPIRISM: return FxVampirism.draw
		EffectType.STASIS_FIELD: return FxStasisField.draw
		EffectType.CHAIN_LIGHTNING: return FxChainLightning.draw
		EffectType.CURSE_RADIUS: return FxCurseRadius.draw
		EffectType.POISON_SPLASH: return FxPoisonSplash.draw
		EffectType.TRAP_THROW: return FxTrapThrow.draw
		EffectType.TRAP_PLACED: return FxTrapPlaced.draw
		EffectType.TRAP_TRIGGER: return FxTrapTrigger.draw
		EffectType.SMOKE_POOF: return FxSmokePoof.draw
		EffectType.WIZARD_BURST: return FxWizardBurst.draw
		EffectType.KNIGHT_SHOCKWAVE: return FxKnightShockwave.draw
		EffectType.WARRIOR_BUFF: return FxWarriorBuff.draw
		EffectType.NINJA_DASH: return FxNinjaDash.draw
		EffectType.PALADIN_SEAL: return FxPaladinSeal.draw
		EffectType.WATER_FOUNTAIN: return FxWaterFountain.draw
		EffectType.SHIELD_DOME: return FxShieldDome.draw
		EffectType.TAUNT_ROAR: return FxTauntRoar.draw
		EffectType.BRACE_STANCE: return FxBraceStance.draw
		EffectType.FROST_NOVA: return FxFrostNova.draw
		EffectType.BLINK_GLYPH: return FxBlinkGlyph.draw
		EffectType.POISON_CLOUD: return FxPoisonCloud.draw
		EffectType.LIFE_DRAIN: return FxLifeDrain.draw
		EffectType.BONE_SPIKES: return FxBoneSpikes.draw
		EffectType.LIGHTNING_STRIKE: return FxLightningStrike.draw
		EffectType.MANA_BOLT: return FxManaBolt.draw
		EffectType.TIME_STOP: return FxTimeStop.draw
		EffectType.BEAST_CLAWS: return FxBeastClaws.draw
		EffectType.SMITE_FLASH: return FxSmiteFlash.draw
		EffectType.DEATH_BLOSSOM: return FxDeathBlossom.draw
		EffectType.INSPIRE_BLOOM: return FxInspireBloom.draw
		EffectType.RECKLESS_SLASH: return FxRecklessSlash.draw
		EffectType.STAR_SHURIKEN: return FxStarShuriken.draw
		EffectType.SNARE_GEAR: return FxSnareGear.draw
		EffectType.COMBUSTION_TRAP: return FxCombustionTrap.draw
		EffectType.WAR_CRY_WAVE: return FxWarCryWave.draw
		EffectType.CALTROPS: return FxCaltrops.draw
		EffectType.ARCANE_AURA: return FxArcaneAura.draw
		EffectType.HASTE_WIND: return FxHasteWind.draw
		EffectType.BANNER_RAISE: return FxBannerRaise.draw
		EffectType.RAMPAGE_AURA: return FxRampageAura.draw
		EffectType.STORM_AURA: return FxStormAura.draw
		EffectType.DEATH_PACT_AURA: return FxDeathPactAura.draw
		EffectType.BLADE_STORM: return FxBladeStorm.draw
		EffectType.SOUL_VORTEX: return FxSoulVortex.draw
		EffectType.BLADE_ORBIT: return FxBladeOrbit.draw
		EffectType.BLADE_BLENDER: return FxBladeBlender.draw
		EffectType.SANCTUARY_DOME: return FxSanctuaryDome.draw
		EffectType.VAMPIRIC_LATCH: return FxVampiricLatch.draw
		EffectType.RAPIER_STAB: return FxRapierStab.draw
		EffectType.LOW_SWING: return FxLowSwing.draw
		EffectType.DISARM_FLOURISH: return FxDisarmFlourish.draw
		EffectType.DIVINE_BEAM: return FxDivineBeam.draw
		EffectType.FORTIFY_AURA: return FxFortifyAura.draw
		EffectType.GROUND_POUND: return FxGroundPound.draw
		EffectType.DRUID_ROOTS: return FxDruidRoots.draw
		EffectType.DRUID_MOONLIGHT: return FxDruidMoonlight.draw
		EffectType.DRUID_WILD_SURGE: return FxDruidWildSurge.draw
		EffectType.MELEE_SWING: return FxMeleeSwing.draw
		EffectType.PURIFY_CIRCLE: return FxPurifyCircle.draw
		EffectType.BEAM_WARNING: return FxBeamWarning.draw
	return Callable()


static func ring(canvas: CanvasItem, at: Vector2, radius: float, width_px: float, colour: Color) -> void:
	if radius > 0.0 and colour.a > 0.001:
		canvas.draw_arc(at, radius, 0.0, TAU, 48, colour, width_px * S)


static func dot(canvas: CanvasItem, at: Vector2, radius_px: float, colour: Color) -> void:
	if colour.a > 0.001:
		canvas.draw_circle(at, radius_px * S, colour)


static func line(canvas: CanvasItem, from: Vector2, to: Vector2, width_px: float, colour: Color) -> void:
	if colour.a > 0.001:
		canvas.draw_line(from, to, colour, width_px * S)


static func polygon(canvas: CanvasItem, points: Array, colour: Color) -> void:
	if colour.a > 0.001 and points.size() >= 3:
		canvas.draw_colored_polygon(PackedVector2Array(points), colour)


## Where a wave that starts `delay` of the way in has got to, 0..1, or -1
## before it starts and after it is gone: the web's staggered ripples.
static func wave(progress: float, delay: float) -> float:
	var t := maxf(0.0, progress - delay) / maxf(0.001, 1.0 - delay)
	return t if t > 0.0 and t < 1.0 else -1.0


static func polar(at: Vector2, angle: float, distance: float) -> Vector2:
	return at + Vector2(cos(angle), sin(angle)) * distance


## The web client rolls Math.random() every frame for its jitter, so a
## bolt shivers. Seeded from the effect and a coarse tick of its age, so
## it shivers here too but a scripted render draws the same shape twice.
static func rng_for(fx: Dictionary, elapsed_ms: int, ticks_per_second := 25) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(fx.get("started", 0)), fx.get("pos", Vector2.ZERO), elapsed_ms * ticks_per_second / 1000])
	return rng
