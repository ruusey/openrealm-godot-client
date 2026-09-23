class_name NetMaskedSections
extends RefCounted

## Presence rules for a masked-section block.
##
## v0.9.0 gates optional field groups on a bitmask byte: a straight bullet
## carries mask 0 and pays nothing for the wavy / orbit / homing / sprite
## groups. Reading is unambiguous -- the byte says what follows -- but writing
## has to decide which sections a Dictionary actually wants, which is what
## lives here.
##
## The mask a packet was decoded with is kept under `_mask`, so a decode
## followed by an encode reproduces the original bytes even when a section
## carried nothing but default values. Dictionaries built by hand have no
## `_mask`, so the sections are inferred from the values present instead.


static func mask_for(sections: Array, data: Dictionary, decoded: Variant) -> int:
	if decoded != null:
		return int(decoded)

	var mask := 0
	for section in sections:
		if has_values(section[1], data):
			mask |= int(section[0])
	return mask


## True when `data` carries any non-default value for this section's fields.
## Defaults are skipped so an all-zero group does not force its bit on, which
## is exactly the saving the mask exists for.
static func has_values(fields: Array, data: Dictionary) -> bool:
	for field in fields:
		var name: String = field[0]
		if not data.has(name):
			continue
		var value: Variant = data[name]
		match typeof(value):
			TYPE_NIL:
				continue
			TYPE_BOOL:
				if value:
					return true
			TYPE_INT:
				if int(value) != 0:
					return true
			TYPE_FLOAT:
				if not is_zero_approx(float(value)):
					return true
			TYPE_STRING:
				if String(value) != "":
					return true
			_:
				return true
	return false
