class_name FxGeneric
extends RefCounted

## What an effect this build has no drawer for looks like: the native
## client's generic AoE form, in the effect's tier colour. Every type the
## server names has its own drawer, so this is what a newer server's
## effect draws as until someone ports it -- and the native's per-type hue
## table went with the last type it coloured.
##
## A disc kept light so a large area tints rather than washes out, three
## concentric rings for thickness, a pulsing inner ring, sixteen bright
## motes orbiting the rim and twelve drifting out from the centre, and a
## flash for the first third. The radius snaps out over the first third;
## alpha holds until 70% and then fades.
## A tier of ten or more is the server's boss-grenade sentinel and gets
## the native's much louder ring: red at 10, green at 11, blue at 12.

const BOSS_TIER := 10
## Boss sentinel tiers: [fill, edge, second edge] for 10 red, 11 green, 12 blue.
const BOSS := {
	11: [Color(0.078, 0.722, 0.235), Color(0.200, 0.878, 0.333), Color(0.451, 1.000, 0.584)],
	12: [Color(0.078, 0.471, 1.000), Color(0.200, 0.600, 1.000), Color(0.451, 0.753, 1.000)],
}
const BOSS_RED := [Color(1.000, 0.051, 0.051), Color(1.000, 0.200, 0.200), Color(1.000, 0.451, 0.333)]

## Which form the last draw took, "boss" or "generic": a test cannot see
## draw commands, but it can see this.
static var last_form := ""


static func radius_at(radius: float, progress: float) -> float:
	return radius * minf(progress * 3.0, 1.0)


static func alpha_at(progress: float) -> float:
	return 1.0 if progress < 0.7 else maxf(0.0, 1.0 - (progress - 0.7) * 3.33)


static func draw(canvas: CanvasItem, fx: Dictionary, progress: float, colour: Color, _elapsed_ms: int) -> void:
	var at: Vector2 = fx["pos"]
	var radius: float = fx["radius"]
	if radius <= 0.0:
		return
	if int(fx.get("tier", 0)) >= BOSS_TIER:
		last_form = "boss"
		_boss(canvas, at, radius, progress, int(fx["tier"]))
		return
	last_form = "generic"
	var reach := radius_at(radius, progress)
	var alpha := alpha_at(progress)
	canvas.draw_circle(at, reach, Color(colour, alpha * 0.20))
	canvas.draw_arc(at, reach, 0.0, TAU, 64, Color(colour, alpha), 4.0)
	for scale in [0.97, 1.03]:
		canvas.draw_arc(at, reach * scale, 0.0, TAU, 64, Color(colour, alpha * 0.7), 4.0)
	var pulse := 0.7 + 0.3 * sin(progress * PI * 8.0)
	canvas.draw_arc(at, reach * 0.6, 0.0, TAU, 48, Color(colour, alpha * 0.8 * pulse), 2.0)
	var bright := Color(minf(colour.r + 0.3, 1.0), minf(colour.g + 0.3, 1.0), minf(colour.b + 0.3, 1.0))
	for i in 16:
		var angle := i * TAU / 16.0 + progress * PI * 4.0
		var mote := Fx.polar(at, angle, reach)
		var mote_alpha := alpha * (0.6 + 0.4 * sin(angle * 3.0 + progress * PI * 10.0))
		canvas.draw_rect(Rect2(mote - Vector2(3, 3), Vector2(6, 6)), Color(bright, mote_alpha))
	var lighter := Color(minf(colour.r + 0.2, 1.0), minf(colour.g + 0.2, 1.0), minf(colour.b + 0.2, 1.0))
	for i in 12:
		var angle := i * TAU / 12.0 - progress * PI * 3.0
		var distance := reach * 0.2 + reach * 0.6 * progress
		canvas.draw_rect(Rect2(Fx.polar(at, angle, distance) - Vector2(2.5, 2.5), Vector2(5, 5)), Color(lighter, alpha * 0.9))
	if progress < 0.3:
		canvas.draw_circle(at, reach * 0.3 * (1.0 - progress * 2.0), Color(Color.WHITE, (0.3 - progress) * 3.0 * 0.5))


## The boss grenade: a loud filled disc with a thick edge that throbs, and
## a second pair of rings inside and out.
static func _boss(canvas: CanvasItem, at: Vector2, radius: float, progress: float, tier: int) -> void:
	var alpha := 1.0 if progress < 0.7 else maxf(0.0, 1.0 - (progress - 0.7) * 3.33)
	var colours: Array = BOSS.get(tier, BOSS_RED)
	canvas.draw_circle(at, radius, Color(colours[0], alpha * 0.95))
	var urgency := 0.85 + 0.15 * sin(progress * PI * 12.0)
	for scale in [1.0, 0.97, 1.03]:
		canvas.draw_arc(at, radius * scale, 0.0, TAU, 48, Color(colours[1], alpha * urgency), 8.0)
	for scale in [0.9, 1.1]:
		canvas.draw_arc(at, radius * scale, 0.0, TAU, 48, Color(colours[2], alpha * 0.85), 8.0)
