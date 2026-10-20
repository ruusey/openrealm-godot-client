extends GutTest

## The home screen's signed-in line: who is signed in, Sign out, and Buy
## Fame while the data service is selling fame.


func _buttons(row: SignedInRow) -> Array:
	return row.get_children().filter(func(child: Node) -> bool: return child is Button)


func test_buy_fame_hidden_until_on_sale():
	var opened := [0]
	var row: SignedInRow = autofree(SignedInRow.new(func() -> void: pass, func() -> void: opened[0] += 1))
	var buy: Button = _buttons(row)[0]
	assert_eq(buy.text, "Buy Fame")
	assert_false(buy.visible)
	row.show_buy_fame(true)
	assert_true(buy.visible)
	buy.pressed.emit()
	assert_eq(opened[0], 1)
	row.show_buy_fame(false)
	assert_false(buy.visible)


func test_no_buy_fame_without_a_handler():
	var row: SignedInRow = autofree(SignedInRow.new(func() -> void: pass))
	row.show_buy_fame(true)
	assert_eq(_buttons(row).map(func(button: Button) -> String: return button.text), ["Sign out"])
