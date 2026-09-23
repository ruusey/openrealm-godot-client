extends GutTest

## What is written under a portal, and the card the one you stand on becomes.


func test_the_badge_is_the_tier_or_else_the_difficulty():
	assert_eq(PortalCard.badge({"tier": 2, "difficulty": 3.5}), "T2", "a tiered realm shows its tier")
	assert_eq(PortalCard.badge({"tier": 1, "difficulty": 3.5}), "D3.5", "tier one is not a tier")
	assert_eq(PortalCard.badge({"tier": 0, "difficulty": 3.0}), "D3", "a whole number, whole")
	assert_eq(PortalCard.badge({"tier": 0, "difficulty": 0.0}), "")


func test_the_caption_is_the_label_and_the_badge():
	assert_eq(PortalCard.caption({"label": "Grasslands", "tier": 2}), "Grasslands  -  T2")
	assert_eq(PortalCard.caption({"label": "Grasslands", "tier": 0, "difficulty": 1.5}), "Grasslands  -  D1.5")
	assert_eq(PortalCard.caption({"label": "Grasslands", "tier": 0}), "Grasslands")
	assert_eq(PortalCard.caption({"label": "", "tier": 3}), "", "no realm behind it, no caption")


func test_the_card_lists_every_fact_the_wire_carries():
	var card := PortalCard.card({"label": "Grasslands", "tier": 2, "difficulty": 3.5,
		"player_count": 4, "purified": 43, "goal": 100, "modifiers": "Frenzy, Fog"})
	assert_eq(Array(card.split("\n")), ["Grasslands   [T2]", "Difficulty 3.5  -  4 in realm", "Purified 43%", "[Frenzy] [Fog]"])


func test_the_card_says_when_there_is_less_to_say():
	assert_eq(Array(PortalCard.card({"label": "Nexus", "tier": 0}).split("\n")), ["Nexus", "0 in realm"],
		"no difficulty, no goal, no modifiers, nothing tiered")
	assert_eq(Array(PortalCard.card({"label": "Deep", "tier": 3}).split("\n")), ["Deep   [T3]", "0 in realm", "Modifiers revealed on entry"],
		"a tiered realm that has not rolled its modifiers yet")
	assert_eq(PortalCard.card({"label": "", "tier": 3}), "")
	assert_eq(PortalCard.card({"label": "X", "purified": 150, "goal": 100}).split("\n")[2], "Purified 100%", "clamped")


func test_standing_on_or_beside_the_portal_focuses_it():
	var portal := Vector2(64, 64)
	var centre := Vector2(80, 80)
	assert_true(PortalCard.focused(portal, centre), "on it")
	assert_true(PortalCard.focused(portal, centre + Vector2(41, 0)), "1.3 tiles: beside it")
	assert_false(PortalCard.focused(portal, centre + Vector2(42, 0)), "just past")


func test_a_tiered_realm_reads_warm_and_a_plain_one_green():
	assert_eq(PortalCard.colour({"tier": 2}), PortalCard.TIERED)
	assert_eq(PortalCard.colour({"tier": 1}), PortalCard.PLAIN)
	var box := PortalCard.box()
	assert_almost_eq(box.bg_color.a, 0.82, 0.001)
	assert_eq(box.corner_radius_top_left, 6)
	assert_eq(box.content_margin_left, 7.0)
