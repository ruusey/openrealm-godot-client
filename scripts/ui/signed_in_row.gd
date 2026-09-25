class_name SignedInRow
extends HBoxContainer

## The one line the sign-in form gives way to once the account is listed:
## who is signed in, and a way out. Both references leave the sign-in
## behind at this point; keeping the form under the characters ran the
## Enter realm button off the bottom of a phone's rows.

var _name: Label


func _init(on_sign_out: Callable) -> void:
	visible = false
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(_name)
	InventoryLayout.button(self, "Sign out", on_sign_out)


func show_for(email: String) -> void:
	_name.text = "Signed in as %s" % email
	visible = true
