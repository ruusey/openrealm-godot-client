class_name JsonInt64
extends RefCounted

## Recovers 64-bit integers from JSON.
##
## Godot's JSON parser stores every number as a float, and a double only
## carries 53 bits of mantissa -- so a player id like 3088558154868086650
## comes back as 3088558154868086272. The server then sees the rounded id in
## the next PlayerMovePacket and disconnects the session for a player-id
## mismatch, which looks like a protocol bug and is not one.
##
## Binary packets are unaffected: the codec reads int64 straight from the
## bytes. This is only needed for ids carried inside JSON command payloads.

const _PATTERN := '"%s"\\s*:\\s*(-?\\d+)'


## Reads one integer field straight from the JSON text, bypassing the float.
## Returns `fallback` when the field is absent or not an integer literal.
static func read_field(raw: String, key: String, fallback := 0) -> int:
	var regex := RegEx.new()
	regex.compile(_PATTERN % key.replace("\\", "\\\\").replace('"', '\\"'))
	var found := regex.search(raw)
	if found == null:
		return fallback
	return found.get_string(1).to_int()


## Replaces the named fields of an already-parsed object with their exact
## values from the source text.
static func repair(raw: String, parsed: Variant, keys: Array) -> Variant:
	if not parsed is Dictionary:
		return parsed
	var out: Dictionary = parsed
	for key in keys:
		if out.has(key):
			out[key] = read_field(raw, key, int(out[key]))
	return out
