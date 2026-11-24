shader_type spatial;
// Gullhaven's sea. Colour comes from how deep the water is (read back from the depth
// buffer), the shallows show the seabed through them, foam gathers along every shore
// and post, and fish shadows swim underneath. Patterns snap to the 16 px/m texel grid
// so the water reads as pixel art next to the sprites.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform vec3 shallow_color : source_color = vec3(0.36, 0.80, 0.80);
uniform vec3 deep_color : source_color = vec3(0.08, 0.30, 0.52);
uniform vec3 foam_color : source_color = vec3(0.94, 0.98, 1.0);
uniform vec3 glow_color : source_color = vec3(0.35, 0.95, 0.85);
uniform float pixels_per_metre = 16.0;
uniform float clarity : hint_range(0.0, 1.0) = 0.82;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float wind : hint_range(0.0, 1.0) = 0.2;
uniform float rain : hint_range(0.0, 1.0) = 0.0;

// Fish shadows: x, z, length (m), heading (radians; direction = cos, sin in x, z).
uniform vec4 fish[8];
uniform int fish_count = 0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float swell(vec2 p, float t) {
	return sin(p.x * 0.55 + t * 1.1) * 0.5
		+ sin(p.y * 0.8 - t * 0.9 + p.x * 0.2) * 0.35
		+ sin((p.x + p.y) * 1.7 + t * 1.9) * 0.15;
}

vec3 view_from_depth(vec2 uv, float raw, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The web / Compatibility renderer (OpenGL): depth runs 0..1 and NDC z runs -1..1.
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw * 2.0 - 1.0, 1.0);
#else
	// Forward+ and Mobile (Godot 4.3+) use reversed-Z: the raw depth is already the NDC z.
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
#endif
	return v.xyz / v.w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += swell(world_pos.xz, TIME * (0.8 + wind * 0.6)) * (0.025 + wind * 0.07);
}

void fragment() {
	float t = TIME;
	vec2 p = (floor(world_pos.xz * pixels_per_metre) + 0.5) / pixels_per_metre;

	// How deep is it here? Rebuild the seabed's world position under this pixel.
	vec3 floor_view = view_from_depth(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(floor_view, 1.0)).xyz;
	float depth = max(world_pos.y - floor_world.y, 0.0);

	// Banded depth colour: a few flat steps, like a painted sprite.
	float shade = 1.0 - exp(-depth * 0.75);
	shade = floor(shade * 5.0 + 0.5) / 5.0;
	vec3 water = mix(shallow_color, deep_color, shade);

	// Pixel-snapped ripples tilt the normal, so sun, moon and lamps glint off the surface.
	vec2 g = vec2(
		cos(p.x * 2.3 + t * 1.4) + cos((p.x + p.y) * 1.6 - t * 1.1),
		cos(p.y * 2.7 + t * 1.7) + cos((p.x - p.y) * 1.3 + t * 0.8)) * (0.04 + wind * 0.06);
	NORMAL = normalize((VIEW_MATRIX * vec4(-g.x, 1.0, -g.y, 0.0)).xyz);

	// The seabed seen through the shallows, wobbling a little. If the wobbled sample
	// lands on something in front of the water (a post, the dock), don't bend it.
	vec2 ruv = SCREEN_UV + g * 0.05 * (1.0 - shade);
	vec3 rview = view_from_depth(ruv, texture(depth_tex, ruv).r, INV_PROJECTION_MATRIX);
	if (rview.z > VERTEX.z) {
		ruv = SCREEN_UV;
	}
	vec3 behind = texture(screen_tex, ruv).rgb;
	float see = clarity * (1.0 - shade);

	// Fish shadows: an oval body and a forked tail that wags.
	float shadow = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= fish_count) {
			break;
		}
		vec4 f = fish[i];
		float len = max(f.z, 0.1);
		vec2 rel = p - f.xy;
		float c = cos(f.w);
		float s = sin(f.w);
		vec2 l = vec2(rel.x * c + rel.y * s, -rel.x * s + rel.y * c);
		l.y += sin(t * 9.0 + l.x * 5.0 + float(i) * 1.7) * 0.05 * len * clamp(-l.x / len + 0.3, 0.0, 1.0);
		float body = length(vec2(l.x / (len * 0.5), l.y / (len * 0.17)));
		float tx = -l.x - len * 0.42;
		float tail = (tx > 0.0 && tx < len * 0.26 && abs(l.y) < tx * 0.9 + 0.02) ? 1.0 : 0.0;
		float inside = max(step(body, 1.0), tail);
		shadow = max(shadow, inside);
		rim = max(rim, step(body, 1.3) * (1.0 - inside));
	}
	float dark = shadow * mix(0.5, 0.15, night);
	water *= 1.0 - dark;
	behind *= 1.0 - dark * 1.2;

	// Foam: a lapping line where the water meets anything, and a broken second line.
	float edge = 0.2 + 0.07 * sin(t * 1.8 + p.x * 3.1 + p.y * 2.3);
	float foam = step(depth, edge);
	float band = 0.48 + 0.12 * sin(t * 1.2 + p.x * 1.3 - p.y * 0.7);
	foam = max(foam, step(abs(depth - band), 0.035) * step(0.45, hash(floor(p * 4.0))));

	// Whitecaps when it's windy, out where the water is deep.
	float caps = step(0.995 - wind * 0.025, hash(floor(p * 2.0) + floor(t * 0.8 + hash(floor(p * 2.0)) * 3.0)));
	foam = max(foam, caps * step(0.55, wind) * step(0.4, shade));

	// Rain: little rings opening on the surface.
	if (rain > 0.01) {
		vec2 cell = floor(p * 1.6);
		float seed = hash(cell);
		float age = fract(t * 1.4 + seed * 7.0);
		vec2 centre = (cell + 0.25 + 0.5 * vec2(hash(cell + 3.1), hash(cell + 7.7))) / 1.6;
		float ring = abs(length(p - centre) - age * 0.28);
		foam = max(foam, step(ring, 0.022) * (1.0 - age) * step(1.0 - rain, seed) * 0.8);
	}

	// Sparkles: sun glitter by day, a few moon flecks at night.
	float spark = step(0.9972, hash(p + floor(t * 3.0) * 0.371)) * (1.0 - foam) * (1.0 - rain);

	ALBEDO = mix(water * (1.0 - see), foam_color, foam);
	EMISSION = behind * mix(vec3(1.0), shallow_color * 1.25, 0.5) * see * (1.0 - foam)
		+ vec3(1.0, 0.97, 0.86) * spark * mix(1.4, 0.35, night)
		+ glow_color * (rim * 0.9 + shadow * 0.2) * night * 0.7;
	ROUGHNESS = mix(0.06, 0.9, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
