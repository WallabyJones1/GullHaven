extends Node
## Town time. One real second is one town minute, so a whole day takes 24 minutes.
## Moves the sun and moon, tints the sky and fog, and lights lamps, windows and the
## lighthouse beam after dusk.

const MINUTES_PER_SECOND := 1.0
# hour, sky top, horizon
const SKY_KEYS := [
	[0.0, Color(0.02, 0.03, 0.09), Color(0.07, 0.09, 0.2)],
	[4.8, Color(0.02, 0.03, 0.09), Color(0.07, 0.09, 0.2)],
	[6.0, Color(0.25, 0.32, 0.6), Color(0.98, 0.6, 0.45)],
	[7.5, Color(0.3, 0.52, 0.88), Color(0.75, 0.85, 0.95)],
	[16.5, Color(0.3, 0.52, 0.88), Color(0.75, 0.85, 0.95)],
	[18.0, Color(0.28, 0.27, 0.58), Color(1.0, 0.52, 0.36)],
	[19.4, Color(0.04, 0.05, 0.14), Color(0.12, 0.12, 0.28)],
	[24.0, Color(0.02, 0.03, 0.09), Color(0.07, 0.09, 0.2)],
]

var hour := 9.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
var harbour: Node3D
var _beam_angle := 0.0
var _sky_t := 0.0
var _last_hour := -1.0


static func period(h: float) -> String:
	if h >= 5.0 and h < 7.0:
		return "dawn"
	if h >= 7.0 and h < 17.5:
		return "day"
	if h >= 17.5 and h < 19.5:
		return "dusk"
	return "night"


func setup(s: DirectionalLight3D, m: DirectionalLight3D, e: Environment, sk: ProceduralSkyMaterial, h: Node3D, start_hour: float) -> void:
	sun = s
	moon = m
	env = e
	sky = sk
	harbour = h
	hour = fmod(start_hour, 24.0)
	# Spread sky re-lighting over several frames; the sky changes slowly anyway.
	env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_apply(0.0)


func _process(delta: float) -> void:
	hour = fmod(hour + delta * MINUTES_PER_SECOND / 60.0, 24.0)
	_apply(delta)


func _apply(delta: float) -> void:
	# The sun rises in the east (+X) at 6, peaks to the south (toward the camera) at
	# noon and sets in the west at 18, so shadows fall back into the scene.
	var a := (hour - 6.0) / 12.0 * PI
	var to_sun := Vector3(cos(a), sin(a), 0.55).normalized()
	var day := smoothstep(-0.08, 0.2, to_sun.y)
	var night := 1.0 - day
	sun.light_energy = day * 1.25
	sun.shadow_enabled = day > 0.01
	if to_sun.y > -0.25:
		sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.96, 0.9), smoothstep(0.0, 0.5, to_sun.y))

	var to_moon := Vector3(-cos(a), -sin(a) * 0.9, 0.6).normalized()
	moon.light_energy = night * 0.3 * smoothstep(-0.05, 0.15, to_moon.y)
	moon.shadow_enabled = moon.light_energy > 0.02
	if to_moon.y > -0.25:
		moon.basis = Basis.looking_at(-to_moon, Vector3.UP)

	# Lamps and windows come on through dusk and stay on until dawn.
	var lamps_on := smoothstep(0.45, 0.85, night)
	for l in harbour.lamps:
		l.light_energy = lamps_on * 1.6
	for m in harbour.glow_mats:
		m.emission_energy_multiplier = lamps_on * float(m.get_meta("glow", 3.0))
	var water: ShaderMaterial = harbour.water_material
	if water:
		water.set_shader_parameter("night", night)
	var beam: SpotLight3D = harbour.beam
	if beam:
		_beam_angle += delta * 0.7
		beam.rotation = Vector3(deg_to_rad(-5.0), _beam_angle, 0.0)
		beam.light_energy = lamps_on * 8.0
		beam.visible = lamps_on > 0.01

	# The sky only needs re-tinting every half second, or straight away after a jump.
	_sky_t -= delta
	if _sky_t > 0.0 and absf(hour - _last_hour) < 0.1:
		return
	_sky_t = 0.5
	_last_hour = hour
	var top := Color()
	var horizon := Color()
	for i in SKY_KEYS.size() - 1:
		var k0: Array = SKY_KEYS[i]
		var k1: Array = SKY_KEYS[i + 1]
		var h0: float = k0[0]
		var h1: float = k1[0]
		if hour >= h0 and hour <= h1:
			var f := (hour - h0) / (h1 - h0)
			var top0: Color = k0[1]
			var hor0: Color = k0[2]
			top = top0.lerp(k1[1], f)
			horizon = hor0.lerp(k1[2], f)
			break
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon.darkened(0.15)
	sky.ground_bottom_color = top.darkened(0.6)
	env.fog_light_color = horizon.lerp(top, 0.3)
	env.ambient_light_energy = lerpf(0.35, 1.0, day)
