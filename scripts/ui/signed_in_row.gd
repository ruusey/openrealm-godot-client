class_name SignedInRow
extends HBoxContainer

## The one line the sign-in form gives way to once the account is listed:
## who is signed in, and a way out. Both references leave the sign-in
## behind at this point; keeping the form under the characters ran the
## Enter realm button off the bottom of a phone's rows. Buy Fame sits
## beside Sign out while the data service is selling fame.

var _name: Label
var _buy_fame: Button


func _init(on_sign_out: Callable, on_buy_fame := Callable()) -> void:
	visible = false
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(_name)
	if on_buy_fame.is_valid():
		_buy_fame = InventoryLayout.button(self, "Buy Fame", on_buy_fame)
		_buy_fame.visible = false
	InventoryLayout.button(self, "Sign out", on_sign_out)


func show_for(email: String) -> void:
	_name.text = "Signed in as %s" % email
	visible = true


func show_buy_fame(on: bool) -> void:
	if _buy_fame != null and _buy_fame.visible != on:
		_buy_fame.visible = on
