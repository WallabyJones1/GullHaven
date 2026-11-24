extends Node
## The fishing loop.
##   Cast: hold Space (or click / pad A) to charge, release near the top for distance. Your rod
##     sets how far you can cast. The bait on your hook (R to change) shifts what bites.
##   Wait: a shadow comes over and nibbles. Striking early spooks it.
##   Bite: the "!" gives you 0.9 s to strike. What's on the line is rolled from the web
##     game's rules: which water you cast into, the time, tide, weather,
##     season, your bait, your rod, and the size of the shadow that bit.
##   Fight: hold to reel. Every fish has a style (runner, jumper, diver, sulker...) that
##     decides how it fights. Steer against runs, ease off for dives, and let go while it
##     jumps. Tension snaps the line; too much line out and it escapes.
##   Catch: graded Perfect, Great or Clean. Streaks of catches add bonus Shells.

const Sea := preload("res://scripts/sea.gd")
const SaveGame := preload("res://scripts/save_game.gd")

enum State { IDLE, CHARGING, CASTING, WAITING, BITE, FIGHT, LANDED, REELING }

const TIER_BONUS := {"Perfect": 1.5, "Great": 1.2, "Clean": 1.0}
const MIN_CAST := 2.5
const BITE_WINDOW := 0.9
const ESCAPE := 1.25  # line out at which the fish gets away
# How each style fights: chance of each move after a calm spell, and how long things last.
const STYLES := {
	"runner": {"run": 0.6, "dive": 0.15, "jump": 0.25, "calm": 1.0, "len": 1.0},
	"jumper": {"run": 0.35, "dive": 0.05, "jump": 0.6, "calm": 0.9, "len": 0.9},
	"fighter": {"run": 0.5, "dive": 0.3, "jump": 0.2, "calm": 0.8, "len": 0.8},
	"darter": {"run": 0.85, "dive": 0.15, "jump": 0.0, "calm": 0.6, "len": 0.5},
	"sulker": {"run": 0.25, "dive": 0.75, "jump": 0.0, "calm": 1.4, "len": 1.5},
	"diver": {"run": 0.5, "dive": 0.5, "jump": 0.0, "calm": 1.0, "len": 1.3},
	"gentle": {"run": 0.4, "dive": 0.2, "jump": 0.0, "calm": 1.6, "len": 0.6},
	"heavy": {"run": 0.0, "dive": 1.0, "jump": 0.0, "calm": 1.6, "len": 0.8},
	"junk": {"run": 0.0, "dive": 0.0, "jump": 0.0, "calm": 1.0, "len": 1.0},
}
const SHAPE_STYLE := {
	"torp": "runner", "gar": "jumper", "deep": "fighter", "disc": "fighter", "jacket": "fighter",
	"squid": "darter", "cuttle": "darter", "octo": "darter", "guitar": "sulker", "ray": "sulker",
	"flathead": "sulker", "shark": "diver", "seahorse": "gentle", "crab": "gentle",
}
const STYLE_NAME := {
	"runner": "a runner", "jumper": "a jumper", "fighter": "a scrapper", "darter": "a darter",
	"sulker": "a heavy sulker", "diver": "a deep diver", "gentle": "a gentle one",
	"heavy": "something heavy", "junk": "something limp",
}
const JUNK_QUIPS := {
	"old_boot": "Someone's missing a boot.", "tin_can": "Recycling counts as fishing, right?",
	"seaweed_clump": "Lovely. Slimy.", "tangled_line": "Not yours, at least.",
	"plastic_bag": "One less in the sea.", "broken_rod": "It's seen better days.",
	"car_tyre": "How did that get down there?", "shopping_trolley": "It fought like a marlin.",
	"bicycle": "Two wheels, no fish.", "rubber_duck": "Quack.",
}
const GOLD_TINT := Color(1.4, 1.12, 0.45)
const ALBINO_TINT := Color(1.3, 1.2, 1.25)

var state := State.IDLE
var player: CharacterBody3D
var school: Node3D
var hud: CanvasLayer
var cam: Camera3D
var harbour: Node3D
var save: Dictionary
var sea: Node
var audio: Node
var town: Node
var boats: Node3D  # when you're aboard, you cast off the side

var power := 0.0
var catch_e: Dictionary = {}
var size_cm := 0.0
var variant := ""
var style := "fighter"
var zone := "harbour"
var streak := 0
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
var ink: CPUParticles3D
var jumper: Sprite3D

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
var _reel_t := 0.0
var _jump_t := 0.0
var _tip := Vector3.ZERO
var _rod_dir := Vector3.UP
var _cast_dir := Vector3.BACK


func setup(p: CharacterBody3D, s: Node3D, h: CanvasLayer, c: Camera3D, hb: Node3D, sv: Dictionary, se: Node, a: Node, t: Node) -> void:
	player = p
	school = s
	hud = h
	cam = c
	harbour = hb
	save = sv
	sea = se
	audio = a
	town = t
	_rng.randomize()
	_build_gear()
	school.roller = _roll_shadow
	school.reroll_all()
	school.connect("nibble", _on_nibble)
	school.connect("bite", _on_bite)
	school.connect("frenzy_started", _on_frenzy)
	school.connect("frenzy_ended", _on_frenzy_end)
	if not sea.bait.has(str(save.bait_sel)) or (save.bait_sel != "dough" and int(save.bait.get(save.bait_sel, 0)) <= 0):
		save.bait_sel = "dough"
	hud.set_streak(0)
	hud.set_catches(_logged_here(), _total_here())
	hud.refresh_bait()


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


# --- gear --------------------------------------------------------------------------

func _gear(kind: String) -> Dictionary:
	var list: Array = sea.gear.get(kind, [{}])
	return list[clampi(int(save.gear.get(kind, 0)), 0, list.size() - 1)]


func rod_tier() -> int:
	return int(save.gear.get("rod", 0))


func max_cast() -> float:
	return 4.0 + 10.0 * float(_gear("rod").get("cast", 0.55))


func bait_key() -> String:
	return str(save.bait_sel)


func _cycle_bait() -> void:
	var options: Array[String] = ["dough"]
	for k in sea.bait_order:
		if k != "dough" and int(save.bait.get(k, 0)) > 0:
			options.append(str(k))
	if options.size() == 1:
		hud.toast("Only bread dough on hand. Hale sells bait at the stall.")
		return
	var i := options.find(bait_key())
	save.bait_sel = options[(i + 1) % options.size()]
	hud.refresh_bait()
	audio.play("click")


## Use up one bait when the cast lands (lures are kept unless the line snaps).
func _use_bait() -> void:
	var k := bait_key()
	if k == "dough" or sea.bait.get(k, {}).has("lure"):
		return
	var left := int(save.bait.get(k, 0)) - 1
	save.bait[k] = maxi(left, 0)
	if left <= 0:
		save.bait_sel = "dough"
		hud.toast("That was your last %s. Back to bread dough." % str(sea.bait[k].n).to_lower())
	hud.refresh_bait()


# --- states ----------------------------------------------------------------------

func _idle() -> void:
	player.can_move = not hud.modal
	if hud.input_blocked():
		return
	if Input.is_action_just_pressed("bait"):
		_cycle_bait()
	var it: Dictionary = town.nearest(player.global_position, player.facing)
	if not it.is_empty():
		hud.set_prompt(str(it.text))
		if Input.is_action_just_pressed("action"):
			town.interact(it)
		return
	if harbour.indoor:
		hud.set_prompt("")
		return
	if player.swimming:
		hud.set_prompt("Swim to a beach, or push against a dock to climb out")
		return
	var f: Vector3 = player.facing
	var pos: Vector3 = player.global_position
	var near_water: bool = harbour.is_water(pos.x + f.x * 3.0, pos.z + f.z * 3.0) or harbour.is_water(pos.x + f.x * 6.0, pos.z + f.z * 6.0)
	var hint := "Hold Space to cast" if near_water else ""
	if boats and boats.aboard:
		hint = "Hold Space to cast   Esc: step ashore" if boats.can_land() else "Hold Space to cast"
	hud.set_prompt(hint)
	if near_water and Input.is_action_just_pressed("action"):
		power = 0.0
		_power_dir = 1.0
		_cast_dir = Vector3(f.x, 0.0, f.z).normalized()
		player.face(_cast_dir)
		_set_state(State.CHARGING)


func _charging(delta: float) -> void:
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
	var d := lerpf(MIN_CAST, max_cast(), power)
	var landing := Vector3.INF
	# Shorten the cast until it lands on open water (not the dock, the boat or the sand).
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
	audio.play("cast", -2.0, 1.0, 0.08)
	_set_state(State.CASTING)


func _casting(delta: float) -> void:
	_cast_t = minf(_cast_t + delta / 0.55, 1.0)
	var water_y: float = harbour.water_level_at(_cast_to.x, _cast_to.z)
	var p := _cast_from.lerp(Vector3(_cast_to.x, water_y, _cast_to.z), _cast_t)
	p.y += sin(_cast_t * PI) * (1.2 + power * 2.0)
	bobber.global_position = p
	if _cast_t >= 1.0:
		_splash(_cast_to)
		audio.play("plop", -2.0, 1.0, 0.1)
		zone = harbour.zone_at(_cast_to.x, _cast_to.z)
		_use_bait()
		school.lure_landed(Vector2(_cast_to.x, _cast_to.z))
		var info: Dictionary = sea.zones.get(zone, {})
		var where := str(info.get("n", "the water"))
		if zone == "harbour":
			where = "the harbour"
		hud.set_prompt("Fishing %s...   Esc to reel in" % where)
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
	var level: float = harbour.water_level_at(p.x, p.z)
	p.y = level - 0.14 + sin(_bob_t * 30.0) * 0.03  # dragged under, thrashing
	bobber.global_position = p
	alert.global_position = player.global_position + Vector3(0.0, 2.35, 0.0)
	alert.visible = true
	if Input.is_action_just_pressed("action"):
		alert.visible = false
		_hook()
	elif _state_t > BITE_WINDOW:
		alert.visible = false
		hud.toast("Missed it! The fish let go.")
		audio.play("miss", -4.0)
		_break_streak()
		school.bite_missed()
		hud.set_prompt("Waiting for another bite...   Esc to reel in")
		_set_state(State.WAITING)


func _hook() -> void:
	var e := catch_e
	var r := int(e.r)
	var cls := Sea.size_class(e)
	style = _style_for(e)
	strength = 0.7 + r * 0.2 + cls * 0.12 + Sea.size_frac(e, size_cm) * 0.2
	distance = 0.7 + r * 0.08 + cls * 0.06
	match style:
		"junk":
			strength = 0.4 + r * 0.1
			distance = 0.55
		"heavy":
			strength = 0.8 + r * 0.15
	if e.cat == "legend":
		strength += 0.3
		distance += 0.15
	distance = minf(distance, 1.0)  # always start with some room before it escapes
	tension = 0.2
	max_tension = tension
	phase = "calm"
	_phase_t = _rng.randf_range(1.0, 1.8) * float(STYLES[style].calm)
	_warn_t = 0.0
	school.hooked()
	cam.set_focus(true, bobber.global_position)
	cam.shake(0.4)
	_splash(bobber.global_position)
	audio.play("splash", -2.0, 1.0, 0.1)
	hud.set_prompt("")
	_set_state(State.FIGHT)


func _style_for(e: Dictionary) -> String:
	match str(e.cat):
		"junk":
			return "junk"
		"fish", "legend":
			return SHAPE_STYLE.get(str(e.art), "fighter")
	return "heavy"  # treasure, letters and other finds: dead weight


func _fight(delta: float) -> void:
	var reeling := Input.is_action_pressed("action")
	var steer := Input.get_axis("move_left", "move_right")
	var r := float(catch_e.r)
	var st: Dictionary = STYLES[style]

	# Calm spells alternate with moves (run, dive or jump), each with a warning first.
	if _warn_t > 0.0:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_begin_phase(_next_phase, st, r)
	else:
		_phase_t -= delta
		if _phase_t <= 0.0:
			if phase == "calm":
				_next_phase = _pick_move(st)
				if _next_phase == "":
					_phase_t = 1.0
				else:
					_warn_t = 0.3 if style == "darter" else 0.45
			else:
				_end_phase()
				phase = "calm"
				_phase_t = maxf(_rng.randf_range(1.3, 2.4) * float(st.calm) - r * 0.2, 0.5)

	# The fish's pull, softened by your rod; runs can be steered against.
	var pull := 0.15
	match phase:
		"run":
			pull = 1.0
		"dive":
			pull = 0.75
		"jump":
			pull = 0.0
	pull *= strength / pow(float(_gear("rod").get("power", 1.0)), 0.6)
	var countered := phase == "run" and steer * fish_dir < -0.3
	if countered:
		pull *= 0.45

	var line_k := pow(float(_gear("line").get("str", 1.0)), 0.4)
	var drag := float(_gear("reel").get("drag", 1.0))
	var goal := 0.0
	if phase == "jump":
		goal = 1.25 if reeling else 0.05  # reeling a fish in mid-air snaps the line
	elif reeling:
		goal = (0.22 + pull * 0.85 / sqrt(drag)) / line_k
	else:
		goal = pull * 0.25 / line_k
	var rate := (0.7 if phase == "jump" else 0.6) if goal > tension else 1.1 * drag
	tension = move_toward(tension, goal, rate * delta)
	max_tension = maxf(max_tension, tension)
	if phase != "jump":
		if reeling:
			var reel := 0.15 * float(_gear("reel").get("speed", 1.0)) * (1.0 - minf(pull, 1.2) * 0.45)
			if phase == "dive":
				reel *= 0.4
			distance -= reel * delta
		else:
			distance += pull * 0.07 * delta

	if reeling:
		_reel_t -= delta
		if _reel_t <= 0.0:
			_reel_t = 0.085 / float(_gear("reel").get("speed", 1.0))
			audio.play("reel", -9.0, 0.8 + tension * 0.7, 0.04)

	_move_bobber(delta)
	_fight_hud()

	if tension >= 1.0:
		_snap()
	elif distance >= ESCAPE:
		_end_fight()
		hud.toast("It got away...")
		audio.play("miss", -2.0)
		_break_streak()
		school.fish_escaped()
		_reel_in()
	elif distance <= 0.0:
		_end_fight()
		_land()


func _pick_move(st: Dictionary) -> String:
	var run := float(st.run)
	var dive := float(st.dive)
	var jump := float(st.jump)
	var total := run + dive + jump
	if total <= 0.0:
		return ""
	var x := _rng.randf() * total
	if x < run:
		return "run"
	if x < run + dive:
		return "dive"
	return "jump"


func _begin_phase(p: String, st: Dictionary, r: float) -> void:
	phase = p
	match p:
		"run":
			_phase_t = (_rng.randf_range(1.0, 2.0) + r * 0.3) * float(st.len)
			fish_dir = -1.0 if _rng.randf() < 0.5 else 1.0
			if ["squid", "cuttle", "octo"].has(str(catch_e.art)):
				ink.global_position = bobber.global_position
				ink.restart()
		"dive":
			_phase_t = _rng.randf_range(0.8, 1.5) * float(st.len)
		"jump":
			_phase_t = 0.9
			_jump_t = 0.0
			jumper.texture = _icon(str(catch_e.id))
			jumper.modulate = _tint()
			jumper.pixel_size = (1.0 / 44.0) * (0.8 + Sea.size_class(catch_e) * 0.35)
			jumper.visible = true
			audio.play("jump", -1.0, 1.0, 0.1)
	cam.shake(0.25)
	_splash(bobber.global_position)


func _end_phase() -> void:
	if phase == "jump":
		jumper.visible = false
		_splash(bobber.global_position)
		audio.play("splash", -2.0, 1.1, 0.1)


func _move_bobber(delta: float) -> void:
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
	var water_y: float = harbour.water_level_at(b.x, b.z)
	b.y = water_y - 0.06 + sin(_bob_t * 18.0) * 0.03 - (0.1 if phase == "dive" else 0.0)
	bobber.global_position = b
	school.move_lure(Vector2(b.x, b.z))
	cam.set_focus(true, b)
	if phase == "jump":
		_jump_t += delta
		var k := clampf(_jump_t / 0.9, 0.0, 1.0)
		var height := (1.2 + Sea.size_class(catch_e) * 0.3) * sin(k * PI)
		jumper.global_position = b + Vector3(fish_dir * (k - 0.5) * 0.8, height + 0.2, 0.0)
		jumper.rotation.z = (k - 0.5) * 2.4 * fish_dir
	elif phase != "calm":
		_splash_t -= delta
		if _splash_t <= 0.0:
			_splash_t = 0.3
			_splash(b)


func _fight_hud() -> void:
	var text := "Hold Space to reel in"
	if _state_t < 1.4:
		text = "Hooked! Feels like %s." % STYLE_NAME.get(style, "a fish")
	elif style == "junk":
		text = "Something limp... reel it in"
	if _warn_t > 0.0:
		text = {"run": "It's about to run!", "dive": "It's about to dive!", "jump": "It's going to jump!"}.get(_next_phase, "")
	elif phase == "run":
		var key := "D" if fish_dir < 0.0 else "A"
		text = "Running %s! Hold %s to steer" % ["left" if fish_dir < 0.0 else "right", key]
	elif phase == "dive":
		text = "Diving! Ease off"
	elif phase == "jump":
		text = "It's jumping! Let go!"
	hud.show_fight(tension, clampf(1.0 - distance / ESCAPE, 0.0, 1.0), text, _warn_t > 0.0 or phase != "calm")


func _snap() -> void:
	_end_fight()
	cam.shake(0.6)
	audio.play("snap")
	var k := bait_key()
	var lost := ""
	if sea.bait.get(k, {}).has("lure"):
		save.bait[k] = 0
		save.bait_sel = "dough"
		lost = " It took your %s with it." % str(sea.bait[k].n).to_lower()
		hud.refresh_bait()
		SaveGame.write(save)
	hud.toast("Snap! The line broke.%s" % lost)
	_break_streak()
	school.fish_escaped()
	bobber.visible = false
	_set_state(State.IDLE)


func _end_fight() -> void:
	hud.hide_fight()
	cam.set_focus(false)
	if jumper.visible:
		jumper.visible = false


func _break_streak() -> void:
	if streak > 0:
		streak = 0
		hud.set_streak(0)


func _land() -> void:
	var e := catch_e
	var id: String = e.id
	var cat: String = e.cat
	var is_fish := cat == "fish" or cat == "legend"
	var tier := "Clean"
	if max_tension < 0.75:
		tier = "Perfect"
	elif max_tension < 0.9:
		tier = "Great"
	if is_fish:
		streak += 1
		hud.set_streak(streak)
		if streak > int(save.best_streak):
			save.best_streak = streak
	var vmult := 3.0 if variant == "g" else (2.0 if variant == "a" else 1.0)
	var smult := 1.0 + minf(streak, 10) * 0.05
	var value := int(e.price)
	if is_fish:
		value = int(round(float(e.price) * (0.8 + 0.4 * Sea.size_frac(e, size_cm)) * float(TIER_BONUS[tier]) * vmult * smult))
	elif cat != "junk":
		value = int(round(float(e.price) * float(TIER_BONUS[tier])))
	var hot: bool = is_fish and town.is_hot(id)
	if hot:
		value *= 2
	var for_who: String = town.claim_catch(e, size_cm)
	if for_who != "":
		value = 0
	var mats_note := ""
	if cat == "junk":
		mats_note = town.junk_materials(id)

	var book: Dictionary = save.log
	var entry: Dictionary = book.get(id, {})
	var is_new := entry.is_empty()
	var best := float(entry.get("best", 0.0))
	entry["count"] = int(entry.get("count", 0)) + 1
	if size_cm > 0.0:
		entry["best"] = snappedf(maxf(best, size_cm), 0.1)
	if variant != "":
		entry[variant] = int(entry.get(variant, 0)) + 1
	book[id] = entry
	var stats: Dictionary = save.stats
	stats["catches"] = int(stats.get("catches", 0)) + 1
	if cat == "junk":
		stats["junk"] = int(stats.get("junk", 0)) + 1
	elif not is_fish:
		stats["finds"] = int(stats.get("finds", 0)) + 1
	save.shells = int(save.shells) + value
	SaveGame.write(save)
	hud.set_shells(save.shells)
	hud.set_catches(_logged_here(), _total_here())

	school.fish_landed()
	bobber.visible = false
	var icon := _icon(id)
	player.show_off(icon, _tint())
	cam.shake(0.2)
	_cheer(e, is_new)
	if value > 0:
		_float_text("+%d Shells" % value, player.global_position + Vector3(0.0, 2.9, 0.0))

	var title := str(e.get("n", "Something"))
	if variant == "g":
		title = "Golden " + title
	elif variant == "a":
		title = "Albino " + title
	var r := int(e.r)
	var kind := ""
	if cat == "junk":
		kind = "Junk"
	elif cat == "legend":
		kind = "Legend"
	elif not is_fish:
		kind = "Find"
	elif r < sea.rarity.size():
		kind = str(sea.rarity[r])
	var note := ""
	if for_who != "":
		note = "%s asked for one of these! Take it to them." % for_who
	elif cat == "junk":
		note = JUNK_QUIPS.get(id, "")
		if mats_note != "":
			note = ("%s  %s for your hut." % [note, mats_note]).strip_edges()
	elif hot:
		note = "Catch of the day: double Shells!" + ("  New in your Logbook!" if is_new else "")
	elif is_new:
		note = "New in your Logbook!"
	elif size_cm > best and size_cm > 0.0:
		note = "Biggest one yet!"
	elif variant != "":
		note = "A one in %d catch!" % (400 if variant == "g" else 250)
	hud.show_catch({
		"name": title,
		"rarity": r,
		"rarity_name": kind,
		"icon": icon,
		"tint": _tint(),
		"size": size_cm,
		"tier": tier if is_fish else "",
		"shells": value,
		"note": note,
		"style": STYLE_NAME.get(style, "") if is_fish else "",
	})
	_set_state(State.LANDED)


## The right fanfare for what you landed.
func _cheer(e: Dictionary, is_new: bool) -> void:
	audio.play("cardflip", -6.0)
	if e.cat == "junk":
		audio.play("thud")
		if e.id == "rubber_duck":
			audio.play("quack")
	elif e.cat == "legend" or variant != "":
		audio.play("jackpot")
	elif int(e.r) >= 2 or e.cat != "fish":
		audio.play("fanfare2", -2.0)
	elif is_new:
		audio.play("fanfare1")
	else:
		audio.play("catch")


func _landed() -> void:
	player.can_move = false
	hud.set_prompt("")
	if _state_t > 0.6 and Input.is_action_just_pressed("action"):
		hud.hide_catch()
		player.hide_held()
		audio.play("coin", -6.0)
		_set_state(State.IDLE)
		hud.block_input(0.2)


func _reel_in() -> void:
	_cast_from = bobber.global_position
	_cast_t = 0.0
	hud.set_prompt("")
	audio.play("whoosh", -6.0)
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
		audio.play("plop", -14.0, 1.7, 0.2)


func _on_bite(cls: int) -> void:
	if state != State.WAITING:
		return
	var at := Vector2(bobber.global_position.x, bobber.global_position.z)
	var boost: float = school.frenzy_boost(at)
	var table: Array = sea.hook_table(zone, bait_key(), rod_tier(), cls, boost)
	var e: Variant = Sea.pick_w(table, _rng.randf())
	if e == null:
		e = sea.by_id.get("seaweed_clump", {"id": "seaweed_clump", "n": "Seaweed", "cat": "junk", "r": 0, "price": 1, "art": "", "sz": null})
	catch_e = e
	size_cm = Sea.roll_size(catch_e, _rng.randf())
	variant = Sea.roll_variant(catch_e, _rng.randf())
	_splash(bobber.global_position)
	audio.play("bite")
	cam.shake(0.3)
	hud.set_prompt("Strike! Press Space")
	_set_state(State.BITE)


func _on_frenzy(at: Vector3) -> void:
	var where := "off the beach" if at.x < -12.0 else ("by the dock" if absf(at.x - 3.5) < 6.0 else "out in the harbour")
	hud.toast("A feeding frenzy %s! Rare fish are biting there for a minute." % where)
	audio.play("whistle")


func _on_frenzy_end() -> void:
	hud.toast("The frenzy's died down.")


## A shadow's size class, from what could be biting at that spot right now.
func _roll_shadow(pos: Vector2) -> int:
	return sea.roll_shadow(harbour.zone_at(pos.x, pos.y), bait_key(), rod_tier(), _rng.randf())


func _logged_here() -> int:
	var n := 0
	for id in save.log:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and (e.cat == "fish" or e.cat == "legend") and e.z != "unknown":
			n += 1
	return n


func _total_here() -> int:
	var n := 0
	for e in sea.items:
		if (e.cat == "fish" or e.cat == "legend") and e.z != "unknown" and e.how != "pot":
			n += 1
	return n


func _icon(id: String) -> Texture2D:
	var path := "res://art/fish2/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://art/fish/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


func _tint() -> Color:
	if variant == "g":
		return GOLD_TINT
	if variant == "a":
		return ALBINO_TINT
	return Color.WHITE


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

	splash = _particles(Color(0.92, 0.98, 1.0), 28, 0.7, 1.6, 3.4, -9.8, 0.09)
	ink = _particles(Color(0.12, 0.08, 0.18), 40, 1.4, 0.2, 0.7, 0.4, 0.22)
	ink.spread = 180.0

	jumper = Sprite3D.new()
	jumper.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	jumper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	jumper.shaded = true
	jumper.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	jumper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	jumper.visible = false
	add_child(jumper)


func _particles(color: Color, amount: int, life: float, v_min: float, v_max: float, gravity: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color = color
	var drop := QuadMesh.new()
	drop.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	drop.material = mat
	p.mesh = drop
	add_child(p)
	return p


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
	var water_y: float = harbour.water_level_at(p.x, p.z)
	p.y = water_y + sin(_bob_t * 2.6) * 0.025 - _dip
	bobber.global_position = p


## A little "+42 Shells" that rises and fades above the fisher.
func _float_text(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = alert.font
	l.font_size = 56
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Color(1.0, 0.85, 0.4)
	l.outline_modulate = Color(0.15, 0.08, 0.04)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", at.y + 1.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)


func _splash(at: Vector3) -> void:
	var water_y: float = harbour.water_level_at(at.x, at.z)
	splash.global_position = Vector3(at.x, water_y + 0.02, at.z)
	splash.restart()


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	player.can_move = s == State.IDLE
	if s == State.IDLE:
		if player.pose == "cast":
			player.pose = ""
	elif s != State.LANDED:
		player.pose = "cast"
