extends GutTest

## TermsGate unlocks I Agree only once the terms have been read to the end,
## and the login screen shows it between signing in and the list.

var gate: TermsGate


func before_each():
	gate = TermsGate.new()
	add_child_autofree(gate)


func _laid_out() -> void:
	await wait_process_frames(3)


func test_hidden_and_idle_until_asked():
	assert_false(gate.visible)
	assert_false(gate.is_processing(), "nothing watched behind the game")
	gate.ask()
	assert_true(gate.is_processing())
	gate.answer(false)
	assert_false(gate.is_processing())


func test_agree_stays_dead_until_the_end_is_reached():
	gate.ask()
	await _laid_out()
	assert_true(gate.visible)
	assert_gt(gate.body.get_content_height(), 300, "the terms are longer than the box")
	assert_false(gate.read_to_end())
	assert_true(gate.agree_button.disabled)
	watch_signals(gate)
	gate.agree_button.pressed.emit()
	gate.answer(true)
	assert_signal_not_emitted(gate, "answered", "a dead button agrees to nothing")
	assert_true(gate.visible)
	var bar := gate.body.get_v_scroll_bar()
	bar.value = bar.max_value
	await _laid_out()
	assert_true(gate.read_to_end())
	assert_false(gate.agree_button.disabled, "unlocked at the end")
	assert_eq(gate.hint.modulate.a, 0.0, "the hint goes")
	bar.value = 0
	await _laid_out()
	assert_false(gate.agree_button.disabled, "and stays unlocked")


func test_ask_comes_back_with_the_answer():
	var answers := []
	var asking := func() -> void: answers.append(await gate.ask())
	asking.call()
	await _laid_out()
	gate.decline_button.pressed.emit()
	assert_eq(answers, [false])
	assert_false(gate.visible)
	asking.call()
	await _laid_out()
	assert_true(gate.agree_button.disabled, "asked again, read again")
	var bar := gate.body.get_v_scroll_bar()
	bar.value = bar.max_value
	await _laid_out()
	gate.agree_button.pressed.emit()
	assert_eq(answers, [false, true])


func test_nothing_laid_out_is_not_the_end():
	var loose := TermsGate.new()
	add_child_autofree(loose)
	loose.body.text = ""
	assert_false(loose.read_to_end())


# --- on the login screen -----------------------------------------------------

func _screen() -> Array:
	var backend := FakeHttpBackend.new()
	var service := DataService.new()
	service.backend = backend
	service.base_url = "http://data.test"
	add_child_autofree(service)
	var screen := LoginScreen.new()
	screen.data_service = service
	add_child_autofree(screen)
	screen.prefill("me@example.com", "pw")
	backend.push_json(200, {"accountGuid": "g", "token": "t"})
	backend.push_json(200, {"currentVersion": 1, "acceptedVersion": 0, "needsAcceptance": true})
	return [screen, backend]


func test_declining_on_the_login_screen_signs_out():
	var made := _screen()
	var screen: LoginScreen = made[0]
	screen._on_login_pressed()
	await _laid_out()
	assert_true(screen._terms.visible, "asked before anything is listed")
	assert_true(screen._form.button.disabled, "no second sign-in meanwhile")
	screen._terms.decline_button.pressed.emit()
	await _laid_out()
	assert_false(screen._terms.visible)
	assert_eq(screen._status.text, AccountSignIn.DECLINED)
	assert_false(screen._stage.visible)
	assert_false(screen._form.button.disabled)
	assert_eq(screen.data_service.token, "")


func test_agreeing_on_the_login_screen_lists_the_characters():
	var made := _screen()
	var screen: LoginScreen = made[0]
	var backend: FakeHttpBackend = made[1]
	backend.push_json(200, {"ok": true, "acceptedVersion": 1})
	backend.push_json(200, {"characters": [{"characterUuid": "c1", "characterClass": 0, "stats": {}}]})
	screen._on_login_pressed()
	await _laid_out()
	var bar := screen._terms.body.get_v_scroll_bar()
	bar.value = bar.max_value
	await _laid_out()
	screen._terms.agree_button.pressed.emit()
	await _laid_out()
	assert_string_ends_with(backend.requests[2]["url"], "/admin/account/terms/accept")
	assert_true(screen._stage.visible)
	assert_eq(screen._stage.picker.alive_count(), 1)
