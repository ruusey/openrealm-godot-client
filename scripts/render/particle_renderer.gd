class_name ParticleRenderer
extends Node2D

## Draws the particle field, under the bullets.
##
## One texture for every particle -- a white dot fading to nothing at its
## edge, the web client's radial gradient -- tinted and faded per command,
## so the whole layer batches. It sits under the bullet layer because both
## references order fx < afterimages < outlines < bodies: a shot is drawn
## over its own smoke.

const DOT_SIZE := 32

var state: RealmState
var drawn := 0

static var _dot: ImageTexture
## Every in-view particle is one instance of a shared unit quad, so the whole
## field draws in a single draw_multimesh call rather than a draw_texture_rect
## per particle -- draw-call count is the frame ceiling under a horde on the GL
## compatibility backend. The per-instance transform carries the particle's size
## and position, the per-instance colour its tint and fade.
var _multimesh: MultiMesh


func _ready() -> void:
	# The one world layer that is not nearest-filtered: a soft dot sampled
	# nearest is a stepped one.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh.mesh = quad


func _draw() -> void:
	drawn = 0 if state == null else _paint_batched(state.particles, ViewRect.of(self))


## The in-view particles packed into the shared MultiMesh and drawn at once.
## Culls and counts exactly as paint() does; instances past the visible count are
## left undrawn, and instance_count only grows so the buffer is not re-allocated
## every frame. Returns the number drawn.
func _paint_batched(field: ParticleField, view: Rect2) -> int:
	if _multimesh.instance_count < field.count:
		_multimesh.instance_count = field.count
	var count := 0
	for i in field.count:
		var size := field.size_at(i)
		var at := Vector2(field.x[i], field.y[i])
		if not view.grow(size).has_point(at):
			continue
		var colour: Color = field.tint[i]
		colour.a = field.alpha_at(i)
		_multimesh.set_instance_transform_2d(count, Transform2D(0.0, Vector2(size, size), 0.0, at))
		_multimesh.set_instance_color(count, colour)
		count += 1
	_multimesh.visible_instance_count = count
	if count > 0:
		draw_multimesh(_multimesh, soft_dot())
	return count


static func paint(canvas: CanvasItem, field: ParticleField, view: Rect2) -> int:
	var texture := soft_dot()
	var painted := 0
	for i in field.count:
		var size := field.size_at(i)
		var at := Vector2(field.x[i], field.y[i])
		if not view.grow(size).has_point(at):
			continue
		var colour: Color = field.tint[i]
		colour.a = field.alpha_at(i)
		canvas.draw_texture_rect(texture, Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)),
			false, colour)
		painted += 1
	return painted


## Built once: full at the centre, just over half at 45% of the radius, gone
## at the edge, with straight ramps between -- the web client's gradient
## stops. The native's (1 - d)^2 is close, and not what the web draws.
static func soft_dot() -> ImageTexture:
	if _dot != null:
		return _dot
	var image := Image.create(DOT_SIZE, DOT_SIZE, false, Image.FORMAT_RGBA8)
	var centre := (DOT_SIZE - 1) * 0.5
	for py in DOT_SIZE:
		for px in DOT_SIZE:
			var distance := Vector2(px - centre, py - centre).length() / (DOT_SIZE * 0.5)
			image.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha_at_distance(distance)))
	_dot = ImageTexture.create_from_image(image)
	return _dot


static func alpha_at_distance(distance: float) -> float:
	if distance >= 1.0:
		return 0.0
	if distance <= 0.45:
		return lerpf(1.0, 0.55, distance / 0.45)
	return lerpf(0.55, 0.0, (distance - 0.45) / 0.55)
