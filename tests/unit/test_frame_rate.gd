extends GutTest

## The frame rate the client ships with: vsync on, and a 240 fps ceiling
## for when it is switched off, so an uncapped desktop run does not spin
## the GPU at hundreds of frames a second for nothing.


func test_vsync_is_on_by_default():
	var mode: int = ProjectSettings.get_setting("display/window/vsync/vsync_mode", DisplayServer.VSYNC_ENABLED)
	assert_eq(mode, DisplayServer.VSYNC_ENABLED)


func test_frames_are_capped_at_240():
	assert_eq(ProjectSettings.get_setting("application/run/max_fps"), 240)
	assert_eq(Engine.max_fps, 240, "applied to the running engine, not only written down")
