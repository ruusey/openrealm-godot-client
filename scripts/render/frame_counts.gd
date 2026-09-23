class_name FrameCounts
extends RefCounted

## What the last frame drew, read from the rendering server -- the one
## source for every count the client shows or a test judges (the HUD, the
## frame sampler, the render audit).
##
## The server is below every node and viewport, so nothing drawn can be
## missing from its counts. The Performance monitors of the same names read
## the same counters (212 = 212 frame for frame, measured); these read them
## at the source so there is one place the numbers come from. All zero
## headless, where nothing draws.


static func draw_calls() -> int:
	return read(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


static func objects() -> int:
	return read(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)


static func primitives() -> int:
	return read(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)


static func read(info: RenderingServer.RenderingInfo) -> int:
	return int(RenderingServer.get_rendering_info(info))
