extends GutTest

## The four settings that decide how the finished frame reaches the window.
##
## They live in project.godot, which Godot rewrites on every launch and which
## carries no comments to explain itself -- a setting that changes here
## changes what every player sees, silently, and nothing else in the suite
## would notice. The reasoning is in README.md; these are the values.


func test_a_bigger_window_shows_more_world():
	# Not a scaled-up picture of the same world: the web client sizes its
	# canvas to the container and keeps a fixed world scale, so a wider window
	# is a wider view there too. `expand` is what matches it.
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_the_scale_never_lands_between_whole_pixels():
	# Measured on a 1273x758 window, fractional scaling of a 1280x720 base
	# came out 0.9953 by 0.9961 -- which does not blur, it DROPS pixels, so
	# single-pixel sprite details vanish and tile edges land off-grid. Godot's
	# integer mode fixed that and left black margins instead (a 1900x1000
	# window drew 1368x720 in the middle), so the setting stays at its
	# fractional default and DisplayScale keeps the ratio a whole number by
	# making the window itself the base. Its own test covers the rule.
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode", "fractional"), "fractional")


func test_the_base_the_scale_is_measured_against():
	# Both clients draw 32px tiles at 2x, so 20 tiles across at this width.
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)


func test_sprites_are_sampled_without_smoothing():
	# Nearest neighbour. This is only one leg of pixel-art crispness -- it
	# governs how a sprite is sampled, not how the frame is scaled to the
	# window, which is what the two settings above are for.
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_what_shows_through_where_there_is_no_tile():
	# Tile id 0 is Void_Tile -- "no tile", not a black square -- and is
	# skipped, so the window background is what shows through it. Black to
	# match the web client rather than Godot's grey.
	assert_eq(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"),
		Color(0, 0, 0, 1))
