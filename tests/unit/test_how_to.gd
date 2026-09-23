extends GutTest

## The how-to: the "?" on the sign-in panel opens the web client's guide,
## with this client's keys in it, and it goes away as the web's does.

var screen: LoginScreen
var how_to: HowToPanel


func before_each():
	screen = LoginScreen.new()
	add_child_autofree(screen)
	how_to = screen._how_to


func after_each():
	KeyBindings.apply({})


func test_shut_until_the_question_mark_is_pressed():
	assert_false(how_to.visible)
	assert_eq(how_to.body.text, "", "nothing written while shut")
	screen._how_to_button.pressed.emit()
	assert_true(how_to.visible)


func test_every_section_of_the_web_guide_is_there():
	how_to.open()
	var text := how_to.body.get_parsed_text()
	assert_string_contains(text, HowToGuide.INTRO)
	for section in ["The Goal", "Controls", "Inventory & Items", "Abilities", "Ability Skill Points",
			"Character Skills (Masteries)", "Loot Progression", "Realm Purification", "The Final Boss Fight"]:
		assert_string_contains(text, section)
	assert_string_contains(text, "Soulbound loot")
	assert_string_contains(text, "Hold  Left Mouse ")
	assert_false("[" in text, "every tag parsed: %s" % text.substr(text.find("["), 40))
	assert_false("{" in text, "every key filled in")
	assert_false("utofire" in text, "the web's autofire is not ours")


func test_the_keys_are_the_keys_bound_now():
	how_to.open()
	var text := how_to.body.get_parsed_text()
	assert_string_contains(text, "Drink them with  Z  /  X ", "the project's own keys")
	assert_string_contains(text, "Open and close your bag with  Tab ")
	KeyBindings.rebind("drink_hp", KEY_Q)
	KeyBindings.rebind("toggle_masteries", KEY_P)
	how_to.close()
	how_to.open()
	text = how_to.body.get_parsed_text()
	assert_string_contains(text, "Drink them with  Q  /  X ", "written again on opening")
	assert_string_contains(text, "Open them any time with  P ")
	var row: Array = HowToControls.rows().filter(func(r: Array) -> bool: return r[0] == "Drink HP potion")[0]
	assert_string_contains(row[1], " Q ")


func test_the_close_button_escape_and_the_dim_put_it_away():
	how_to.open()
	how_to.close_button.pressed.emit()
	assert_false(how_to.visible)

	how_to.open()
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	how_to._unhandled_key_input(key)
	assert_true(how_to.visible, "any other key leaves it")
	key.keycode = KEY_ESCAPE
	how_to._unhandled_key_input(key)
	assert_false(how_to.visible)

	how_to.open()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	how_to._dim.gui_input.emit(click)
	assert_true(how_to.visible, "a release is not a click")
	click.pressed = true
	how_to._dim.gui_input.emit(click)
	assert_false(how_to.visible)


func test_escape_while_shut_is_left_for_the_game():
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	how_to._unhandled_key_input(key)
	assert_false(how_to.visible, "it does not open on Escape")


func test_toggle():
	how_to.toggle()
	assert_true(how_to.visible)
	how_to.toggle()
	assert_false(how_to.visible)
