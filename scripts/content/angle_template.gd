class_name AngleTemplate
extends RefCounted

## Parses the `angleOffset` templates in projectile-groups.json.
##
## Content writes them as `{{PI/4}}`, occasionally with a coefficient
## (`{{3PI/4}}`), sometimes as a plain number, and once -- group 111 -- with a
## missing brace. The web client resolves these with a regex substitution of
## `<coeff>PI` followed by an eval, and anything it cannot parse degrades to
## 0; this mirrors that, including the degrade, because a projectile drawn at
## the wrong angle is worse than one drawn unrotated.

const TEMPLATE := r"\{\{(.+?)\}\}"
const COEFFICIENT := r"(\d*\.?\d*)PI"


static func parse(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is float or value is int:
		return float(value)

	var text := String(value).strip_edges()
	if text.is_empty():
		return 0.0

	var template := RegEx.create_from_string(TEMPLATE)
	var found := template.search(text)
	if found == null:
		# Not a template -- a bare number, or malformed like "{{PI/2}".
		return float(text) if text.is_valid_float() else 0.0

	return _evaluate(_substitute_pi(found.get_string(1).strip_edges()))


## `PI` -> its value, `3PI` -> 3 * PI, so the rest is plain arithmetic.
static func _substitute_pi(expression: String) -> String:
	var coefficient := RegEx.create_from_string(COEFFICIENT)
	var out := expression
	var found := coefficient.search(out)
	while found != null:
		var digits := found.get_string(1)
		var scale := 1.0 if digits.is_empty() else float(digits)
		out = out.substr(0, found.get_start()) + str(scale * PI) \
			+ out.substr(found.get_end())
		found = coefficient.search(out)
	return out


static func _evaluate(expression: String) -> float:
	var parsed := Expression.new()
	if parsed.parse(expression) != OK:
		return 0.0
	var result: Variant = parsed.execute()
	if parsed.has_execute_failed() or not (result is float or result is int):
		return 0.0
	return float(result)
