shader_type spatial;
// Gullhaven's ground. A material map (one byte per metre, from tools/godot_world.py)
// picks grass, sand, rock, dirt, cobbles, forest floor, mud or pebbles; the lookup is
// jittered per texel so borders come out crisp and ragged like hand-placed pixel art.
// Steep faces turn to rock, projected from the side so cliffs don't smear.
render_mode diffuse_burley, cull_disabled;

uniform sampler2DArray textures : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D material_map : filter_nearest, repeat_disable;
uniform vec2 world_size = vec2(1280.0, 1024.0);
uniform float pixels_per_metre = 16.0;
uniform int rock_layer = 2;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 texel = floor(world_pos.xz * pixels_per_metre);
	vec2 jitter = vec2(hash(texel), hash(texel + 17.31)) - 0.5;
	vec2 cell = floor(world_pos.xz * 4.0);
	vec2 mjit = (vec2(hash(cell + 3.7), hash(cell + 9.1)) - 0.5) * 0.9 + jitter * 0.35;
	vec2 muv = (world_pos.xz + mjit) / world_size;
	float layer = floor(texture(material_map, muv).r * 255.0 + 0.5);
	vec2 uv = world_pos.xz / 4.0;
	float steep = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	if (steep > 0.42 + (hash(cell) - 0.5) * 0.08) {
		layer = float(rock_layer);
		uv = (abs(world_normal.x) > abs(world_normal.z) ? world_pos.zy : world_pos.xy) / 4.0;
	}
	vec3 col = texture(textures, vec3(uv, layer)).rgb;
	// a faint darkening in creases keeps the terraces readable
	col *= mix(0.86, 1.0, clamp(world_normal.y * 1.4 - 0.2, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
