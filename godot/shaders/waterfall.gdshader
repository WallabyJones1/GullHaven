shader_type spatial;
// The falls below Mirrorlake: pixel-snapped streaks of white water pouring down.
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.45, 0.7, 0.85);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float speed = 1.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * vec2(64.0, 176.0));
	float column = hash(vec2(px.x, 0.0));
	float flow = fract(px.y / 176.0 * 6.0 - TIME * speed * (0.7 + column * 0.6) + column);
	float streak = step(0.62, flow) * step(0.3, hash(vec2(px.x, floor(px.y / 6.0))));
	vec3 col = mix(deep_color, foam_color, streak);
	// foam where it hits the river
	float bottom = smoothstep(0.82, 1.0, UV.y);
	col = mix(col, foam_color, bottom * step(0.4, hash(px + floor(TIME * 6.0))));
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = col;
	ALPHA = 0.88 * edge;
}
