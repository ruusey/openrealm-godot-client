class_name HowToGuide
extends RefCounted

## The web client's "How to Play" (index.html, #howto-modal), as BBCode for
## the modal's RichTextLabel.
##
## Its words, section by section, with three kinds of change: a key is the
## key this client has for it now -- `{bag}` and the like, filled in from
## the input map, so a rebinding shows here too -- and the Controls section
## is ours (HowToControls); what the web has and this client does not
## (autofire) is left out; and where we differ (the bag opens and shuts)
## the line says what we do.

const TITLE := "How to Play OpenRealm"
const INTRO := "A fast-paced top-down bullet-hell RPG. Survive, grow stronger, and cleanse the realm."
const HEADING := "#ffd96b"

## Section -> body, in the web client's order; "Controls" is built.
const SECTIONS := {
	"The Goal": "Pick a class, dive into the corrupted overworld, and fight your way outward through ever-tougher zones. Kill enemies to earn XP, level up, and collect better gear. Working with others, purge each island of corruption to trigger its climactic boss fight.",
	"Controls": "",
	"Inventory & Items": """[ul]
Open and close your bag with {bag} — 5 equipment slots ([b]weapon, armor, gauntlets, boots, ring[/b]) plus a backpack.
Drag an item onto a slot to equip it, or between slots to rearrange. Drag an item out of the bag to drop it (dropped items are public).
[b]Hot-equip:[/b] [b]double-click[/b] an equippable item to instantly equip it to its slot, or hold {shift} and press a slot number ({one}–{eight}) to equip/use the item in that backpack slot.
Carry up to 6 HP and 6 MP potions. Drink them with {hp} / {mp} (or click the potion slots).
[b]Stat potions[/b] (Life, Mana, Attack, Defense, Speed, Dexterity, Vitality, Wisdom) permanently raise a stat — drink them as soon as you grab them.
Walk over loot and press {pick_up} to grab the nearest bag.
[/ul]""",
	"Abilities": """[ul]
Every class has [b]3 active abilities[/b] (slots 1–3) plus an always-on [b]class passive[/b].
Cast with {a1}/{a2}/{a3}, aimed at your cursor — {right} casts the first. Abilities cost MP and have cooldowns.
Many abilities apply status effects — stun, slow, armor break, bleed, poison — on top of damage.
Ability damage scales with your stats (DEX, STR, WIS…) [i]and[/i] with invested skill points. Hover an ability to see its exact damage, MP cost, cooldown, and effects.
[/ul]""",
	"Ability Skill Points": """[ul]
You earn a [b]skill point every two levels[/b] (per character, up to level 20).
Open your character sheet ({sheet}) and invest points into an ability to [b]increase its damage and effect duration and lower its cooldown[/b].
Each ability has a point cap (ultimates cap lower). Spend points to specialize your build around the abilities you use most.
[/ul]""",
	"Character Skills (Masteries)": """[ul]
Separate from ability skill points, your account has [b]9 permanent masteries[/b] that level up (0–99) just by [i]playing[/i]. They are [b]account-wide[/b] — shared by all your characters and never lost on death. Open them any time with {masteries}.
[b]Combat[/b] — Ranged / Melee / Magic: trained by dealing damage with that weapon type. [b]+0.1% weapon damage[/b] per level.
[b]Armor[/b] — Heavy / Light / Cloak: trained by taking damage while wearing that armor class. [b]+0.1% damage reduction[/b] per level.
[b]DPS Caster[/b] — trained by dealing ability damage. [b]+0.1% ability damage[/b] per level.
[b]Support Caster[/b] — trained by buffing allies with abilities (25 XP per second of buff). [b]+0.15% buff duration[/b] per level.
[b]Impairment Caster[/b] — trained by debuffing enemies with abilities (15 XP per second of debuff). [b]+0.15% debuff duration[/b] per level.
Hover any mastery in the {masteries} menu to see its current level, XP progress, and the exact bonus it grants you right now.
[/ul]""",
	"Loot Progression": """Zones get harder the farther out you go, and gear tiers climb with them:
[ul]
[b]Beach[/b] → tier 0–2 gear
[b]Grasslands[/b] → tier 3–4 gear
[b]Highlands[/b] → tier 5–7 gear
[b]Summit[/b] → untiered legendary gear (Titan weapons, Amulet of Resurrection)
[/ul]
Rings follow the same curve: [b]Superior[/b] rings drop in Beach/Grasslands, [b]Exalted[/b] rings in Highlands/Summit. The bag color tells you what's inside at a glance:
[indent][color=#8a5a2a][font_size=18]■[/font_size][/color] [b]Brown[/b] — HP/MP potions (public)
[color=#4060c0][font_size=18]■[/font_size][/color] [b]Blue[/b] — stat potions
[color=#9050c0][font_size=18]■[/font_size][/color] [b]Purple[/b] — low/mid-tier gear (Beach/Grasslands)
[color=#30c0c0][font_size=18]■[/font_size][/color] [b]Cyan[/b] — high-tier gear & Exalted rings (Highlands/Summit)
[color=#e0e0e0][font_size=18]■[/font_size][/color] [b]White[/b] — untiered legendary items
[color=#c04040][font_size=18]■[/font_size][/color] [b]Red[/b] — a tier-upgraded bonus drop from tougher enemies
[color=#888888][font_size=18]■[/font_size][/color] [b]Grave[/b] — gear a fallen player left behind[/indent]
[b]Soulbound loot:[/b] deal at least 5% of an enemy's health and you earn your own private loot roll — only you can see or grab your soulbound bags. HP/MP potions, items players drop, and graves are public; everything else binds to the player it dropped for.""",
	"Realm Purification": """[ul]
Each overworld island is corrupted and has a [b]purification meter[/b] (shown on screen). Everyone in the realm fills the [i]same[/i] meter — team up.
Fill it by [b]killing enemies, clearing dungeons, and resolving corruption-outbreak events[/b]. Tougher kills and larger packs fill it much faster.
Fully purifying a realm takes roughly 20–30 minutes of coordinated effort.
[/ul]""",
	"The Final Boss Fight": """[ul]
When a realm hits 100% purification, a short countdown begins and [b]everyone in that realm is pulled into a shared boss arena[/b] — a corrupted castle.
Bring potions, a strong build, and invested skill points: defeating the boss yields the realm's best rewards, and difficulty scales with the realm.
[/ul]""",
}


## The whole guide, with this client's keys in it.
static func bbcode() -> String:
	var keys := HowToControls.key_words()
	var out := "[i]%s[/i]\n" % INTRO
	for section in SECTIONS:
		out += "\n[font_size=16][b][color=%s]%s[/color][/b][/font_size]\n" % [HEADING, section]
		out += HowToControls.table() if section == "Controls" else String(SECTIONS[section]).format(keys)
		out += "\n"
	return out
