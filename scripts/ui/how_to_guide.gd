class_name HowToGuide
extends RefCounted

## "How to Play OpenRealm" — the guide shown by the "?" on the sign-in panel,
## as BBCode for the modal's RichTextLabel. A standalone HTML copy of the same
## content is published at openrealm.net/guide for linking without the client;
## keep the two in rough sync when systems change.
##
## Keys in {curly braces} are filled from the live input map (HowToControls), so
## a rebinding shows here too. Use only the keys in HowToControls.key_words();
## reference menus/tiles by name in prose otherwise. No literal braces in bodies.

const TITLE := "How to Play OpenRealm"
const INTRO := "A fast-paced top-down bullet-hell RPG with a real player-driven economy. Pick a class, grow stronger, cleanse the realm — and, if you choose, earn and cash out $REALM for the loot you find."
const HEADING := "#ffd96b"

## Section -> body, in reading order; "Controls" is built from HowToControls.
const SECTIONS := {
	"The Goal": "Pick a class, dive into the corrupted overworld, and fight your way outward through ever-tougher zones. Kill enemies to earn XP, level up, and collect better gear. Working with others, purge each island of corruption to trigger its climactic boss fight. Everything you loot has value — keep it, or sell it for $REALM.",
	"Controls": "",
	"Classes & Weapons": """[ul]
Each class is built around a [b]weapon archetype[/b] that decides how you deal damage:
[b]Heavy / Melee[/b] — swords, axes, hammers. Short range, high burst, and swings that throw out shockwaves, lightning fans, and other AoE volleys. Trained by the [b]Melee[/b] mastery.
[b]Light / Ranged[/b] — bows and daggers. Fast, mobile, multishot spreads. Trained by the [b]Ranged[/b] mastery.
[b]Magic[/b] — staves, wands, tomes. Spell-like projectiles and the strongest ability kits. Trained by the [b]Magic[/b] mastery.
Your weapon's projectile pattern (shot count, spread, speed, special effects) comes from the weapon itself — try different ones. Some unique weapons fire signature patterns (lightning storms, orbiting rings, summons).
[/ul]""",
	"Inventory & Items": """[ul]
Open and close your bag with {bag} — 5 equipment slots ([b]weapon, armor, gauntlets, boots, ring[/b]) plus a backpack.
Drag an item onto a slot to equip it, or between slots to rearrange. Drag an item out of the bag to drop it (dropped items are public).
[b]Hot-equip:[/b] [b]double-click[/b] an equippable item to equip it to its slot, or hold {shift} and press a slot number ({one}–{eight}) to equip/use the item in that backpack slot.
Carry up to 6 HP and 6 MP potions. Drink them with {hp} / {mp} (or click the potion slots).
[b]Stat potions[/b] (Life, Mana, [b]Strength[/b], Defense, Speed, Dexterity, Vitality, Wisdom) permanently raise a stat — drink them as soon as you grab them. [i]Strength (STR) is your attack power; it scales ranged, melee, and some ability damage.[/i]
Walk over loot and press {pick_up} to grab the nearest bag.
[/ul]""",
	"Abilities": """[ul]
Every class has [b]3 active abilities[/b] (slots 1–3) plus an always-on [b]class passive[/b].
Cast with {a1}/{a2}/{a3}, aimed at your cursor — {right} casts the first. Abilities cost MP and have cooldowns.
Many abilities apply [b]status effects[/b] — stun, slow, armor break, bleed, poison — on top of damage.
Ability damage scales with your stats (DEX, STR, WIS…) [i]and[/i] with invested skill points. Hover an ability to see its exact damage, MP cost, cooldown, and effects.
[/ul]""",
	"Status Effects": """Hits and abilities apply timed effects — watch the icons over health bars:
[ul]
[b]Slowed[/b] — reduced movement. [b]Stunned / Frozen[/b] — can't act or move.
[b]Armor Break (Vulnerable)[/b] — takes extra damage. [b]Bleed / Poison[/b] — damage over time.
Buffs work the same way for you: [b]Berserk[/b] (more damage), [b]Armored[/b] (damage reduction), [b]Lifesteal[/b], [b]Healing[/b], [b]Speedy[/b].
Bosses have their own: an [b]Invincible / Armored[/b] grace during phase changes means wait it out — you can't burn them down mid-transition.
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
[b]Support Caster[/b] — trained by buffing allies with abilities. [b]+0.15% buff duration[/b] per level.
[b]Impairment Caster[/b] — trained by debuffing enemies. [b]+0.15% debuff duration[/b] per level.
Hover any mastery to see its level, XP, and current bonus.
[/ul]""",
	"Rarity, Gems & The Forge": """Gear now has a [b]rarity[/b] and can be upgraded:
[ul]
[b]Rarity[/b] runs Mundane → Common → Uncommon → Rare → Epic → Legendary. Higher rarity means stronger stats, more gem sockets, and (if you sell it) far more $REALM.
[b]Gem sockets[/b] — slot stat-scaling and effect gems (Crit, Vampiric, Frost, Multishot, Thorns, Venom…) into sockets to shape your build. Gems come from the Fame Store and from drops.
[b]The Forge[/b] (a nexus tile) — [b]enchant[/b] an item to add bonus modifiers, or [b]disenchant[/b] to recover materials. Use [b]essence[/b] and [b]crystals[/b] as the crafting inputs.
[b]Advanced enchanting[/b] — a per-pixel picker lets you place a chosen enchant/gem effect onto a specific pixel of the item's icon, so your gear shows what it carries at a glance.
[/ul]
Tooltips spell out rarity, sockets, modifiers, and gem effects — read them before you equip or sell.""",
	"Loot Progression": """Zones get harder the farther out you go, and gear tiers climb with them:
[ul]
[b]Beach[/b] → tier 0–2 gear
[b]Grasslands[/b] → tier 3–4 gear
[b]Highlands[/b] → tier 5–7 gear
[b]Summit / bosses[/b] → untiered legendary gear (signature weapons, Crown of Resurrection)
[/ul]
The bag color tells you what's inside:
[indent][color=#8a5a2a][font_size=18]■[/font_size][/color] [b]Brown[/b] — HP/MP potions (public)
[color=#4060c0][font_size=18]■[/font_size][/color] [b]Blue[/b] — stat potions
[color=#9050c0][font_size=18]■[/font_size][/color] [b]Purple[/b] — low/mid-tier gear
[color=#30c0c0][font_size=18]■[/font_size][/color] [b]Cyan[/b] — high-tier gear & Exalted rings
[color=#e0e0e0][font_size=18]■[/font_size][/color] [b]White[/b] — untiered legendary items
[color=#c04040][font_size=18]■[/font_size][/color] [b]Red[/b] — a tier-upgraded bonus drop from tougher enemies
[color=#888888][font_size=18]■[/font_size][/color] [b]Grave[/b] — gear a fallen player left behind[/indent]
[b]Soulbound loot:[/b] deal at least 5% of an enemy's health and you earn your own private loot roll — only you can see or grab your soulbound bags. Potions, dropped items, and graves are public; everything else binds to you.""",
	"Dungeons, Portals & Difficulty": """[ul]
Overworld islands are linked in a graph; [b]portals[/b] drop you into [b]dungeons[/b] — self-contained instances built from prefab rooms, each ending in a boss.
A portal carries a [b]difficulty[/b] and sometimes a [b]tier[/b] with rolled [b]Realm Modifiers[/b] — buffs/twists that raise the challenge and the rewards. Check the portal card before you enter.
Dungeon bosses drop the best loot and guard the exit — beat the boss to claim it and leave via its return portal.
[/ul]""",
	"Enemy Hordes": "Some zones spawn [b]hordes[/b] — a commander leading a pack of followers that move and fight as a group. They hit harder together but fill the purification meter fast when you break them.",
	"Realm Purification": """[ul]
Each overworld island is corrupted and has a [b]purification meter[/b] (shown on screen). Everyone in the realm fills the [i]same[/i] meter — team up.
Fill it by [b]killing enemies, clearing dungeons, and resolving corruption-outbreak events[/b]. Tougher kills and larger packs fill it much faster.
Fully purifying a realm takes roughly 20–30 minutes of coordinated effort.
[/ul]""",
	"The Final Boss Fight": """[ul]
When a realm hits 100% purification, a short countdown begins and [b]everyone in that realm is pulled into a shared boss arena[/b] — a corrupted castle.
Bring potions, a strong build, and invested skill points: defeating the boss yields the realm's best rewards, and difficulty scales with the realm.
[/ul]""",
	"Quests & Stars": "Take on [b]quests[/b] for goals that span a character or your whole account; completing them for the first time awards [b]stars[/b]. Your star total shows under your name and on the public scoreboard — a quick read of how far someone has come.",
	"Fame & the Fame Store": """[ul]
[b]Fame[/b] is a soft currency. You bank it when a character dies (based on its XP), and you can top it up by buying it with crypto via the [b]Add Fame[/b] button (SOL or $REALM, web build).
Spend fame at the [b]Fame Store[/b] (a nexus tile): cosmetic [b]dyes[/b], [b]stat crystals[/b], [b]gems[/b], and the [b]Crown of Resurrection[/b].
Fame is separate from the $REALM economy — the two don't convert into each other at a profit.
[/ul]""",
	"The Exchange Market": """A nexus tile opens the Exchange, with two tabs:
[ul]
[b]Item Swap[/b] — trade consumables of the same kind (shards, crystals, essence, stat potions). You hand in N and get back N−1; the market keeps one as tax.
[b]Item Exchange[/b] — [b]sell backpack items for $REALM[/b]. Each item shows its $REALM value; click Sell to bank it. Gear, gems, rings, and uniques pay out; consumables don't. Rarer and higher-tier items are worth far more — a signature weapon or a Crown is a jackpot.
[/ul]""",
	"Membership & The $REALM Economy": """OpenRealm has a real, one-token economy built on [b]$REALM[/b] (a Solana token). It's optional — you can play and progress entirely for free — but if you want to earn:
[ul]
[b]Link a wallet[/b] — open the [b]Economy[/b] menu (web build) and connect your Phantom wallet. You sign a one-time challenge to prove ownership; the game never holds your keys.
[b]Membership[/b] — a weekly pass costs [b]$REALM[/b], paid from your wallet. It unlocks [b]cashing out[/b] (you can earn points without it, but you need an active membership to withdraw).
[b]Earn[/b] — sell items in the [b]Item Exchange[/b] to bank $REALM.
[b]Cash out[/b] — with an active membership and a linked wallet, request a payout from the Economy menu. Your $REALM is sent straight to your wallet.
[/ul]
It's a gamble on your own play: a strong week — or a lucky jackpot drop — can out-earn your membership, while a quiet week won't. Play fair; everything is verified on-chain and server-side.""",
	"Graphics & Options": """Open [b]Options[/b] (gear/menu) to tune your experience:
[ul]
[b]Graphics[/b] — toggle dynamic lighting and quality settings for smoother play on weaker machines.
[b]View[/b] — the world renders in classic top-down 2D; an experimental 3D view is available too.
[b]UI scale[/b] — scales the HUD and menus (defaults larger on mobile for touch).
[b]Controls[/b] — rebind any key; the rebinds show up live in this guide's Controls section.
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
