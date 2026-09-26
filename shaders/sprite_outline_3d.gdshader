shader_type spatial;
// A dark silhouette behind a billboard sprite, matching the 2D SpriteOutline and
// the JS/native clients' 8-direction black stroke -- but in a single pass. Where
// the sprite is transparent yet a neighbouring texel (within the atlas region) is
// opaque, paint the outline colour; where the sprite is opaque, draw it normally.
//
// Runs as a Sprite3D material_override: the node still builds the quad + UVs (UVs
// are baked into the sprite's atlas region), so we sample the full sheet at UV and
// clamp neighbour taps to the region so adjacent atlas cells never bleed in.
//
// The override replaces the Sprite3D's own material, which is what did the
// billboarding, so vertex() re-does the standard keep-scale billboard (Godot 4 has
// no billboard render_mode for custom spatial shaders).
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // atlas-UV min.xy, max.zw
uniform vec2 texel = vec2(0.0);                  // 1.0 / sheet size
uniform float thickness = 1.0;                   // outline width, in texels
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform vec4 tint : source_color = vec4(1.0);
uniform bool outline_on = true;

const vec2 DIRS[8] = {
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0)
};

void vertex() {
	// Standard keep-scale billboard: face the camera, preserve the node's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec4 base = texture(sheet, UV) * tint;
	if (base.a > 0.5) {
		ALBEDO = base.rgb;
		ALPHA = base.a;
	} else if (outline_on) {
		float ring = 0.0;
		for (int i = 0; i < 8; i++) {
			vec2 nuv = clamp(UV + DIRS[i] * texel * thickness, region.xy, region.zw);
			ring = max(ring, texture(sheet, nuv).a);
		}
		if (ring > 0.5) {
			ALBEDO = outline_color.rgb;
			ALPHA = outline_color.a;
		} else {
			ALPHA = 0.0;
		}
	} else {
		ALPHA = 0.0;
	}
}
