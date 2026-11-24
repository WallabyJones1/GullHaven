extends Node
## The Phase 0 fishing loop.
##   Cast: hold E (or click / A) to charge, release at the top of the bar for distance.
##   Wait: a shadow comes over and nibbles. Striking early spooks it.
##   Bite: the "!" gives you 0.9 s to strike.
##   Fight: hold to reel. Tension rises while you reel and the fish pulls; it snaps at the
##     top. Ease off and the fish takes line; let it run out and it escapes. Runs can be
##     steered against (hold the opposite direction); dives you just have to wait out.
##   Land it with low tension for a Perfect or Great catch and bonus Shells.

const SaveGame := preload("res://scripts/save_game.gd")
const DayNight := preload("res://scripts/day_night.gd")

enum State { IDLE, CHARGING, CASTING, WAITING, BITE, FIGHT, LANDED, REELING }

const RARITY_WEIGHT := [60.0, 28.0, 10.0, 3.0]
const TIER_BONUS := {"Perfect": 1.5, "Great": 1.2, "Clean": 1.0}
const MIN_CAST := 2.5
const MAX_CAST := 11.0
const BITE_WINDOW := 0.9
const ESCAPE := 1.25  # line out at which the fish gets away

var state := State.IDLE
var player: CharacterBody3D
var school: Node3D
var hud: CanvasLayer
var cam: Camera3D
var harbour: Node3D
var save: Dictionary
var day_night: Node
var fish_db: Array = []
var rarity_names: Array = []

var power := 0.0
var species: Dictionary = {}
var size_cm := 0.0
var tension := 0.0
var distance := 1.0
var max_tension := 0.0
var strength := 1.0
var phase := "calm"
var fish_dir := 1.0

var bobber: Node3D
var rod: MeshInstance3D
var line: MeshInstance3D
var line_mesh: ImmediateMesh
var line_mat: StandardMaterial3D
var alert: Label3D
var splash: CPUParticles3D

var _rng := RandomNumberGenerator.new()
var _state_t := 0.0
var _power_dir := 1.0
var _cast_from := Vector3.ZERO
var _cast_to := Vector3.ZERO
var _cast_t := 0.0
var _bob_t := 0.0
var _dip := 0.0
var _phase_t := 0.0
var _warn_t := 0.0
var _next_phase := ""
var _splash_t := 0.0
var _tip := Vector3.ZERO
var _rod_dir := Vector3.UP
var _cast_dir := Vector3.BACK


func setup(p: CharacterBody3D, s: Node3D, h: CanvasLayer, c: Camera3D, hb: Node3D, sv: Dictionary) -> void:
	player = p
	school = s
	hud = h
	cam = c
	harbour = hb
	save = sv
	day_night = get_parent().get_node_or_null("DayNight")
	_rng.randomize()
	_load_fish()
	_build_gear()
	school.roller = _roll_species
	school.reroll_all()
	school.connect("nibble", _on_nibble)
	school.connect("bite", _on_bite)
	hud.set_catches(save.log.size(), fish_db.size())


func _process(delta: float) -> void:
	_state_t += delta
	_bob_t += delta
	match state:
		State.IDLE:
			_idle()
		State.CHARGING:
			_charging(delta)
		State.CASTING:
			_casting(delta)
		State.WAITING:
			_waiting(delta)
		State.BITE:
			_biting(delta)
		State.FIGHT:
			_fight(delta)
		State.LANDED:
			_landed()
		State.REELING:
			_reeling(delta)
	_update_gear()


# --- states ----------------------------------------------------------------------

func _idle() -> void:
	player.can_move = true
	var f: Vector3 = player.facing
	var pos: Vector3 = player.global_position
	var near_water: bool = harbour.is_water(pos.x + f.x * 3.0, pos.z + f.z * 3.0) or harbour.is_water(pos.x + f.x * 6.0, pos.z + f.z * 6.0)
	hud.set_prompt("Hold E to cast" if near_water else "")
	if near_water and Input.is_action_just_pressed("action"):
		power = 0.0
		_power_dir = 1.0
		_cast_dir = Vector3(f.x, 0.0, f.z).normalized()
		_set_state(State.CHARGING)


func _charging(delta: float) -> void:
	player.can_move = false
	power += _power_dir * delta * 0.9
	if power >= 1.0:
		power = 1.0
		_power_dir = -1.0
	elif power <= 0.0:
		power = 0.0
		_power_dir = 1.0
	hud.show_power(power)
	hud.set_prompt("Release to cast")
	if Input.is_action_just_pressed("cancel"):
		hud.hide_power()
		_set_state(State.IDLE)
	elif not Input.is_action_pressed("action"):
		_start_cast()


func _start_cast() -> void:
	hud.hide_power()
	var origin: Vector3 = player.global_position
	var d := lerpf(MIN_CAST, MAX_CAST, power)
	var landing := Vector3.INF
	# Shorten the cast until it lands on open water (not the dock, the boat or the beach).
	while d >= 1.5:
		var p := origin + _cast_dir * d
		if harbour.is_water(p.x, p.z):
			landing = Vector3(p.x, 0.0, p.z)
			break
		d -= 0.5
	if landing == Vector3.INF:
		hud.toast("That's not open water. Face the sea to cast.")
		_set_state(State.IDLE)
		return
	_cast_from = _tip
	_cast_to = landing
	_cast_t = 0.0
	bobber.global_position = _tip
	bobber.visible = true
	hud.set_prompt("")
	_set_state(State.CASTING)


func _casting(delta: float) -> void:
	_cast_t = minf(_cast_t + delta / 0.55, 1.0)
	var p := _cast_from.lerp(_cast_to, _cast_t)
	p.y = lerpf(_cast_from.y, 0.0, _cast_t) + sin(_cast_t * PI) * (1.2 + power * 2.0)
	bobber.global_position = p
	if _cast_t >= 1.0:
		_splash(_cast_to)
		school.lure_landed(Vector2(_cast_to.x, _cast_to.z))
		hud.set_prompt("Wait for a bite...   Q to reel in")
		_set_state(State.WAITING)


func _waiting(delta: float) -> void:
	_float_bobber(delta)
	var strike := Input.is_action_just_pressed("action") and _state_t > 0.3
	if strike or Input.is_action_just_pressed("cancel"):
		if strike and school.is_interested():
			hud.toast("Too soon! You spooked it.")
		school.lure_cleared()
		_reel_in()


func _biting(_delta: float) -> void:
	var p := bobber.global_position
	p.y = -0.14 + sin(_bob_t * 30.0) * 0.03  # dragged under and thrashing
	bobber.global_position = p
	alert.global_position = player.global_position + Vector3(0.0, 2.35, 0.0)
	alert.visible = true
	if Input.is_action_just_pressed("action"):
		alert.visible = false
		_hook()
	elif _state_t > BITE_WINDOW:
		alert.visible = false
		hud.toast("Missed it! The fish let go.")
		school.bite_missed()
		hud.set_prompt("Wait for a bite...   Q to reel in")
		_set_state(State.WAITING)


func _hook() -> void:
	var sz: Array = species.get("sz", [20, 40])
	var lo := float(sz[0])
	var hi := float(sz[1])
	size_cm = lerpf(lo, hi, pow(_rng.randf(), 1.6))  # big ones are rarer
	var r := float(species.get("r", 0))
	strength = 0.75 + r * 0.22 + clampf((size_cm - 25.0) / 150.0, 0.0, 0.4)
	tension = 0.25
	max_tension = tension
	distance = 0.75 + r * 0.1
	phase = "calm"
	_phase_t = _rng.randf_range(1.2, 2.2)
	_warn_t = 0.0
	school.hooked()
	cam.set_focus(true, bobber.global_position)
	cam.shake(0.4)
	_splash(bobber.global_position)
	hud.set_prompt("")
	_set_state(State.FIGHT)


func _fight(delta: float) -> void:
	var reeling := Input.is_action_pressed("action")
	var steer := Input.get_axis("move_left", "move_right")
	var r := float(species.get("r", 0))

	# The fish alternates between easy spells and runs or dives, with a warning first.
	if _warn_t > 0.0:
		_warn_t -= delta
		if _warn_t <= 0.0:
			phase = _next_phase
			_phase_t = _rng.randf_range(1.0, 2.0) + r * 0.3 if phase == "run" else _rng.randf_range(0.8, 1.5)
			fish_dir = -1.0 if _rng.randf() < 0.5 else 1.0
			cam.shake(0.25)
			_splash(bobber.global_position)
	else:
		_phase_t -= delta
		if _phase_t <= 0.0:
			if phase == "calm":
				_next_phase = "run" if _rng.randf() < 0.6 else "dive"
				_warn_t = 0.45
			else:
				phase = "calm"
				_phase_t = maxf(_rng.randf_range(1.4, 2.6) - r * 0.25, 0.7)

	var pull := 0.15
	if phase == "run":
		pull = 1.0
	elif phase == "dive":
		pull = 0.75
	pull *= strength
	var countered := phase == "run" and steer * fish_dir < -0.3
	if countered:
		pull *= 0.45

	var goal := 0.22 + pull * 0.85 if reeling else pull * 0.25
	tension = move_toward(tension, goal, (0.6 if goal > tension else 1.1) * delta)
	max_tension = maxf(max_tension, tension)
	if reeling:
		var reel := 0.15 * (1.0 - minf(pull, 1.2) * 0.45)
		if phase == "dive":
			reel *= 0.4
		distance -= reel * delta
	else:
		distance += pull * 0.07 * delta

	# Drag the bobber about: out along the cast line with the line out, and sideways on a run.
	var origin: Vector3 = player.global_position
	var away := Vector3(_cast_to.x - origin.x, 0.0, _cast_to.z - origin.z).normalized()
	var sway := sin(_state_t * 1.7) * 0.6
	if phase == "run":
		sway += fish_dir * 1.4
	# Sideways is screen left/right (world X), so "running right" looks right.
	var want := origin + away * (2.0 + distance * 6.0) + Vector3.RIGHT * sway
	var b := bobber.global_position.lerp(Vector3(want.x, 0.0, want.z), minf(delta * 2.0, 1.0))
	if not harbour.is_water(b.x, b.z):
		b = bobber.global_position
	b.y = -0.06 + sin(_bob_t * 18.0) * 0.03 - (0.1 if phase == "dive" else 0.0)
	bobber.global_position = b
	school.move_lure(Vector2(b.x, b.z))
	cam.set_focus(true, b)
	if phase != "calm":
		_splash_t -= delta
		if _splash_t <= 0.0:
			_splash_t = 0.3
			_splash(b)

	var text := "Hold E to reel in"
	if _warn_t > 0.0:
		text = "It's about to run!" if _next_phase == "run" else "It's about to dive!"
	elif phase == "run":
		var key := "D" if fish_dir < 0.0 else "A"
		text = "Running %s! Hold %s to steer" % ["left" if fish_dir < 0.0 else "right", key]
	elif phase == "dive":
		text = "Diving! Ease off"
	hud.show_fight(tension, clampf(1.0 - distance / ESCAPE, 0.0, 1.0), text, _warn_t > 0.0 or phase != "calm")

	if tension >= 1.0:
		_end_fight()
		cam.shake(0.6)
		hud.toast("Snap! The line broke.")
		school.fish_escaped()
		bobber.visible = false
		_set_state(State.IDLE)
	elif distance >= ESCAPE:
		_end_fight()
		hud.toast("It got away...")
		school.fish_escaped()
		_reel_in()
	elif distance <= 0.0:
		_end_fight()
		_land()


func _end_fight() -> void:
	hud.hide_fight()
	cam.set_focus(false)


func _land() -> void:
	var tier := "Clean"
	if max_tension < 0.75:
		tier = "Perfect"
	elif max_tension < 0.9:
		tier = "Great"
	var sz: Array = species.get("sz", [20, 40])
	var lo := float(sz[0])
	var span := maxf(float(sz[1]) - lo, 1.0)
	var bonus: float = TIER_BONUS[tier]
	var value := int(round(float(species.get("price", 10)) * (0.8 + 0.4 * (size_cm - lo) / span) * bonus))

	var id: String = species.get("id", "")
	var book: Dictionary = save.log
	var entry: Dictionary = book.get(id, {})
	var is_new := entry.is_empty()
	var best := float(entry.get("best", 0.0))
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["best"] = snappedf(maxf(best, size_cm), 0.1)
	book[id] = entry
	save.shells = int(save.shells) + value
	SaveGame.write(save)
	hud.set_shells(save.shells)
	hud.set_catches(book.size())

	school.fish_landed()
	bobber.visible = false
	var icon_path := "res://art/fish/%s.png" % id
	var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	player.show_off(icon)
	cam.shake(0.2)
	var r := int(species.get("r", 0))
	hud.show_catch({
		"name": species.get("n", "A fish"),
		"rarity": r,
		"rarity_name": rarity_names[r] if r < rarity_names.size() else "",
		"icon": icon,
		"size": size_cm,
		"tier": tier,
		"shells": value,
		"is_new": is_new,
		"record": not is_new and size_cm > best,
	})
	_set_state(State.LANDED)


func _landed() -> void:
	player.can_move = false
	hud.set_prompt("")
	if _state_t > 0.6 and Input.is_action_just_pressed("action"):
		hud.hide_catch()
		player.hide_held()
		_set_state(State.IDLE)


func _reel_in() -> void:
	_cast_from = bobber.global_position
	_cast_t = 0.0
	hud.set_prompt("")
	_set_state(State.REELING)


func _reeling(delta: float) -> void:
	_cast_t = minf(_cast_t + delta / 0.35, 1.0)
	var p := _cast_from.lerp(_tip, _cast_t)
	p.y += sin(_cast_t * PI) * 0.6
	bobber.global_position = p
	if _cast_t >= 1.0:
		bobber.visible = false
		_set_state(State.IDLE)


# --- school signals ------------------------------------------------------------------

func _on_nibble() -> void:
	if state == State.WAITING:
		_dip = 0.07


func _on_bite(sp: Dictionary) -> void:
	if state != State.WAITING:
		return
	species = sp if not sp.is_empty() else _roll_species()
	_splash(bobber.global_position)
	cam.shake(0.3)
	hud.set_prompt("Strike! Press E")
	_set_state(State.BITE)


# --- the catalogue -----------------------------------------------------------------

func _load_fish() -> void:
	var f := FileAccess.open("res://data/fish.json", FileAccess.READ)
	if f == null:
		push_error("Missing res://data/fish.json (run tools/export_godot_assets.py)")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	rarity_names = data.get("rarity", [])
	for e in data.get("fish", []):
		if e.z == "harbour" and e.cat == "fish":
			fish_db.append(e)


## Pick a harbour fish that is about at this time of day, weighted by rarity.
func _roll_species() -> Dictionary:
	if fish_db.is_empty():
		return {}
	var hour := _hour()
	var pool: Array = []
	var weights: Array[float] = []
	var total := 0.0
	for e in fish_db:
		if _available(e, hour):
			var w: float = RARITY_WEIGHT[clampi(int(e.r), 0, RARITY_WEIGHT.size() - 1)]
			pool.append(e)
			weights.append(w)
			total += w
	if pool.is_empty():
		return fish_db[0]
	var pick := _rng.randf() * total
	for i in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _available(e: Dictionary, hour: float) -> bool:
	var when: Variant = e.cp.get("time")
	if when == null:
		return true
	var now := DayNight.period(hour)
	for part in str(when).split("/"):
		if part == now:
			return true
		if part == "midnight" and (hour >= 23.0 or hour < 2.0):
			return true
	return false


func _hour() -> float:
	if day_night:
		return float(day_night.hour)
	return 9.0


# --- rod, line, bobber and effects -------------------------------------------------

func _build_gear() -> void:
	rod = MeshInstance3D.new()
	var rod_mesh := BoxMesh.new()
	rod_mesh.size = Vector3(0.04, 0.04, 1.7)
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.42, 0.26, 0.15)
	rod_mesh.material = rod_mat
	rod.mesh = rod_mesh
	rod.visible = false
	add_child(rod)

	line_mesh = ImmediateMesh.new()
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.95, 0.95, 0.9)
	line = MeshInstance3D.new()
	line.mesh = line_mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)

	bobber = Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.18, 0.15)
	red.emission_enabled = true
	red.emission = Color(0.9, 0.18, 0.15)
	red.emission_energy_multiplier = 0.25  # stays visible at night
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.96, 0.92)
	var body := SphereMesh.new()
	body.radius = 0.1
	body.height = 0.2
	body.material = red
	var top := SphereMesh.new()
	top.radius = 0.06
	top.height = 0.12
	top.material = white
	var m1 := MeshInstance3D.new()
	m1.mesh = body
	m1.position.y = 0.06
	var m2 := MeshInstance3D.new()
	m2.mesh = top
	m2.position.y = 0.15
	bobber.add_child(m1)
	bobber.add_child(m2)
	bobber.visible = false
	add_child(bobber)

	alert = Label3D.new()
	alert.text = "!"
	alert.font = load("res://art/fonts/pixelify_sans_bold.woff2")
	alert.font_size = 96
	alert.pixel_size = 0.008
	alert.outline_size = 18
	alert.modulate = Color(1.0, 0.85, 0.25)
	alert.outline_modulate = Color(0.16, 0.08, 0.05)
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.no_depth_test = true
	alert.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alert.visible = false
	add_child(alert)

	splash = CPUParticles3D.new()
	splash.emitting = false
	splash.one_shot = true
	splash.amount = 28
	splash.lifetime = 0.7
	splash.explosiveness = 0.9
	splash.direction = Vector3.UP
	splash.spread = 35.0
	splash.initial_velocity_min = 1.6
	splash.initial_velocity_max = 3.4
	splash.gravity = Vector3(0.0, -9.8, 0.0)
	splash.scale_amount_min = 0.6
	splash.scale_amount_max = 1.2
	splash.color = Color(0.92, 0.98, 1.0)
	var drop := QuadMesh.new()
	drop.size = Vector2(0.09, 0.09)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop_mat.vertex_color_use_as_albedo = true
	drop.material = drop_mat
	splash.mesh = drop
	add_child(splash)


func _update_gear() -> void:
	var active := state != State.IDLE and state != State.LANDED
	var base: Vector3 = player.global_position + Vector3(0.0, 0.9, 0.0) + _cast_dir * 0.15
	var up := Vector3.UP
	match state:
		State.CHARGING:
			_rod_dir = (-_cast_dir * (0.3 + power * 0.5) + up).normalized()
		State.CASTING:
			_rod_dir = (_cast_dir * minf(_cast_t * 2.5, 1.0) + up * 0.7).normalized()
		State.FIGHT:
			var to := bobber.global_position - base
			to.y = 0.0
			var toward := to.normalized() if to.length() > 0.05 else _cast_dir
			_rod_dir = (toward * (0.5 + tension * 0.4) + up * (1.0 - tension * 0.4)).normalized()
		_:
			_rod_dir = (_cast_dir + up * 0.75).normalized()
	_tip = base + _rod_dir * 1.7
	rod.visible = active
	if active:
		rod.global_transform = Transform3D(Basis.looking_at(_rod_dir, Vector3.UP), base + _rod_dir * 0.85)

	line.visible = active and bobber.visible
	if not line.visible:
		return
	var sag := 0.15
	if state == State.WAITING or state == State.BITE:
		sag = 0.5
	elif state == State.FIGHT:
		sag = (1.0 - tension) * 0.4
	var a := _tip
	var b := bobber.global_position + Vector3(0.0, 0.12, 0.0)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_mat)
	for i in 17:
		var t := i / 16.0
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()


func _float_bobber(delta: float) -> void:
	_dip = move_toward(_dip, 0.0, delta * 0.4)
	var p := bobber.global_position
	p.y = sin(_bob_t * 2.6) * 0.025 - _dip
	bobber.global_position = p


func _splash(at: Vector3) -> void:
	splash.global_position = Vector3(at.x, 0.02, at.z)
	splash.restart()


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	player.can_move = s == State.IDLE
