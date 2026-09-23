extends GutTest

## What a player just said, over their head.

var now := 10_000
var bubbles: ChatBubbles


func before_each():
	now = 10_000
	bubbles = ChatBubbles.new(func() -> int: return now)


func _said(from: String, message: String) -> void:
	bubbles.apply_text({"from": from, "to": "", "message": message})


func test_a_line_floats_over_its_sender_and_the_next_replaces_it():
	_said("Ruu", "hi")
	assert_eq(bubbles.over("Ruu"), {"message": "hi", "alpha": 1.0})
	assert_eq(bubbles.over("Mingau"), {}, "nobody else said anything")
	_said("Ruu", "again")
	assert_eq(bubbles.over("Ruu")["message"], "again")


func test_the_server_and_the_minimap_say_nothing_over_a_head():
	_said("SYSTEM", "Welcome")
	_said("EVENT_MARKER", "ADD|1|2|3|4|boss")
	_said("", "anon")
	_said("Ruu", "")
	assert_eq(bubbles.over("SYSTEM"), {})
	assert_eq(bubbles.over("EVENT_MARKER"), {})
	assert_eq(bubbles.over(""), {})
	assert_eq(bubbles.over("Ruu"), {})


func test_a_long_line_is_clipped_because_the_log_has_the_rest():
	var long := "x".repeat(100)
	_said("Ruu", long)
	var shown: String = bubbles.over("Ruu")["message"]
	assert_eq(shown.length(), 82, "79 characters and an ellipsis, as both references clip")
	assert_true(shown.ends_with("..."))
	_said("Ruu", "x".repeat(80))
	assert_eq(bubbles.over("Ruu")["message"].length(), 80, "exactly eighty is not clipped")


func test_life_is_the_references_formula_and_the_end_fades():
	# 3500 + 40 a character, capped at 2500 extra: "hello" lives 3700ms.
	_said("Ruu", "hello")
	now += 3199
	assert_eq(bubbles.over("Ruu")["alpha"], 1.0, "not yet fading")
	now += 251
	assert_almost_eq(bubbles.over("Ruu")["alpha"], 0.5, 0.001, "halfway through the last 500ms")
	now += 250
	assert_eq(bubbles.over("Ruu"), {}, "gone at 3700ms")
	assert_eq(bubbles.over("Ruu"), {}, "and stays gone")
	_said("Ruu", "x".repeat(80))
	now += 5999
	assert_ne(bubbles.over("Ruu"), {}, "a long line lives six seconds")
	now += 1
	assert_eq(bubbles.over("Ruu"), {})


func test_the_realm_raises_them_off_the_chat_packet_and_drops_them_with_the_world():
	var state := RealmState.new(null, func() -> int: return now)
	state.apply_packet("TextPacket", {"from": "Ruu", "to": "", "message": "hi"})
	assert_eq(state.bubbles.over("Ruu")["message"], "hi")
	assert_eq(state.chat.lines.size(), 1, "and the log still has it")
	state.reset_world()
	assert_eq(state.bubbles.over("Ruu"), {})
	bubbles.apply_text({"from": "Ruu", "message": "x"})
	bubbles.clear()
	assert_eq(bubbles.over("Ruu"), {})


func test_the_dress_is_the_web_clients():
	assert_eq(HeadStack.BUBBLE_WRAP, 180.0, "wrapped at 180")
	assert_eq(HeadStack.CHIP_SIZE, Vector2(40.0, 14.0))
	var box := TagStyles.bubble_box()
	assert_eq(box.bg_color, Color(1.0, 1.0, 1.0, 0.95))
	assert_eq(box.border_color, Color("c8c0b0"))
	assert_eq(box.corner_radius_top_left, 10)
	assert_eq(Vector2(box.content_margin_left, box.content_margin_top), Vector2(8.0, 5.0), "8 by 5 of padding")
	assert_eq(TagStyles.bubble_label().font_size, 12)
	assert_eq(ChatBubbles.MAX_CHARS, 80)
	assert_eq(ChatBubbles.FADE_MS, 500)
