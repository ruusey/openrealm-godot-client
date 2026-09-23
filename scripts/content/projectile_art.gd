class_name ProjectileArt
extends RefCounted

## Per-group render attributes, resolved from content once and cached.
##
## Sibling of ClassSprites: GameData stays a thin facade and the fiddly
## per-group parsing lives next to the thing that needs it. Both values here
## are parsed from strings or nested structures that would otherwise be
## re-walked every frame, for every bullet on screen.

## What the web client falls back to for a spin with no rate -- and, because
## `fx.rate || 6` treats zero as absent, for a rate of exactly zero too.
const DEFAULT_SPIN_RATE := 6.0

var _library: ContentLibrary
var _offsets := {}   # group id -> resolved angleOffset
var _spins := {}     # group id -> {} or {"rate": float, "additive": bool}
var _fx := {}        # group id -> {"trail", "impact", "muzzle": {} or the entry, "afterimage": Color}


func _init(library: ContentLibrary) -> void:
	_library = library


## Extra rotation the group's art needs, from its angleOffset template. The
## sprites are drawn pointing diagonally, so most groups carry PI/4; without
## it every shot is drawn 45 degrees off its heading. Only positive offsets
## apply, matching the web client.
func angle_offset(group_id: int) -> float:
	if not _offsets.has(group_id):
		_offsets[group_id] = maxf(AngleTemplate.parse(
			_group(group_id).get("angleOffset")), 0.0)
	return _offsets[group_id]


## The group's spin effect as {"rate": radians per second, "additive": bool},
## or {} when it does not spin.
##
## `rate` carries the direction in its sign. Screen space is y-down and
## Godot's rotation is clockwise-positive, as PIXI's is, so CW is positive
## here; the native client negates instead only because LibGDX is
## counter-clockwise-positive.
func spin(group_id: int) -> Dictionary:
	if not _spins.has(group_id):
		_spins[group_id] = _parse_spin(_group(group_id).get("fx"))
	return _spins[group_id]


static func _parse_spin(fx: Variant) -> Dictionary:
	if not fx is Array:
		return {}
	for entry in fx:
		if not entry is Dictionary or String(entry.get("type", "")) != "spin":
			continue
		var rate := float(entry.get("rate", 0.0))
		if is_zero_approx(rate):
			rate = DEFAULT_SPIN_RATE
		if String(entry.get("dir", "CW")).to_upper() == "CCW":
			rate = -rate
		# Anything that is not "continuous" is additive, which is how both
		# references read it -- the mode is absent on some entries.
		return {"rate": rate, "additive": String(entry.get("mode", "")) != "continuous"}
	return {}


## The group's particle effects and its afterimage, resolved once:
## `trail`, `impact` and `muzzle` are the raw fx entries of that type (or
## {}), and `afterimage` is the group's trailColor, transparent when it has
## none. The particles are the web client's data-driven fx list; the
## afterimage is a separate group property, five tinted copies behind a
## straight shot, that the same four groups mostly also carry.
func fx(group_id: int) -> Dictionary:
	if not _fx.has(group_id):
		_fx[group_id] = _parse_fx(_group(group_id))
	return _fx[group_id]


static func _parse_fx(group: Dictionary) -> Dictionary:
	var out := {"trail": {}, "impact": {}, "muzzle": {}, "afterimage": Color.TRANSPARENT}
	var entries: Variant = group.get("fx")
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary:
				continue
			var kind := String(entry.get("type", ""))
			if out.has(kind) and kind != "afterimage" and out[kind].is_empty():
				out[kind] = entry
	var trail_colour: Variant = group.get("trailColor")
	if trail_colour != null and String(trail_colour) != "":
		out["afterimage"] = colour(trail_colour, Color.WHITE)
	return out


## A colour as the content writes it -- "0x1c1c1c", "#8a1020" or a number --
## and `fallback` for anything else, which is how both references read it.
static func colour(value: Variant, fallback: Color) -> Color:
	if value is int or value is float:
		return Color.hex((int(value) << 8) | 0xff)
	if value is String:
		var text: String = value.strip_edges()
		for prefix in ["0x", "0X", "#"]:
			text = text.trim_prefix(prefix)
		if text.length() == 6 and text.is_valid_hex_number(false):
			return Color.hex((text.hex_to_int() << 8) | 0xff)
	return fallback


## How far a spinning group has turned by `now_ms`.
##
## Deliberately the wall clock rather than a bullet's own age, so every bullet
## in a group turns in phase. Both references do exactly this; a per-bullet
## phase would look more correct and match neither.
static func spun(spin: Dictionary, now_ms: int) -> float:
	if spin.is_empty():
		return 0.0
	return float(spin["rate"]) * (now_ms * 0.001)


func _group(group_id: int) -> Dictionary:
	return _library.projectile_groups.get(group_id, {})
