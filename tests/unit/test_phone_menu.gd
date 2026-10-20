extends GutTest

## The phone's Menu: one grid of every panel, an item shown only while its
## own test passes, and a press that opens the panel and shuts the menu.


func test_a_press_opens_the_panel_and_closes_the_menu():
	var menu: PhoneMenu = add_child_autofree(PhoneMenu.new())
	var opened := [false]
	menu.set_items([["Character", func() -> void: opened[0] = true]])
	menu.open()
	menu.item(0).pressed.emit()
	assert_true(opened[0])
	assert_false(menu.visible)


func test_an_item_shows_only_while_its_test_passes():
	var menu: PhoneMenu = add_child_autofree(PhoneMenu.new())
	var gate := [false]
	menu.set_items([["Options", func() -> void: pass],
		["Companion", func() -> void: pass, func() -> bool: return gate[0]]])
	menu.open()
	assert_true(menu.item(0).visible)
	assert_false(menu.item(1).visible)
	gate[0] = true
	menu.open()
	assert_true(menu.item(1).visible)


func test_a_folded_chip_moves_to_the_column_edge_only_on_a_phone():
	PhoneLayout.on = true
	assert_eq(PhoneLayout.chip_x(246.0, 60.0, true), PhoneLayout.MARGIN)
	assert_eq(PhoneLayout.chip_x(246.0, 60.0, false), 184.0)
	PhoneLayout.on = false
	assert_eq(PhoneLayout.chip_x(246.0, 60.0, true), 184.0)
