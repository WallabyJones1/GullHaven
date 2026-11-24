shader_type spatial;
// Plants: camera-facing pixel sprites (turning on the vertical axis) that sway in the wind.
// The sway grows toward the top of the sprite and snaps to whole texels, so it stays pixel art.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_nearest;
uniform float wind = 0.3;       // set by the world each frame from the weather
uniform float sway = 1.0;       // how much this kind of plant bends (0 for rocks)
uniform float texel = 0.0625;   // metres per texture pixel

void vertex() {
	// sway in the plane of the sprite, more at the top
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float gust = sin(TIME * 1.7 + phase) + 0.35 * sin(TIME * 4.3 + phase * 2.1);
	float bend = (1.0 - UV.y) * (1.0 - UV.y) * sway * wind * 0.18 * gust;
	VERTEX.x += round(bend / texel) * texel;
	// billboard around Y, keeping the instance's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
