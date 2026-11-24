extends Node
## Time, weather and tide, all read from the sea's clock (sea.gd), so they match the web
## game: one real second is one town minute, the weather turns every four town hours and
## the tide every six. Moves the sun and moon, tints the sky and fog, lights lamps and
## windows after dusk, raises and lowers the sea, rains, storms (with lightning) and
## fogs, and picks the music and ambience to match.

const TIDE_RANGE := 0.3  # metres either side of mean sea level
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
# How grey and dark each kind of weather makes the day (0 = clear).
const OVERCAST := {"calm": 0.0, "windy": 0.15, "rain": 0.6, "fog": 0.45, "storm": 0.85}

var hour := 9.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
var harbour: Node3D
var sea: Node
var audio: Node
var focus: Node3D  # the rain follows this (the player)
var indoor := false  # inside a building: no sun, no rain, muffled weather
var sea_near := 1.0  # how close the open sea is (0 far inland), for the sound of waves
var _beam_angle := 0.0
var _sky_t := 0.0
var _last_hour := -1.0
var _overcast := 0.0
var _fog := 0.0
var _rain_amount := 0.0
var _rain: GPUParticles3D
var _flash: DirectionalLight3D
var _flash_t := 0.0
var _next_flash := 8.0
var _thunder_in := -1.0
var _gull_in := 6.0


static func period(h: float) -> String:
	if h >= 5.0 and h < 7.0:
		return "dawn"
	if h >= 7.0 and h < 17.5:
		return "day"
	if h >= 17.5 and h < 19.5:
		return "dusk"
	return "night"


func setup(s: DirectionalLight3D, m: DirectionalLight3D, e: Environment, sk: ProceduralSkyMaterial, h: Node3D, se: Node, a: Node, follow: Node3D) -> void:
	sun = s
	moon = m
	env = e
	sky = sk
	harbour = h
	sea = se
	audio = a
	focus = follow
	# Spread sky re-lighting over several frames; the sky changes slowly anyway.
	env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_build_rain()
	_flash = DirectionalLight3D.new()
	_flash.light_color = Color(0.85, 0.9, 1.0)
	_flash.light_energy = 0.0
	_flash.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	add_child(_flash)
	var start: Dictionary = sea.env
	_overcast = float(OVERCAST.get(start.sky, 0.0))
	_fog = 1.0 if start.sky == "fog" else 0.0
	_apply(0.0)


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	var E: Dictionary = sea.env
	hour = float(E.hour)
	var sky_kind := str(E.sky)
	var blend := 1.0 if delta <= 0.0 else minf(delta * 0.15, 1.0)  # weather eases in over a few seconds
	_overcast = lerpf(_overcast, float(OVERCAST.get(sky_kind, 0.0)), blend)
	_fog = lerpf(_fog, 1.0 if sky_kind == "fog" else 0.0, blend)
	var rain_goal := 1.0 if sky_kind == "storm" else (0.55 if sky_kind == "rain" else 0.0)
	_rain_amount = lerpf(_rain_amount, rain_goal, blend)

	# The sun rises in the east (+X) at 6, peaks to the south (toward the camera) at
	# noon and sets in the west at 18, so shadows fall back into the scene.
	var a := (hour - 6.0) / 12.0 * PI
	var to_sun := Vector3(cos(a), sin(a), 0.55).normalized()
	var day := smoothstep(-0.08, 0.2, to_sun.y)
	var night := 1.0 - day
	sun.light_energy = day * 1.25 * (1.0 - _overcast * 0.7)
	sun.shadow_enabled = day > 0.01
	if to_sun.y > -0.25:
		sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.96, 0.9), smoothstep(0.0, 0.5, to_sun.y))

	var to_moon := Vector3(-cos(a), -sin(a) * 0.9, 0.6).normalized()
	var moonlight := 0.45 if E.moon == "fullmoon" else (0.12 if E.moon == "newmoon" else 0.3)
	moon.light_energy = night * moonlight * smoothstep(-0.05, 0.15, to_moon.y) * (1.0 - _overcast * 0.8)
	moon.shadow_enabled = moon.light_energy > 0.02
	if to_moon.y > -0.25:
		moon.basis = Basis.looking_at(-to_moon, Vector3.UP)
	if indoor:
		sun.light_energy = 0.0
		sun.shadow_enabled = false
		moon.light_energy = 0.0
		moon.shadow_enabled = false

	# Lamps and windows come on through dusk (and in dark weather) and stay on until dawn.
	var lamps_on := clampf(smoothstep(0.45, 0.85, night) + _overcast * 0.5 * day, 0.0, 1.0)
	for l in harbour.lamps:
		l.light_energy = lamps_on * 1.6
	for m in harbour.glow_mats:
		m.emission_energy_multiplier = lamps_on * float(m.get_meta("glow", 3.0))
	var water: ShaderMaterial = harbour.water_material
	if water:
		water.set_shader_parameter("night", night)
		water.set_shader_parameter("wind", float(E.wind))
		water.set_shader_parameter("rain", _rain_amount)
	var beam: SpotLight3D = harbour.beam
	if beam:
		_beam_angle += delta * 0.7
		beam.rotation = Vector3(deg_to_rad(-5.0), _beam_angle, 0.0)
		beam.light_energy = lamps_on * (16.0 if harbour.golden else 8.0)
		beam.visible = lamps_on > 0.01

	# The tide: high at midnight and noon, low at six.
	harbour.sea_level = float(E.tide) * TIDE_RANGE

	# Fog and haze (indoors, just a touch).
	env.fog_density = lerpf(0.0035, 0.045, _fog) + _rain_amount * 0.006
	env.volumetric_fog_density = lerpf(0.008, 0.035, _fog) + _rain_amount * 0.01
	if indoor:
		env.fog_density = 0.002
		env.volumetric_fog_density = 0.012

	_update_rain(delta)
	_update_lightning(delta, sky_kind)
	_update_sound(delta, E, night)

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
	# Bad weather greys the sky out.
	var grey := Color(0.42, 0.45, 0.5) * (0.25 + 0.75 * day)
	top = top.lerp(grey, _overcast * 0.8)
	horizon = horizon.lerp(grey * 1.15, _overcast * 0.8)
	if _fog > 0.01:
		horizon = horizon.lerp(Color(0.75, 0.78, 0.8) * (0.3 + 0.7 * day), _fog * 0.7)
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon.darkened(0.15)
	sky.ground_bottom_color = top.darkened(0.6)
	env.fog_light_color = horizon.lerp(top, 0.3)
	env.ambient_light_energy = lerpf(0.35, 1.0, day) * (1.0 - _overcast * 0.35)


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 2400
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.local_coords = true
	_rain.visibility_aabb = AABB(Vector3(-20.0, -16.0, -20.0), Vector3(40.0, 32.0, 40.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16.0, 0.5, 14.0)
	pm.direction = Vector3(0.15, -1.0, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0.0, -6.0, 0.0)
	_rain.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	drop.material = mat
	_rain.draw_pass_1 = drop
	_rain.emitting = false
	add_child(_rain)


func _update_rain(_delta: float) -> void:
	if focus:
		_rain.global_position = focus.global_position + Vector3(0.0, 12.0, 2.0)
	_rain.emitting = _rain_amount > 0.05 and not indoor
	_rain.amount_ratio = clampf(_rain_amount, 0.0, 1.0)


func _update_lightning(delta: float, sky_kind: String) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.light_energy = 3.0 * maxf(_flash_t / 0.18, 0.0) * (1.0 if fmod(_flash_t, 0.08) > 0.03 else 0.4)
	else:
		_flash.light_energy = 0.0
	if _thunder_in > 0.0:
		_thunder_in -= delta
		if _thunder_in <= 0.0:
			audio.play("thunder", -2.0, 1.0, 0.15)
	if sky_kind != "storm":
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(7.0, 16.0)
		_flash_t = 0.18
		_thunder_in = randf_range(0.4, 1.6)


func _update_sound(delta: float, E: Dictionary, night: float) -> void:
	var sky_kind := str(E.sky)
	var wind := float(E.wind)
	if sky_kind == "storm":
		audio.set_music("storm")
	elif period(hour) == "dawn" or period(hour) == "day":
		audio.set_music("day")
	else:
		audio.set_music("night")
	var muffle := 0.25 if indoor else 1.0
	audio.set_amb("waves", (0.75 + wind * 0.4) * sea_near * muffle)
	audio.set_amb("wind", clampf((wind - 0.3) * 1.4, 0.0, 1.0) * muffle)
	audio.set_amb("rain", _rain_amount * (0.45 if indoor else 1.0))
	audio.set_amb("crickets", night * (1.0 - _rain_amount) * (1.0 - _fog * 0.5) * muffle)
	# Gulls call by day when it isn't pouring.
	_gull_in -= delta
	if _gull_in <= 0.0:
		_gull_in = randf_range(9.0, 24.0)
		if night < 0.5 and _rain_amount < 0.3 and not indoor and sea_near > 0.3:
			audio.play("gull", randf_range(-14.0, -8.0), randf_range(0.9, 1.15))
