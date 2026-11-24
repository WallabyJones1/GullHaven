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
const Mystery := preload("res://scripts/mystery.gd")
const SideQuests := preload("res://scripts/sidequests.gd")
const Companion := preload("res://scripts/companion.gd")
const Minigames := preload("res://scripts/minigames.gd")
const Journal := preload("res://scripts/journal.gd")
const Ambient := preload("res://scripts/ambient.gd")
const Menus := preload("res://scripts/menus.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Bag := preload("res://scripts/bag.gd")
const Progress := preload("res://scripts/progress.gd")
const Kit := preload("res://scripts/kit.gd")
const Spearfishing := preload("res://scripts/spearfishing.gd")
const Story := preload("res://scripts/story.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
const Music := preload("res://scripts/music.gd")
const Opening := preload("res://scripts/opening.gd")

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
var mystery: Node3D
var sidequests: Node3D
var companion: Node3D
var minigames: Node3D
var journal: CanvasLayer
var ambient: Node3D
var menus: CanvasLayer
var dialogue: CanvasLayer
var bag: CanvasLayer
var progress: Node
var kit: Node3D
var spear: CanvasLayer
var story: Node3D
var wardrobe: CanvasLayer
var music: Node
var opening: CanvasLayer
var _first_time := false
var skip_save := false  # starting a new game: don't write the old save back on the way out
var save: Dictionary
var quality_high := true
var _area := ""
var _area_t := 0.0


func _ready() -> void:
	InputSetup.setup()
	var glyphs := Glyphs.new()
	glyphs.name = "Glyphs"
	add_child(glyphs)
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

	progress = Progress.new()
	progress.name = "Progress"
	add_child(progress)
	progress.setup(save, hud, audio)

	dialogue = Dialogue.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	dialogue.setup(hud, audio, player)

	wardrobe = Wardrobe.new()
	wardrobe.name = "Wardrobe"
	add_child(wardrobe)
	wardrobe.setup(save, hud, audio, player)
	wardrobe.apply()

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
	town.dialogue = dialogue
	town.register_service("outfitter", wardrobe.open_shop)
	town.progress = progress
	shop.progress = progress

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
	fishing.progress = progress
	boats.fishing = fishing
	boats.progress = progress
	quests.progress = progress

	mystery = Mystery.new()
	mystery.name = "Mystery"
	add_child(mystery)
	mystery.setup(harbour, player, hud, audio, sea, save, town)
	interiors.mystery = mystery
	mystery.progress = progress
	fishing.specials.append(mystery.special_catch)
	fishing.catch_hooks.append(mystery.on_catch)
	if bool(save.mystery.get("restored", false)):
		harbour.restore_light()

	sidequests = SideQuests.new()
	sidequests.name = "SideQuests"
	add_child(sidequests)
	sidequests.setup(harbour, player, hud, audio, save, town)
	sidequests.progress = progress

	companion = Companion.new()
	companion.name = "Companion"
	add_child(companion)
	companion.setup(harbour, player, cam, hud, audio, sea, save, town)
	companion.fishing = fishing
	companion.boats = boats
	town.companion = companion

	minigames = Minigames.new()
	minigames.name = "Minigames"
	add_child(minigames)
	minigames.setup(harbour, player, hud, audio, save, boats, interiors)
	interiors.minigames = minigames
	minigames.progress = progress

	kit = Kit.new()
	kit.name = "Kit"
	add_child(kit)
	kit.setup(harbour, player, cam, hud, audio, sea, save, town)
	kit.fishing = fishing
	kit.boats = boats
	kit.school = school
	kit.dialogue = dialogue
	kit.progress = progress
	kit.interiors = interiors
	spear = Spearfishing.new()
	spear.name = "Spearfishing"
	add_child(spear)
	spear.setup(kit, fishing, sea, hud, audio)
	kit.spear = spear

	for prov in [boats, mystery, sidequests, companion, minigames, kit]:
		town.providers.append(prov)

	journal = Journal.new()
	journal.name = "Journal"
	add_child(journal)
	journal.setup(save, sea, hud, audio)
	journal.mystery = mystery
	journal.sidequests = sidequests
	journal.minigames = minigames
	journal.companion = companion

	bag = Bag.new()
	bag.name = "Bag"
	add_child(bag)
	bag.setup(save, sea, hud, audio)
	bag.extra_sections.append(_bag_kit)

	story = Story.new()
	story.name = "Story"
	add_child(story)
	story.setup(harbour, player, hud, audio, sea, save, town)
	story.fishing = fishing
	story.interiors = interiors
	story.dialogue = dialogue
	story.progress = progress
	story.map_screen = map_screen
	story.mystery = mystery
	story.start()
	journal.story = story

	ambient = Ambient.new()
	ambient.name = "Ambient"
	add_child(ambient)
	ambient.setup(harbour, player, cam, audio, sea, boats)
	ambient.school = school

	menus = Menus.new()
	menus.name = "Menus"
	add_child(menus)
	menus.setup(self, hud, audio, player, cam)
	set_quality(bool(menus.settings.quality), false)

	opening = Opening.new()
	opening.name = "Opening"
	add_child(opening)
	opening.setup(self)

	music = Music.new()
	music.name = "Music"
	add_child(music)
	music.setup(self, audio)

	_first_time = save.visited.is_empty()
	_update_area(true)
	if "--smoke" in OS.get_cmdline_user_args():
		# the build machine's tour of the game (see smoke_test.gd)
		var smoke: Node = load("res://scripts/smoke_test.gd").new()
		smoke.name = "SmokeTest"
		add_child(smoke)
		smoke.call("setup", self)
	if Menus.fresh_start:
		# New game from the menu: straight into making your fisher
		Menus.fresh_start = false
		menus.call_deferred("begin_new")
	elif not bool(menus.settings.get("seen_opening", false)):
		# the very first time: the opening, then the menu
		menus.settings["seen_opening"] = true
		menus._save_settings()
		menus.mode = "intro"
		opening.play(menus.show_title)
	else:
		menus.show_title()


func _process(delta: float) -> void:
	hud.set_clock(day_night.hour)
	_area_t -= delta
	if _area_t <= 0.0:
		_area_t = 0.5
		_update_area(false)
		school.wait_mul = progress.less("patience")
	_update_controls()
	if Input.is_action_just_pressed("time_skip"):
		sea.skip_hours(1.0)
		save.clock_offset = sea.offset
		hud.toast("An hour passes...")
	if Input.is_action_just_pressed("quality"):
		set_quality(not quality_high)
		menus.settings.quality = quality_high
		menus._save_settings()
	if Input.is_action_just_pressed("photo"):
		hud.visible = not hud.visible
	if Input.is_action_just_pressed("logbook") and not hud.input_blocked() and fishing.state == 0:
		logbook.open()
	if Input.is_action_just_pressed("map") and not hud.input_blocked() and fishing.state == 0:
		map_screen.open()
	if Input.is_action_just_pressed("journal") and not hud.input_blocked() and fishing.state == 0:
		journal.open()
	if Input.is_action_just_pressed("bag") and not hud.input_blocked() and fishing.state == 0:
		bag.open()
	if Input.is_action_just_pressed("menu") and not hud.input_blocked() and fishing.state == 0 and menus.mode == "":
		# Esc on a keyboard is also "back": aboard by a jetty it steps you ashore instead
		var esc_lands: bool = Input.is_action_just_pressed("cancel") and bool(boats.aboard) and bool(boats.can_land())
		if not esc_lands and not player.swimming:
			menus.open_pause()
	# Hear a feeding frenzy bubbling as you get close to it.
	var near := 0.0
	if school.frenzy_on:
		var at: Vector2 = school.frenzy_at
		var d := Vector2(player.global_position.x, player.global_position.z).distance_to(at)
		near = clampf(1.0 - d / 16.0, 0.0, 1.0)
	audio.set_amb("bubbles", near)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


## Write the save, remembering where you're standing (or the door, or your mooring).
func save_now() -> void:
	if skip_save:
		return
	if sea:
		save.clock_offset = sea.offset
	if interiors and interiors.is_inside():
		var door: Vector3 = interiors.inside.door
		save.pos = [door.x, door.y, door.z]
	elif interiors and bool(interiors.on_gallery):
		var ldoor: Vector3 = interiors._lighthouse.door
		save.pos = [ldoor.x, ldoor.y, ldoor.z]
	elif boats and boats.aboard:
		boats.remember()
		var spot: Vector3 = boats.landing_spot()
		if spot != Vector3.INF:
			save.pos = [spot.x, spot.y, spot.z]
	elif player and player.is_on_floor():
		var p := player.global_position
		save.pos = [p.x, p.y, p.z]
	SaveGame.write(save)


## The strip of what you can do right now, at the bottom of the screen.
func _update_controls() -> void:
	if menus.mode != "" or hud.modal:
		hud.set_controls([])
		return
	var pairs: Array = []
	match int(fishing.state):
		0:
			if boats.aboard:
				pairs = [["move", "Steer"], ["action", "Cast"], ["bait", "Bait"]]
				if kit.has_any():
					pairs.append(["tool", "Lines in" if kit.troll_on else "Kit"])
				if boats.can_land():
					pairs.append(["cancel", "Step ashore"])
				pairs.append_array([["map", "Map"], ["menu", "Menu"]])
			elif player.swimming:
				pairs = [["move", "Swim to shore"], ["menu", "Menu"]]
			elif interiors.is_inside():
				pairs = [["move", "Walk"], ["action", "Use"], ["bag", "Bag"], ["journal", "Journal"], ["menu", "Menu"]]
				if interiors.in_hut():
					pairs.insert(2, ["build", "Arrange"])
			else:
				pairs = [["move", "Walk"], ["camera", "Camera"], ["zoom", "Zoom"], ["action", "Cast / use"], ["bait", "Bait"]]
				if kit.has_any():
					pairs.append(["tool", "Kit"])
				pairs.append_array([["bag", "Bag"], ["journal", "Journal"], ["map", "Map"], ["menu", "Menu"]])
		1:
			pairs = [["action", "Let go to cast"]]
		2, 3:
			pairs = [["action", "Strike when it bites"], ["cancel", "Reel in"]]
		4:
			pairs = [["action", "Strike!"]]
		5:
			pairs = [["action", "Hold to reel"], ["move", "Steer against runs"]]
		6:
			pairs = [["action", "Continue"]]
	hud.set_controls(pairs)


## The bag's Kit section: pots, net, trolling rig, speargun.
func _bag_kit() -> String:
	var k: Dictionary = save.kit
	if k.is_empty():
		return ""
	var out := "[color=#ffd24d][b]Kit[/b][/color]\n"
	if int(k.get("pot", 0)) > 0:
		out += "Crab pots: %d (%d out in the water)\n" % [int(k.pot), (save.pots as Array).size()]
	for pair in [["net", "Cast net"], ["troll", "Trolling rig"], ["spear", "Snorkel and speargun"]]:
		if int(k.get(pair[0], 0)) > 0:
			out += "%s\n" % pair[1]
	return out


## Under Continue on the main menu: where your story's got to, your level and Shells.
func save_summary() -> String:
	var bits: Array[String] = []
	if story:
		bits.append(str(story.summary()))
	if progress:
		bits.append("Fisher level %d" % int(progress.level()))
	bits.append("%d Shells" % int(save.shells))
	var found: Dictionary = save.log
	bits.append("%d in your Logbook" % found.size())
	return "   ".join(bits)


## The line under the game menu's heading: day, time, where you are, your shells.
func status_line() -> String:
	var e: Dictionary = sea.env
	var hour := float(e.get("hour", 9.0))
	var h := int(hour)
	var h12 := 12 if h % 12 == 0 else h % 12
	var place := _area if _area != "" else "Out on the water"
	if interiors.is_inside():
		place = "Indoors"
	var day := int(floor(float(e.get("t", 0.0)) / 1440.0)) % 7
	var days := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	return "%s, %d:%02d %s   %s   %s   %d shells" % [days[day], h12, int((hour - h) * 60.0), "am" if h < 12 else "pm",
		str(e.get("season", "")).capitalize(), place, int(save.shells)]


## The Fisher page of the game menu: how you're getting on.
func fisher_text() -> String:
	var out := ""
	var found: Dictionary = save.log
	var species := 0
	var biggest := ""
	var big_cm := 0.0
	for id in found:
		var rec: Dictionary = found[id]
		if int(rec.get("count", 0)) > 0:
			species += 1
		var e: Dictionary = sea.by_id.get(id, {})
		if float(rec.get("best", 0.0)) > big_cm and str(e.get("cat", "")) in ["fish", "legend"]:
			big_cm = float(rec.get("best", 0.0))
			biggest = str(e.get("n", id))
	var total := 0
	for e: Dictionary in sea.items:
		var cp: Dictionary = e.get("cp", {})
		var flags: Array = cp.get("flags", []) if cp.get("flags") is Array else []
		if not flags.has("quest"):
			total += 1
	var stats: Dictionary = save.stats
	out += "[color=#ffd24d][b]The catch[/b][/color]\n"
	out += "Logbook: %d of %d found\n" % [species, total]
	out += "Fish landed: %d   Junk hauled: %d   Finds dug up: %d\n" % [int(stats.get("catches", 0)), int(stats.get("junk", 0)), int(stats.get("finds", 0))]
	out += "Best streak: %d\n" % int(save.best_streak)
	if biggest != "":
		out += "Biggest fish: %s, %.1f cm\n" % [biggest, big_cm]
	out += "\n[color=#ffd24d][b]Around the coast[/b][/color]\n"
	var visited: Dictionary = save.visited
	out += "Places found: %d   Map explored: %d%%\n" % [visited.size(), map_screen.explored_pct()]
	var thanks: Dictionary = save.thanks
	var helped := 0
	for who in thanks:
		helped += int(thanks[who])
	out += "Requests done for townsfolk: %d\n" % helped
	out += "Boats owned: %d   Shells: %d\n" % [(save.boats as Array).size(), int(save.shells)]
	if str(save.companion) != "":
		out += "Your cat: %s\n" % str(companion.cat_name(str(save.companion)))
	return out


## After the title screen: a few pointers the first time you play.
func welcome() -> void:
	if not _first_time:
		return
	_first_time = false
	if (save.look as Dictionary).is_empty():
		wardrobe.open_create(_created)
	else:
		_created()


func _created() -> void:
	hud.toast("Welcome to Gullhaven! Walk with {move}, turn the camera with {camera}. The gold corner says what to do next.")
	story.intro()


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


func set_quality(high: bool, say := true) -> void:
	quality_high = high
	var attr := world_env.camera_attributes as CameraAttributesPractical
	attr.dof_blur_far_enabled = high
	attr.dof_blur_near_enabled = high
	env.ssao_enabled = high
	env.volumetric_fog_enabled = high
	sun.shadow_blur = 1.5 if high else 0.5
	if say:
		hud.toast("Quality: " + ("High" if high else "Low"))
