class_name ParticleField
extends RefCounted

## The particles behind projectiles: the smoke, tar or sparks a shot leaves
## behind it, and the burst where one lands.
##
## Both references keep these the same way -- one flat pool, a structure of
## arrays packed to the front, a shared soft dot tinted per particle -- and
## agree on every rule but one: a burst is fired for a bullet that was here
## last frame and is gone this one (impact) or is here for the first time
## (muzzle); a particle grows or shrinks from a start size to an end size,
## fades as the square of its remaining life, and slows. The one they
## differ on is the slowing: the web keeps 90% of the velocity a FRAME, the
## native e^-3 a SECOND; the native's reads the same at every frame rate.
##
## ParticleEmitter turns an fx entry into particles; ParticleRenderer draws
## the arrays. Nothing here allocates per particle.

const CAP := 4096
## A stalled frame must not teleport particles: the web client clamps its
## step at 48ms.
const MAX_STEP := 0.048
const DRAG_PER_SECOND := 3.0

var count := 0
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var life := PackedFloat32Array()
var max_life := PackedFloat32Array()
var size_start := PackedFloat32Array()
var size_end := PackedFloat32Array()
var tint := PackedColorArray()
## Seedable, so a scripted render lands on the same picture every time.
var rng := RandomNumberGenerator.new()

var _art: ProjectileArt
## Bullets with a burst seen last frame: id -> {centre, impact}.
var _seen := {}


func _init(art: ProjectileArt = null) -> void:
	_art = art
	for array in [x, y, vx, vy, life, max_life, size_start, size_end]:
		array.resize(CAP)
	tint.resize(CAP)


func clear() -> void:
	count = 0
	_seen.clear()


## One frame: trails from the live bullets, bursts for the ones that
## vanished since last frame, then every particle stepped.
## `hidden` names the bullets nobody can see (Blind): they emit nothing, and
## are remembered without an impact, so neither leaving sight nor landing
## out of sight bursts where it went -- the web emits from its draw pass,
## after the cull, to the same effect.
func advance(delta: float, bullets: Dictionary, hidden := Callable()) -> void:
	delta = minf(delta, MAX_STEP)
	if _art != null:
		_emit(delta, bullets, hidden)
	_step(delta)


func _emit(delta: float, bullets: Dictionary, hidden: Callable) -> void:
	var next := {}
	for id in bullets:
		var bullet: Dictionary = bullets[id]
		var centre := Projectile.centre(bullet)
		if hidden.is_valid() and hidden.call(bullet):
			next[id] = {"centre": centre, "impact": {}}
			continue
		var fx := _art.fx(int(bullet.get("group_id", -1)))
		if not fx["trail"].is_empty():
			ParticleEmitter.trail(self, centre, bullet, fx["trail"], delta)
		if not fx["muzzle"].is_empty() and not _seen.has(id):
			ParticleEmitter.burst(self, centre, fx["muzzle"])
		# A muzzle-only bullet is remembered too, or it would flash every
		# frame -- which is what both references' diff, keyed on the impact
		# alone, would do with one; no shipped group has a muzzle to show it.
		if not fx["impact"].is_empty() or not fx["muzzle"].is_empty():
			next[id] = {"centre": centre, "impact": fx["impact"]}
	for id in _seen:
		if not next.has(id) and not _seen[id]["impact"].is_empty():
			ParticleEmitter.burst(self, _seen[id]["centre"], _seen[id]["impact"])
	_seen = next


## False when the pool is full: the budget drops what it cannot hold.
func spawn(at: Vector2, velocity: Vector2, seconds: float, from_size: float,
		to_size: float, colour: Color) -> bool:
	if count >= CAP:
		return false
	x[count] = at.x
	y[count] = at.y
	vx[count] = velocity.x
	vy[count] = velocity.y
	life[count] = seconds
	max_life[count] = seconds
	size_start[count] = from_size
	size_end[count] = to_size
	tint[count] = colour
	count += 1
	return true


## Moves, slows and ages every particle, dropping the dead by not copying
## them forward.
func _step(delta: float) -> void:
	var keep := exp(-DRAG_PER_SECOND * delta)
	var alive := 0
	for i in count:
		var remaining_life := life[i] - delta
		if remaining_life <= 0.0:
			continue
		x[alive] = x[i] + vx[i] * delta
		y[alive] = y[i] + vy[i] * delta
		vx[alive] = vx[i] * keep
		vy[alive] = vy[i] * keep
		life[alive] = remaining_life
		max_life[alive] = max_life[i]
		size_start[alive] = size_start[i]
		size_end[alive] = size_end[i]
		tint[alive] = tint[i]
		alive += 1
	count = alive


## Where a particle is in its life, 1 fresh to 0 gone.
func remaining(i: int) -> float:
	return life[i] / max_life[i]


func size_at(i: int) -> float:
	return size_start[i] + (size_end[i] - size_start[i]) * (1.0 - remaining(i))


## The ease-out fade both references use.
func alpha_at(i: int) -> float:
	var f := remaining(i)
	return f * f
