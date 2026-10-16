class_name CompanionSummonCell
extends Control

## The companion-summon readout that sits at the right end of the hotbar: the C
## key, and either READY, a draining summon-cooldown timer, or — while the
## companion is out — its remaining deployed time (or NEXUS, where it never
## expires). Hidden entirely for accounts that own no companion.

const SIZE_PX := 64.0
const COOLDOWN_WINDOW_MS := 10 * 60 * 1000
const BG_READY := Color(0.16, 0.29, 0.16, 0.9)
const BG_COOLDOWN := Color(0.18, 0.19, 0.22, 0.9)
const BG_DEPLOYED := Color(0.16, 0.35, 0.40, 0.9)

var _bg: ColorRect
var _shade: ColorRect
var _text: Label


func _init() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# Cooldown veil over the top of the cell, draining as it becomes ready (same
	# read as the ability cooldown shades beside it).
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.55)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_text = Label.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 12)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)


## Repaint from the account's companion state. Drives bg colour, the top-down
## cooldown veil, and the two-line label. `fraction` is the share of the cell the
## veil covers (1 = just summoned / fully on cooldown, 0 = ready).
func update_from(c: CompanionState) -> void:
	if c == null or c.count() == 0:
		visible = false
		return
	visible = true
	var fraction := 0.0
	if c.is_deployed():
		# C recalls a deployed companion. In the Nexus it never expires (just the
		# action); in combat, the action plus the time left before it auto-returns.
		_bg.color = BG_DEPLOYED
		if c.is_nexus_deploy():
			_text.text = "Recall\n(C)"
		else:
			_text.text = "Recall\n" + _mmss(c.deployed_remaining_ms())
	elif not c.summon_ready():
		_bg.color = BG_COOLDOWN
		var remaining := c.summon_cooldown_remaining_ms()
		_text.text = "Summon\n" + _mmss(remaining)
		fraction = clampf(float(remaining) / float(COOLDOWN_WINDOW_MS), 0.0, 1.0)
	else:
		_bg.color = BG_READY
		_text.text = "Summon\n(C)"
	var covered := SIZE_PX * fraction
	_shade.position = Vector2(0, 0)
	_shade.size = Vector2(SIZE_PX, covered)


static func _mmss(ms: int) -> String:
	var total := int(ceil(ms / 1000.0))
	return "%d:%02d" % [total / 60, total % 60]
