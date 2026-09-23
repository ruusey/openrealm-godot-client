class_name RemoteAnimation
extends RefCounted

## Keeps remote characters' animation state moving.
##
## Split from EntityRegistry, which holds where entities *are*; this is what
## they look like while they are there. Only players have anything to advance
## -- enemies are drawn from a single static sprite, with no cadence to keep.


## Starts a remote player's swing, aimed along the bullet they fired.
##
## Nothing on the wire says "X attacked" -- the shot itself is the signal, and
## its angle is what both references use to pick the clip. Deriving it from
## movement instead leaves a stationary shooter swinging the wrong way.
static func note_attack(players: Dictionary, player_id: int, angle: float) -> void:
	if not players.has(player_id):
		return
	players[player_id]["attack"].begin(ProjectileAngle.direction(angle))


## Advances every remote player's walk cycle from its streamed velocity.
## Enemies are drawn from a single static sprite, so they have no cadence to
## keep.
static func advance(players: Dictionary, delta: float) -> void:
	for id in players:
		var player: Dictionary = players[id]
		var snapshots: Array = player["snaps"]
		# Remote velocity already arrives as px/tick, the units WalkCycle wants.
		var velocity: Vector2 = Vector2.ZERO if snapshots.is_empty() else snapshots[-1]["vel"]
		player["walk"].advance(velocity.length(), delta)
		player["attack"].tick(delta)
		# Remote players face where they are going, exactly as the local one
		# does -- both reference clients derive it from velocity.
		player["facing_left"] = Facing.mirrored(velocity, player["facing_left"])
		player["facing"] = Facing.of(velocity, player["facing"])
