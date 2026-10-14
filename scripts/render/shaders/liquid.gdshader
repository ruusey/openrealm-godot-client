shader_type canvas_item;

// Animates the chunk-cached water/lava tiles entirely on the GPU: the layer is
// drawn once (like the ground) and this runs every frame off TIME, so an ocean or
// a lava lake moves for free. Water vs lava is told apart from the base pixel
// (lava reads warm, water cool) so one material covers both. No TEXTURE UV is
// offset -- that would bleed across the atlas -- the motion is added to the colour.
//
// The pattern is driven by WORLD position (MODEL_MATRIX * VERTEX, before the camera
// transform), not FRAGCOORD, so it stays locked to the terrain and does NOT scroll
// with the camera.
//
// A cell beside land arrives with its shore in the vertex colour (LiquidRenderer):
// red = the cardinal sides that are land, green = the corners, as 4-bit masks over
// 15; blue and alpha = the colour of the ground's lip, RGB565, with blue zero
// for none (red is never zero in a real one). The lip pokes a
// ragged pixel or two into the liquid so the coastline leaves the tile grid.
// Shore effects are worked on the art's own pixel grid so they stay crisp.

uniform float water_speed : hint_range(0.0, 6.0) = 1.5;
uniform float lava_speed : hint_range(0.0, 6.0) = 1.0;
uniform float shore_reach : hint_range(4.0, 32.0) = 15.0;
uniform float shore_pixel : hint_range(1.0, 8.0) = 4.0;
uniform float lip_depth : hint_range(0.0, 16.0) = 7.0;
uniform vec3 foam_colour : source_color = vec3(0.86, 0.95, 1.0);

const float CELL = 32.0;

varying vec2 world_pos;
varying vec2 shore_mask;
varying vec3 lip_colour;
varying float has_lip;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	shore_mask = floor(COLOR.rg * 15.0 + 0.5);
	float high = floor(COLOR.b * 255.0 + 0.5);
	float low = floor(COLOR.a * 255.0 + 0.5);
	has_lip = step(0.5, high);
	lip_colour = vec3(floor(high / 8.0) / 31.0,
		(mod(high, 8.0) * 8.0 + floor(low / 32.0)) / 63.0, mod(low, 32.0) / 31.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bit(float mask, float value) {
	return mod(floor(mask / value), 2.0);
}

// World pixels from `local` (within the cell) to the nearest land: a land side
// is an edge, a land corner is a point, so inner corners come out round.
float shore_distance(vec2 local) {
	float far = CELL * 2.0;
	float d = far;
	vec2 back = CELL - local;
	d = min(d, mix(far, local.y, bit(shore_mask.r, 1.0)));
	d = min(d, mix(far, back.y, bit(shore_mask.r, 2.0)));
	d = min(d, mix(far, local.x, bit(shore_mask.r, 4.0)));
	d = min(d, mix(far, back.x, bit(shore_mask.r, 8.0)));
	d = min(d, mix(far, length(local), bit(shore_mask.g, 1.0)));
	d = min(d, mix(far, length(vec2(back.x, local.y)), bit(shore_mask.g, 2.0)));
	d = min(d, mix(far, length(vec2(local.x, back.y)), bit(shore_mask.g, 4.0)));
	d = min(d, mix(far, length(back), bit(shore_mask.g, 8.0)));
	return d;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) {
		discard;
	}
	float warm = clamp((base.r - base.b) * 3.0, 0.0, 1.0);   // lava ~1, water ~0
	// World-space (camera-independent), matched to the old screen-space frequency.
	vec2 p = world_pos * 0.08;

	// Water: the darker moving ripple bands only. (A brighter scrolling caustic
	// streak used to ride on top but read as distracting, so it's gone.)
	float ripple = sin(p.x * 1.3 + p.y * 0.7 + TIME * water_speed)
		+ sin(p.x * 0.6 - p.y * 1.1 - TIME * water_speed * 0.7);
	vec3 water = base.rgb + 0.14 * ripple * vec3(0.3, 0.6, 1.0);

	// Lava: strong glow pulse plus moving hot cracks pushing toward yellow.
	float flow = sin(p.x * 0.8 + TIME * lava_speed) + sin(p.y * 1.2 - TIME * lava_speed * 0.8);
	float pulse = 0.5 + 0.5 * sin(TIME * lava_speed * 1.5 + (p.x + p.y) * 0.4);
	// CLAMP, not max(): flow*0.5+0.5 reaches 1.5, so pow(_,3) spiked hot to ~3.4 and the
	// yellow additive below blew past 1.0 into a bloom-amplified yellow oval. Capped at 1.0.
	float hot = pow(clamp(flow * 0.5 + 0.5, 0.0, 1.0), 3.0);
	vec3 lava = base.rgb
		+ 0.24 * pulse * vec3(1.0, 0.35, 0.05)
		+ 0.28 * hot * vec3(1.0, 0.7, 0.1);

	vec3 colour = mix(water, lava, warm);
	if (shore_mask.r + shore_mask.g > 0.5) {
		vec2 snapped = (floor(world_pos / shore_pixel) + 0.5) * shore_pixel;
		float d = shore_distance(snapped - floor(world_pos / CELL) * CELL);
		// The coast itself is still: the lip is cut from noise with no TIME in it.
		float coast = d - has_lip * lip_depth * smoothstep(0.3, 0.85, noise(snapped * 0.14 + 5.3));
		// Two moving noises: one frays the foam, one staggers the waves along the
		// shore so no two stretches of beach move together.
		float fray = noise(snapped * 0.11 + vec2(TIME * 0.2, -TIME * 0.13));
		float stagger = noise(snapped * 0.025 + 17.0);

		// Shallows in three flat bands, lighter and greener toward the shore.
		float shallow = floor((1.0 - clamp(coast / shore_reach, 0.0, 1.0)) * 3.0 + 0.5) / 3.0;
		water = mix(water, water * 1.15 + vec3(0.05, 0.15, 0.13), shallow * 0.6);
		// Foam that laps up the coast and back, and a broken swell rolling in to it.
		float lap = 1.0 + 3.5 * (0.5 + 0.5 * sin(TIME * 1.7 + stagger * 6.2832));
		float foam = step(coast, lap) * step(0.3, fray);
		float swell_t = fract(TIME * 0.3 + stagger * 2.0);
		float swell_at = mix(shore_reach, lap, swell_t);
		float swell = step(abs(coast - swell_at), shore_pixel * 0.5) * step(0.45, fray)
			* sin(swell_t * 3.14159);
		water = mix(water, foam_colour, max(foam * 0.7, swell * 0.5));

		// Lava: a molten rim glowing along the crust and darker crust drifting off it.
		float rim = step(coast, 2.0 + 2.5 * pulse);
		float crust = step(0.66, noise(snapped * 0.16 + vec2(TIME * 0.05, 0.0)))
			* step(coast, shore_reach * 0.8) * (1.0 - rim);
		lava = mix(lava, vec3(0.28, 0.06, 0.03), crust * 0.7);
		lava = mix(lava, vec3(1.0, 0.86, 0.38), rim * 0.75);

		vec3 lip = lip_colour * (0.88 + 0.24 * hash(snapped));
		colour = mix(mix(water, lava, warm), lip, step(coast, 0.0));
	}

	COLOR = vec4(colour, base.a);
}
