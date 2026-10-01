shader_type canvas_item;

// Animates the chunk-cached water/lava tiles entirely on the GPU: the layer is
// drawn once (like the ground) and this runs every frame off TIME, so an ocean or
// a lava lake moves for free. Water vs lava is told apart from the base pixel
// (lava reads warm, water cool) so one material covers both. No TEXTURE UV is
// offset -- that would bleed across the atlas -- the motion is added to the colour.

uniform float water_speed : hint_range(0.0, 4.0) = 1.2;
uniform float lava_speed : hint_range(0.0, 4.0) = 0.7;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) {
		discard;
	}
	float warm = clamp((base.r - base.b) * 3.0, 0.0, 1.0);   // lava ~1, water ~0
	// Screen-space so the pattern is continuous across tile seams (no per-tile grid).
	vec2 p = FRAGCOORD.xy * 0.03;
	float wave = sin(p.x + TIME * water_speed) + sin(p.y * 1.3 - TIME * water_speed * 0.8);
	float lava_pulse = 0.5 + 0.5 * sin(TIME * lava_speed + (p.x + p.y) * 0.5);
	vec3 col = base.rgb;
	col += (1.0 - warm) * (0.06 * wave) * vec3(0.4, 0.7, 1.0);     // cool shimmer
	col += warm * (0.18 * lava_pulse) * vec3(1.0, 0.45, 0.1);      // warm flowing glow
	COLOR = vec4(col, base.a);
}
