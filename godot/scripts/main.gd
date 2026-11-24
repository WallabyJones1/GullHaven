extends Node3D
## Gullhaven HD-2D, Phase 0: one harbour, one fisher, the cast and the fight.
## Everything is assembled here in code so placeholder shapes can be swapped for
## Blender models (see res://models/README.md) without touching the scene file.

const InputSetup := preload("res://scripts/input_setup.gd")
const Harbour := preload("res://scripts/harbour.gd")
const DayNight := preload("res://scripts/day_night.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Player := preload("res://scripts/player.gd")
const FishSchool := preload("res://scripts/fish_school.gd")
const Fishing := preload("res://scripts/fishing.gd")
const Hud := preload("res://scripts/hud.gd")
const SaveGame := preload("res://scripts/save_game.gd")

var env: Environment
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var harbour: Node3D
var day_night: Node
var player: CharacterBody3D
var cam: Camera3D
var school: Node3D
var fishing: Node
var hud: CanvasLayer
var save: Dictionary
var quality_high := true


func _ready() -> void:
	InputSetup.setup()
	save = SaveGame.load_save()
	_build_environment()

	harbour = Harbour.new()
	harbour.name = "Harbour"
	add_child(harbour)
	harbour.build()

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = harbour.spawn_point

	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	cam.setup(player, world_env.camera_attributes)

	school = FishSchool.new()
	school.name = "FishShadows"
	add_child(school)
	school.setup(harbour)

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, env, sky_mat, harbour, save.get("hour", 9.0))

	fishing = Fishing.new()
	fishing.name = "Fishing"
	add_child(fishing)
	fishing.setup(player, school, hud, cam, harbour, save)

	hud.set_shells(save.shells)
	hud.set_catches(save.log.size())
	hud.toast("Welcome to Gullhaven. Walk with WASD, face the water and hold E to cast.")


func _process(_delta: float) -> void:
	hud.set_clock(day_night.hour)
	if Input.is_action_just_pressed("time_skip"):
		day_night.hour = fmod(day_night.hour + 1.0, 24.0)
	if Input.is_action_just_pressed("quality"):
		_set_quality(not quality_high)
	if Input.is_action_just_pressed("photo"):
		hud.visible = not hud.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save.hour = day_night.hour if day_night else 9.0
		SaveGame.write(save)


# --- lighting and the HD-2D look -------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	# Bloom: lamps, windows and sun glints bleed softly, a big part of the HD-2D feel.
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Soft contact shadows where buildings meet the ground.
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6

	# Distance haze so the far side of the harbour sits back.
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.9)
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.4

	# Light shafts through lamp light at night (desktop "High" quality).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.9, 0.92, 1.0)

	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04

	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env

	# Tilt-shift depth of field: the diorama look.
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 24.0
	attr.dof_blur_far_transition = 16.0
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = 7.0
	attr.dof_blur_near_transition = 4.0
	attr.dof_blur_amount = 0.1
	world_env.camera_attributes = attr
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 50.0
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)


func _set_quality(high: bool) -> void:
	quality_high = high
	var attr := world_env.camera_attributes as CameraAttributesPractical
	attr.dof_blur_far_enabled = high
	attr.dof_blur_near_enabled = high
	env.ssao_enabled = high
	env.volumetric_fog_enabled = high
	sun.shadow_blur = 1.5 if high else 0.5
	hud.toast("Quality: " + ("High" if high else "Low"))
