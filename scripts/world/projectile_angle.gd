class_name ProjectileAngle
extends RefCounted

## Angle handling for projectiles, which has two independent traps in it.
##
## 1. Content authors angles as numbers *or* strings, including the `{{PI}}`
##    and `{{3PI/4}}` placeholders the Java RadianAngleDeserializer expands.
##    Missing that parse is a known failure: the whole enemy/projectile load
##    dies and nothing renders.
##
## 2. The convention is unusual. Velocity is (sin a, cos a) -- angle measured
##    clockwise from +Y, not counter-clockwise from +X. The Java
##    `Bullet.getAngle` helper is *not* the inverse of that: it omits a
##    negation and comes out mirrored in x. `aim` below follows the working
##    web client, which is the behaviour players actually get.

const _PI_EXPRESSION := r"^\{\{\s*(-)?\s*(\d*)\s*PI\s*(?:/\s*(\d+))?\s*\}\}$"

static var _regex: RegEx = null


static func parse(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	if not value is String:
		return 0.0

	var text := (value as String).strip_edges()
	if text == "":
		return 0.0
	if text.is_valid_float():
		return text.to_float()

	if _regex == null:
		_regex = RegEx.new()
		_regex.compile(_PI_EXPRESSION)
	var found := _regex.search(text)
	if found == null:
		push_warning("ProjectileAngle: unparseable angle '%s'" % text)
		return 0.0

	var sign := -1.0 if found.get_string(1) == "-" else 1.0
	var numerator := found.get_string(2)
	var denominator := found.get_string(3)
	var result := PI * (numerator.to_float() if numerator != "" else 1.0)
	if denominator != "":
		result /= denominator.to_float()
	return sign * result


## Firing angle from a source point toward a target.
static func aim(source_centre: Vector2, target: Vector2) -> float:
	return -(atan2(target.y - source_centre.y, target.x - source_centre.x) - PI * 0.5)


## Unit travel direction for an angle in this convention.
static func direction(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))


## The axis 90 degrees from travel, used by the parametric wave.
static func perpendicular(angle: float) -> Vector2:
	return Vector2(cos(angle), -sin(angle))
