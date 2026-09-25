class_name TouchButtons
extends RefCounted

## How the on-screen buttons look: round ones for Attack, the abilities
## and the potions, flat ones for Bag, Menu, Chat and the menu's list --
## and the move stick.


static func flat(text: String, size: Vector2, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


static func round(radius: float, colour: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2.ONE * radius * 2.0
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for look in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(look, circle(radius, colour.lightened(0.25) if look == "pressed" else colour))
	button.add_theme_stylebox_override("disabled", circle(radius, colour.darkened(0.6)))
	return button


static func circle(radius: float, colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = Color(1.0, 1.0, 1.0, 0.6)
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(radius))
	box.set_content_margin_all(radius * 0.3)
	return box


## The move stick: it rises where the thumb lands, on the move actions.
static func stick(size: float, tip: float) -> VirtualJoystick:
	var stick := VirtualJoystick.new()
	for side in ["left", "right", "up", "down"]:
		stick.set("action_" + side, StringName("move_" + side))
	stick.joystick_size = size
	stick.tip_size = tip
	stick.deadzone_ratio = 0.1
	stick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	stick.visibility_mode = VirtualJoystick.VISIBILITY_WHEN_TOUCHED
	stick.visible = false
	return stick
