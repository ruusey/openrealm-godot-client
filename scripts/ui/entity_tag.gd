class_name EntityTag
extends Control

## Everything pinned to one character: the name, the health and mana bars,
## the quest stars under them, and over its head the chips and the bubble
## (HeadStack).
##
## Godot Controls, positioned in screen space at the web client's own pixel
## sizes -- its uiLayer: name 16px bold with a 3px stroke just over the bars,
## bars as wide as the sprite and 4 tall, 28 under the feet; an enemy gets
## one bar over it only while hurt. The tag is placed at the sprite's screen
## top-left and sized to the sprite, so every child is an offset from it.

const BAR_HEIGHT := 4.0
const BAR_GAP := 2.0
const BAR_DROP := 28.0
const NAME_GAP := 5.0
const CHIP_LIFT := 18.0
const ENEMY_BAR_HEIGHT := 6.0
const ENEMY_BAR_LIFT := 12.0
const BACK := Color(0.133, 0.133, 0.133, 0.7)
const HP := Color("40c040", 0.9)
const MP := Color("4080e0", 0.9)
const ENEMY_HP := Color(0.85, 0.2, 0.2)

static var name_style: LabelSettings = TagStyles.name_label()
static var star_style: LabelSettings = TagStyles.star_label()
## The name style in each colour asked for, shared by every tag.
static var _name_styles := {}

var _hp_back: ColorRect
var _hp: ColorRect
var _mp_back: ColorRect
var _mp: ColorRect
var _name: Label
var _stars: Label
var _head: HeadStack


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_back = _rect(BACK)
	_hp = _rect(HP)
	_mp_back = _rect(BACK)
	_mp = _rect(MP)
	_name = Label.new()
	_name.label_settings = name_style
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_stars = Label.new()
	_stars.label_settings = star_style
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stars)
	_head = HeadStack.new()
	add_child(_head)


## A player at `at` (the sprite's screen top-left), `size` pixels square.
func show_player(at: Vector2, size: float, label: String, colour: Color, health: int,
		max_health: int, mana: int, max_mana: int, effects: Array, stacks: Array,
		bubble: Dictionary, stars := 0) -> void:
	position = at
	self.size = Vector2(size, size)
	var top := size + BAR_DROP
	_bar(_hp_back, _hp, BACK, HP, top, size, fraction(health, max_health))
	_bar(_mp_back, _mp, BACK, MP, top + BAR_HEIGHT + BAR_GAP, size, fraction(mana, max_mana))
	_name.visible = label != ""
	_name.text = label
	var style := name_settings(colour)
	if _name.label_settings != style:
		_name.label_settings = style
	_name.reset_size()
	_name.position = Vector2(size * 0.5 - _name.size.x * 0.5, top - NAME_GAP - _name.size.y).round()
	# Under the bars, not over them as the web's line lands: its top meets the
	# name's baseline and covers the HP and MP bars.
	_stars.visible = stars > 0
	if _stars.visible:
		_stars.text = "\u2605 %d" % stars
		_stars.reset_size()
		_stars.position = Vector2(size * 0.5 - _stars.size.x * 0.5, top + 2.0 * BAR_HEIGHT + BAR_GAP + 1.0).round()
	_head.position = Vector2(size * 0.5, -CHIP_LIFT).round()
	_head.show_stack(effects, stacks, bubble)


## The name style in `colour`. Its own LabelSettings, because a
## LabelSettings colour wins over a theme override -- set that way, the local
## player's green never showed and every name drew white.
static func name_settings(colour: Color) -> LabelSettings:
	if not _name_styles.has(colour):
		var style := name_style.duplicate() as LabelSettings
		style.font_color = colour
		_name_styles[colour] = style
	return _name_styles[colour]


## An enemy: a bar over it only while hurt, chips over that.
func show_enemy(at: Vector2, width: float, health: int, max_health: int, effects: Array,
		stacks: Array) -> void:
	position = at
	size = Vector2(width, width)
	_name.visible = false
	_stars.visible = false
	_mp_back.visible = false
	_mp.visible = false
	var hurt := health < max_health
	_hp_back.visible = hurt
	_hp.visible = hurt
	if hurt:
		_bar(_hp_back, _hp, Color(0, 0, 0, 0.6), ENEMY_HP, -ENEMY_BAR_LIFT, width,
			fraction(health, max_health), ENEMY_BAR_HEIGHT)
	_head.position = Vector2(width * 0.5, -2.0).round()
	_head.show_stack(effects, stacks, {})


func chip_count() -> int:
	return _head.chip_count()


func has_bubble() -> bool:
	return _head.has_bubble()


## A maximum the client has not learned yet reads as full, not as empty; the
## web client does the same.
static func fraction(current: int, maximum: int) -> float:
	if maximum <= 0:
		return 1.0
	return clampf(float(current) / float(maximum), 0.0, 1.0)


func _bar(back: ColorRect, fill: ColorRect, back_colour: Color, fill_colour: Color, top: float,
		width: float, filled: float, height := BAR_HEIGHT) -> void:
	back.visible = true
	fill.visible = true
	back.color = back_colour
	fill.color = fill_colour
	back.position = Vector2(0.0, top)
	back.size = Vector2(width, height)
	fill.position = Vector2(0.0, top)
	fill.size = Vector2(width * filled, height)


func _rect(colour: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = colour
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
