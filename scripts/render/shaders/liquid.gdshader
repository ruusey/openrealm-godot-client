shader_type canvas_item;

// Animates the chunk-cached water/lava tiles entirely on the GPU: the layer is
// drawn once (like the ground) and this runs every frame off TIME, so an ocean or
// a lava lake moves for free. Water vs lava is told apart from the base pixel
// (lava reads warm, water cool) so one material covers both. No TEXTURE UV is
// offset -- that would bleed across the atlas -- the motion is added to the colour.

uniform float water_speed : hint_range(0.0, 6.0) = 1.5;
uniform float lava_speed : hint_range(0.0, 6.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) {
		discard;
	}
	float warm = clamp((base.r - base.b) * 3.0, 0.0, 1.0);   // lava ~1, water ~0
	// Screen-space so the pattern is continuous across tile seams (no per-tile grid).
	vec2 p = FRAGCOORD.xy * 0.04;

	// Water: moving ripple bands plus a brighter scrolling caustic streak.
	float ripple = sin(p.x * 1.3 + p.y * 0.7 + TIME * water_speed)
		+ sin(p.x * 0.6 - p.y * 1.1 - TIME * water_speed * 0.7);
	float caustic = pow(max(sin(p.x - p.y * 0.5 + TIME * water_speed * 1.3), 0.0), 6.0);
	vec3 water = base.rgb
		+ 0.14 * ripple * vec3(0.3, 0.6, 1.0)
		+ 0.35 * caustic * vec3(0.6, 0.9, 1.0);

	// Lava: strong glow pulse plus moving hot cracks pushing toward yellow.
	float flow = sin(p.x * 0.8 + TIME * lava_speed) + sin(p.y * 1.2 - TIME * lava_speed * 0.8);
	float pulse = 0.5 + 0.5 * sin(TIME * lava_speed * 1.5 + (p.x + p.y) * 0.4);
	float hot = pow(max(flow * 0.5 + 0.5, 0.0), 3.0);
	vec3 lava = base.rgb
		+ 0.30 * pulse * vec3(1.0, 0.35, 0.05)
		+ 0.45 * hot * vec3(1.0, 0.7, 0.1);

	COLOR = vec4(mix(water, lava, warm), base.a);
}
