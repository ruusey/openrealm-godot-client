class_name HowToControls
extends RefCounted

## The how-to's Controls table, and every key the rest of the guide names.
##
## The web client's rows, with this client's keys: each is read from the
## input map as the guide opens, so a key rebound under Options -> Controls
## reads as rebound here. The rows follow what this client does -- no
## autofire, and the bag, the sheet and the quest log each have a key --
## rather than the web's list word for word. Enter, Escape, the mouse
## buttons and Shift with a digit are not rebindable, so they are text.

const KEY_COLOUR := "#ffe9a8"
const KEY_BACK := "#2a2430"
const REBIND := "Keys can be rebound under [b]Esc → Options → Controls[/b]."


## [what, keys] in the order the table lists them.
static func rows() -> Array:
	return [
		["Move", keys(["move_up", "move_left", "move_down", "move_right"])],
		["Shoot (aim with cursor)", "Hold " + kbd("Left Mouse")],
		["Cast ability 1 / 2 / 3", "%s  /  %s for 1" % [keys(["ability_1", "ability_2", "ability_3"]), kbd("Right Mouse")]],
		["Drink HP potion", key("drink_hp")],
		["Drink MP potion", key("drink_mp")],
		["Pick up loot / use a tile", key("pick_up")],
		["Use a portal", key("use_portal")],
		["Return to the nexus", key("go_nexus")],
		["Go to the vault", key("go_vault")],
		["Use backpack slot 1–8", "%s + %s–%s" % [kbd("Shift"), kbd("1"), kbd("8")]],
		["Bag", key("toggle_inventory")],
		["Character sheet (skill points)", key("toggle_skills")],
		["Masteries", key("toggle_masteries")],
		["Quest log", key("toggle_quests")],
		["Minimap", key("toggle_minimap")],
		["Open chat", kbd("Enter")],
		["Open menu / options", kbd("Esc")],
	]


static func table() -> String:
	var out := "[table=2]"
	for row in rows():
		out += "[cell padding=0,2,24,2]%s[/cell][cell padding=0,2,0,2]%s[/cell]" % row
	return out + "[/table]\n" + REBIND


## The keys the guide's prose names, for String.format.
static func key_words() -> Dictionary:
	return {"bag": key("toggle_inventory"), "shift": kbd("Shift"), "one": kbd("1"), "eight": kbd("8"),
		"hp": key("drink_hp"), "mp": key("drink_mp"), "pick_up": key("pick_up"),
		"a1": key("ability_1"), "a2": key("ability_2"), "a3": key("ability_3"),
		"right": kbd("Right Mouse"), "sheet": key("toggle_skills"), "masteries": key("toggle_masteries")}


## The key an action answers to now, as a keycap.
static func key(action: String) -> String:
	return kbd(KeyBindings.key_name(KeyBindings.key_of(action)))


static func keys(actions: Array) -> String:
	return " ".join(actions.map(key))


## A keycap: the web's .howto-kbd, a dark box and a light face.
static func kbd(text: String) -> String:
	return "[bgcolor=%s][color=%s] %s [/color][/bgcolor]" % [KEY_BACK, KEY_COLOUR, text]
