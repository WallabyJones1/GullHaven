extends Node3D
## Gullhaven HD-2D: a big coast to explore, from the harbour town of Gullhaven up the
## river to Willowford and Mirrorlake and out across the bay to the islands. Fish every
## kind of water, meet the townsfolk, and unlock the rest of the map as you go. Weather,
## tides and feeding frenzies all run on the web game's rules and sounds.
## Everything is assembled here in code so placeholder shapes can be swapped for
## Blender models (see res://models/README.md) without touching the scene file.

const InputSetup := preload("res://scripts/input_setup.gd")
const World := preload("res://scripts/world.gd")
const DayNight := preload("res://scripts/day_night.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Player := preload("res://scripts/player.gd")
const FishSchool := preload("res://scripts/fish_school.gd")
const Fishing := preload("res://scripts/fishing.gd")
const Hud := preload("res://scripts/hud.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Sea := preload("res://scripts/sea.gd")
const Audio := preload("res://scripts/audio.gd")
const Shop := preload("res://scripts/shop.gd")
const Town := preload("res://scripts/town.gd")
const Logbook := preload("res://scripts/logbook.gd")
const Interiors := preload("res://scripts/interiors.gd")
const Boats := preload("res://scripts/boats.gd")
const Boatyard := preload("res://scripts/boatyard.gd")
const Trade := preload("res://scripts/trade.gd")
const HutBuild := preload("res://scripts/hut_build.gd")
const Quests := preload("res://scripts/quests.gd")
const MapScreen := preload("res://scripts/map_screen.gd")

var env: Environment
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var harbour: Node3D  # the world (other scripts still call it harbour)
var day_night: Node
var player: CharacterBody3D
var cam: Camera3D
var school: Node3D
var fishing: Node
var hud: CanvasLayer
var sea: Node
var audio: Node
var shop: CanvasLayer
var town: Node
var logbook: CanvasLayer
var interiors: Node3D
var boats: Node3D
var boatyard: CanvasLayer
var trade: CanvasLayer
var hut_build: Node3D
var quests: Node
var map_screen: CanvasLayer
var save: Dictionary
var quality_high := true
var _area := ""
var _area_t := 0.0


func _ready() -> void:
	InputSetup.setup()
	save = SaveGame.load_save()
	sea = Sea.new()
	sea.name = "Sea"
	add_child(sea)
	sea.setup(float(save.get("clock_offset", 0.0)))
	audio = Audio.new()
	audio.name = "Audio"
	add_child(audio)
	_build_environment()

	harbour = World.new()
	harbour.name = "World"
	add_child(harbour)
	harbour.load_world()
	harbour.permits = save.permits
	harbour.hut_tier = int(save.hut_tier)
	harbour.build()

	player = Player.new()
	player.name = "Player"
	player.harbour = harbour
	player.audio = audio
	add_child(player)
	player.global_position = _start_point()
	harbour.focus = player
	player.gate_blocked.connect(_on_gate_blocked)

	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	cam.terrain = harbour
	cam.setup(player, world_env.camera_attributes)
	player.cam = cam

	school = FishSchool.new()
	school.name = "FishShadows"
	add_child(school)
	school.setup(harbour)
	school.focus = player

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(sea, save)

	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)
	shop.setup(sea, save, audio, hud)

	logbook = Logbook.new()
	logbook.name = "Logbook"
	add_child(logbook)
	logbook.setup(sea, save, audio, hud)

	town = Town.new()
	town.name = "Town"
	add_child(town)
	town.setup(harbour, player, hud, audio, sea, save, shop)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, moon, env, sky_mat, harbour, sea, audio, player)

	interiors = Interiors.new()
	interiors.name = "Interiors"
	add_child(interiors)
	interiors.setup(harbour, player, cam, hud, audio, sea, save, day_night)
	town.interiors = interiors

	boats = Boats.new()
	boats.name = "Boats"
	add_child(boats)
	boats.setup(harbour, player, cam, hud, audio, save, sea)
	town.boats = boats

	boatyard = Boatyard.new()
	boatyard.name = "Boatyard"
	add_child(boatyard)
	boatyard.setup(save, audio, hud, boats, player)
	town.register_service("boatyard", boatyard.open)
	town.register_service("boatworks", boatyard.open)

	trade = Trade.new()
	trade.name = "Trade"
	add_child(trade)
	trade.setup(save, audio, hud, harbour)
	for kind in ["carpenter", "home", "salvager"]:
		town.register_service(kind, trade.open)

	hut_build = HutBuild.new()
	hut_build.name = "HutBuild"
	add_child(hut_build)
	hut_build.setup(interiors, player, cam, hud, audio, save)
	interiors.hut_build = hut_build

	quests = Quests.new()
	quests.name = "Quests"
	add_child(quests)
	quests.setup(harbour, town, hud, audio, sea, save)
	trade.quests = quests

	map_screen = MapScreen.new()
	map_screen.name = "Map"
	add_child(map_screen)
	map_screen.setup(harbour, player, hud, audio, save)
	map_screen.boats = boats
	map_screen.interiors = interiors
	interiors.map_screen = map_screen

	fishing = Fishing.new()
	fishing.name = "Fishing"
	add_child(fishing)
	fishing.setup(player, school, hud, cam, harbour, save, sea, audio, town)
	fishing.boats = boats
	boats.fishing = fishing

	if save.visited.is_empty():
		hud.toast("Welcome to Gullhaven! Walk with WASD, turn the camera with Q and E. Hold Space to cast.")
		hud.toast("Hale's Tackle on the quay sells bait and better gear. Townsfolk have requests.")
		hud.toast("Follow the coast road north to the river. The islands across the bay will need a boat.")
	_update_area(true)


func _process(delta: float) -> void:
	hud.set_clock(day_night.hour)
	_area_t -= delta
	if _area_t <= 0.0:
		_area_t = 0.5
		_update_area(false)
	if Input.is_action_just_pressed("time_skip"):
		sea.skip_hours(1.0)
		save.clock_offset = sea.offset
		hud.toast("An hour passes...")
	if Input.is_action_just_pressed("quality"):
		_set_quality(not quality_high)
	if Input.is_action_just_pressed("photo"):
		hud.visible = not hud.visible
	if Input.is_action_just_pressed("logbook") and not hud.input_blocked() and fishing.state == 0:
		logbook.open()
	if Input.is_action_just_pressed("map") and not hud.input_blocked() and fishing.state == 0:
		map_screen.open()
	# Hear a feeding frenzy bubbling as you get close to it.
	var near := 0.0
	if school.frenzy_on:
		var at: Vector2 = school.frenzy_at
		var d := Vector2(player.global_position.x, player.global_position.z).distance_to(at)
		near = clampf(1.0 - d / 16.0, 0.0, 1.0)
	audio.set_amb("bubbles", near)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if sea:
			save.clock_offset = sea.offset
		if interiors and interiors.is_inside():
			var door: Vector3 = interiors.inside.door
			save.pos = [door.x, door.y, door.z]
		elif boats and boats.aboard:
			boats.remember()
			var spot: Vector3 = boats.landing_spot()
			if spot != Vector3.INF:
				save.pos = [spot.x, spot.y, spot.z]
		elif player and player.is_on_floor():
			var p := player.global_position
			save.pos = [p.x, p.y, p.z]
		SaveGame.write(save)


func _on_gate_blocked(text: String) -> void:
	if text != "":
		hud.toast(text)
		audio.play("error", -8.0)


## Where you left off (if it's still somewhere you can stand), or the town square.
func _start_point() -> Vector3:
	var pos: Array = save.get("pos", [])
	if pos.size() == 3:
		var x := float(pos[0])
		var z := float(pos[2])
		var ground: float = harbour.height_at(x, z)
		if harbour.walkable(x, z) and ground > float(harbour.water_level_at(x, z)) - 0.3:
			return Vector3(x, maxf(float(pos[1]), ground) + 0.2, z)
	return harbour.spawn_point


## Keep track of where you are, and greet each new place with a banner.
func _update_area(first: bool) -> void:
	if interiors and interiors.is_inside():
		return
	var p := player.global_position
	day_night.sea_near = _sea_near(p)
	map_screen.mark(p)
	var place: String = harbour.area_name(p.x, p.z)
	var water := _water_near(p)
	var corner := place
	if water != "":
		corner = water if place == "" else "%s, %s" % [place, water]
	if place == _area:
		hud.show_area(corner, "", false)
		return
	_area = place
	if place == "":
		hud.show_area(corner, "", false)
		return
	var visited: Dictionary = save.visited
	var subtitle := water
	if not visited.has(place):
		visited[place] = true
		subtitle = "Discovered!" if not first else water
		if not first:
			audio.play("fanfare1", -8.0)
		SaveGame.write(save)
	hud.show_area(place, subtitle, true)
	hud.area_label.text = corner


## How close the open sea is: 1 on the coast, fading to 0 about 60 m inland.
func _sea_near(p: Vector3) -> float:
	var best := 999.0
	for i in 16:
		var a := TAU * float(i) / 16.0
		for r in [6.0, 20.0, 40.0, 60.0]:
			var x: float = p.x + cos(a) * r
			var z: float = p.z + sin(a) * r
			if r < best and harbour.is_water(x, z) and harbour.zone_at(x, z) not in ["lake", "estuary"]:
				best = r
	return clampf(1.0 - (best - 10.0) / 50.0, 0.0, 1.0)


## The fishing ground you'd cast into from here, if any.
func _water_near(p: Vector3) -> String:
	var counts := {}
	for i in 12:
		var a := TAU * float(i) / 12.0
		for r in [3.0, 8.0]:
			var x: float = p.x + cos(a) * r
			var z: float = p.z + sin(a) * r
			var zone: String = harbour.zone_at(x, z)
			if zone != "" and harbour.is_water(x, z):
				counts[zone] = int(counts.get(zone, 0)) + 1
	var best := ""
	var most := 0
	for zone in counts:
		if int(counts[zone]) > most:
			most = int(counts[zone])
			best = zone
	if best == "":
		return ""
	var z: Dictionary = sea.zones.get(best, {})
	return str(z.get("n", best))


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
