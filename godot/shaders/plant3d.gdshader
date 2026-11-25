shader_type spatial;
// 3D plants (the Blender models): the canopy, fronds and stems sway in the wind, more the
// higher up they are, and the trunk stays put. Pixel-art textures, nearest filtered.
// Anything between the camera and you is screen-door faded so a tree never hides you.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_nearest_mipmap;
uniform vec4 colour : source_color = vec4(1.0);
uniform bool use_tex = true;
uniform float wind = 0.3;    // set by the world each frame from the weather
uniform float sway = 1.0;    // how much this kind of plant bends (0 for rocks)
uniform float height = 6.0;  // the model's height, so the bend grows toward the top
uniform vec3 focus = vec3(0.0, -1000.0, 0.0);  // the player, for the see-through fade

varying vec3 world_pos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float gust = sin(TIME * 1.7 + phase) + 0.35 * sin(TIME * 4.3 + phase * 2.1);
	float k = clamp(VERTEX.y / height, 0.0, 1.2);
	float bend = k * k * sway * wind * 0.22 * gust * height * 0.12;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.5 * sin(phase * 3.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// screen-door fade near the line from the camera to you, and right in front of the lens
	vec3 pv = (VIEW_MATRIX * vec4(focus + vec3(0.0, 0.9, 0.0), 1.0)).xyz;
	float fade = 0.0;
	if (pv.z < -0.5 && VERTEX.z > pv.z + 0.6) {
		vec2 a = VERTEX.xy / -VERTEX.z;
		vec2 b = pv.xy / -pv.z;
		fade = 1.0 - smoothstep(0.12, 0.3, length((a - b) * vec2(1.0, 1.3)));
	}
	fade = max(fade, 1.0 - smoothstep(3.0, 7.0, -VERTEX.z));
	if (fade > 0.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) & ivec2(3);
		int idx = p.x + p.y * 4;
		float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (fade * 0.8 * 16.0 > bayer[idx] + 0.5) {
			discard;
		}
	}
	vec4 c = use_tex ? texture(tex, UV) * colour : colour;
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
