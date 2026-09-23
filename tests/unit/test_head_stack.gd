extends GutTest

## The bubble over a head is the right size on the frame it appears.
##
## A wrapping Label's minimum height is measured at whatever width it has
## at that moment. A bubble whose label was 12px wide from the last line
## wrapped a new line at 12px -- one word a row, 1087px tall for a line
## at the 180px wrap -- and was drawn that tall, its top a screen up, for
## the frame before the container laid it out. That is the flash of a tall
## white box over a speaker's head on every new line.

const LONG := "a much longer line of chat that has to wrap at one hundred and eighty pixels wide"

var stack: HeadStack


func before_each():
	stack = HeadStack.new()
	add_child_autofree(stack)


func _say(text: String) -> void:
	stack.show_stack([], [], {"message": text, "alpha": 1.0})


func _settled(text: String) -> Vector2:
	# The size the container arrives at once it has laid the label out.
	_say(text)
	await get_tree().process_frame
	_say(text)
	return stack._bubble.size


func test_a_short_line_is_one_row_tall_on_the_frame_it_appears():
	_say("hi")
	var first: Vector2 = stack._bubble.size
	var settled: Vector2 = await _settled("hi")
	assert_eq(first, settled, "no taller on its first frame than once laid out")
	assert_eq(settled.y, 27.0, "one 12px row (17) in a box padded 5 top and bottom")


func test_a_long_line_wraps_at_180_on_the_frame_it_appears():
	_say("hi")
	await get_tree().process_frame
	_say(LONG)
	var first: Vector2 = stack._bubble.size
	assert_lt(stack._bubble.position.y, 0.0, "over the head")
	var settled: Vector2 = await _settled(LONG)
	assert_eq(first, settled, "wrapped at 180 at once, not at the last line's width")
	assert_eq(settled.x, 196.0, "180 plus 8 of padding a side")
	assert_lt(settled.y, 100.0, "a few rows, not a word a row")


func test_a_short_line_after_a_long_one_is_narrow_and_one_row_at_once():
	await _settled(LONG)
	_say("short again")
	assert_eq(stack._bubble.size, await _settled("short again"))
	assert_eq(stack._bubble_text.size.x, stack._bubble_text.custom_minimum_size.x,
		"the label is as wide as its line, not as wide as the last one")
