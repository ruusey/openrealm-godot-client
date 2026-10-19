extends GutTest

## On a phone Nexus is a hot button on the bottom row beside the potions,
## and the top row is PhoneBar's.


func _row_labels(cluster: TouchCluster) -> Array:
	return cluster._panels.get_children().map(func(button: Button) -> String: return button.text)


func test_a_phone_puts_nexus_beside_the_potions_not_in_the_menu():
	var cluster: TouchCluster = autofree(TouchCluster.new(true))
	assert_not_null(cluster._nexus)
	assert_null(cluster._panels, "no top row")
	cluster.place(Vector2(800, 400), Vector2(20, 8))
	assert_eq(cluster._nexus.position.y, cluster._mp.position.y, "on the potions' row")
	assert_lt(cluster._nexus.position.x, cluster._mp.position.x, "left of MP")
	var pressed := [false]
	cluster.nexus.connect(func() -> void: pressed[0] = true)
	cluster._nexus.pressed.emit()
	assert_true(pressed[0])


func test_a_desktop_keeps_nexus_on_the_top_row():
	var cluster: TouchCluster = autofree(TouchCluster.new(false))
	assert_null(cluster._nexus)
	assert_true(_row_labels(cluster).has("Nexus"))
