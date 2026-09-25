class_name TouchSize
extends RefCounted

## A control grown to a thumb: the character select's buttons and rows.
##
## The sign-in panel was laid out for a mouse, and on a phone its buttons
## were a finger's width tall. A row a thumb can hit is about 48 points --
## Android's own minimum touch target -- and the text grows with it.

const ROW := 48.0
const FONT := 18


static func grow(control: Control, font := FONT) -> Control:
	# Square at least, so a one-character button (the "x") is no thin sliver.
	control.custom_minimum_size = control.custom_minimum_size.max(Vector2(ROW, ROW))
	control.add_theme_font_size_override("font_size", font)
	return control


## Every Button and LineEdit under `root` grown, as the sign-in's controls
## are: a form built in one place, sized in one place.
static func grow_all(root: Node, font := FONT) -> void:
	for node in root.find_children("*", "", true, false):
		if node is Button or node is LineEdit:
			grow(node, font)
