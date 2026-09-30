class_name MeleeReticle
extends Control

## A small marker hovering in the aim direction at the equipped melee weapon's
## maximum reach.
##
## A melee swing is an invisible server-side cone (apex at the player centre,
## length = the weapon's projectile range x the archetype's rangeMul, matching
## spawnMeleeSwing), and the swing animation doesn't show how far it reaches. The
## legacy clients drew this dot so the player can see what a swing will and won't
## hit. Hidden for ranged weapons and when there is no mouse aim.
##
## Anchored like every other overlay element: a world point pushed through the
## same `to_screen` transform (the 2D camera's, or the 3D affine projector), so it
## works in both render modes with no extra code.

const RADIUS := 4.0
const FILL := Color(1.0, 0.85, 0.3, 0.85)
const RING := Color(0.0, 0.0, 0.0, 0.6)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 1.0, RING)
	draw_circle(Vector2.ZERO, RADIUS, FILL)


## Places the marker at the melee reach in the aim direction, or hides it when the
## weapon isn't melee / there is no aim point.
func place(state: RealmState, content: GameData, to_screen: Transform2D, aim: Variant) -> void:
	if content == null or state == null or not state.local.is_present() or not (aim is Vector2):
		visible = false
		return
	var weapon: Dictionary = state.local.equipped_weapon()
	var archetype: Dictionary = content.archetype_for_item(int(weapon.get("itemId", -1)))
	if not bool(archetype.get("melee", false)):
		visible = false
		return
	var reach := _reach(content, weapon, archetype)
	if reach <= 0.0:
		visible = false
		return
	var centre: Vector2 = state.local.render_centre()
	var direction: Vector2 = aim - centre
	if direction.length_squared() < 0.0001:
		visible = false
		return
	position = (to_screen * (centre + direction.normalized() * reach)).round()
	visible = true
	queue_redraw()


## Max reach in world px: the weapon's projectile range scaled by the archetype's
## rangeMul, exactly as the server sizes the melee cone.
func _reach(content: GameData, weapon: Dictionary, archetype: Dictionary) -> float:
	var group_id := int(weapon.get("damage", {}).get("projectileGroupId", 0))
	if group_id == 0:
		group_id = content.item_projectile_group(int(weapon.get("itemId", -1)))
	if group_id == 0:
		return 0.0
	var definitions := content.projectiles_in_group(group_id)
	if definitions.is_empty():
		return 0.0
	return float(definitions[0].get("range", 0.0)) * float(archetype.get("rangeMul", 1.0))
