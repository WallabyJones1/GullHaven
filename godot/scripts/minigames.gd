extends Node3D
## Three little games:
## - Stone skipping on the beach by your hut (Pip's challenge). Space stops the power bar;
##   then press Space each time the closing ring meets the circle to skip again.
## - The bay race (Bosun Pell's challenge): take any boat to the red-and-white buoy off the
##   end of Gullhaven's middle dock and press Space. Round six buoys and back, against the clock.
## - Darts in the Gull & Anchor (Rosa's challenge): the aim drifts; hold Space to steady
##   your hand, let go to throw. Three darts.
## Records and prizes are kept in the save; the Journal shows them.

const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const SKIP_SPOT := Vector2(433.0, 690.0)
const RACE_START := Vector2(492.0, 577.0)
const RACE := [Vector2(530.0, 600.0), Vector2(575.0, 640.0), Vector2(605.0, 700.0), Vector2(560.0, 770.0),
	Vector2(480.0, 750.0), Vector2(455.0, 660.0), Vector2(492.0, 577.0)]
const RACE_PRIZES := [[120.0, 300], [95.0, 800]]  # under this many seconds: this many Shells (first time each)
const SKIP_PRIZES := [[5, 150], [10, 500]]
const DART_PRIZES := [[100, 200], [150, 600]]


## A ring that closes on a circle (skipping), or a dartboard with a drifting aim.
class Gauge extends Control:
	var mode := ""  # "power", "ring", "darts"
	var value := 0.0  # power 0..1, or ring radius scale
	var aim := Vector2.ZERO  # darts: -1..1
	var darts: Array = []  # darts: thrown positions
	var good := 0.0  # ring: the tolerance band

	func _draw() -> void:
		var c := size * 0.5
		match mode:
			"power":
				var w := 360.0
				var r := Rect2(c.x - w * 0.5, c.y + 120.0, w, 26.0)
				draw_rect(r.grow(4.0), Color(0.05, 0.06, 0.1, 0.85))
				draw_rect(Rect2(r.position.x + w * 0.62, r.position.y, w * 0.22, r.size.y), Color(0.35, 0.8, 0.45, 0.6))
				draw_rect(Rect2(r.position.x, r.position.y, w * value, r.size.y), Color(1.0, 0.82, 0.3))
			"ring":
				var at := c + Vector2(0.0, 110.0)
				draw_arc(at, 34.0, 0.0, TAU, 40, Color(0.95, 0.95, 0.9, 0.9), 4.0)
				draw_arc(at, 34.0 * (1.0 + good), 0.0, TAU, 40, Color(0.4, 0.9, 0.5, 0.35), 34.0 * good * 2.0)
				draw_arc(at, 34.0 * value, 0.0, TAU, 48, Color(1.0, 0.8, 0.3), 3.0)
			"darts":
				var R := minf(size.x, size.y) * 0.3
				var rings := [[1.0, Color(0.15, 0.12, 0.12)], [0.92, Color(0.92, 0.88, 0.78)], [0.72, Color(0.2, 0.2, 0.22)],
					[0.5, Color(0.92, 0.88, 0.78)], [0.3, Color(0.25, 0.55, 0.3)], [0.12, Color(0.8, 0.22, 0.2)], [0.05, Color(1.0, 0.85, 0.3)]]
				for ring in rings:
					draw_circle(c, R * float(ring[0]), ring[1])
				for d in darts:
					var p: Vector2 = c + Vector2(d) * R
					draw_line(p, p + Vector2(10, -14), Color(0.9, 0.2, 0.2), 3.0)
					draw_circle(p, 3.0, Color(0.1, 0.1, 0.1))
				var a := c + aim * R
				draw_arc(a, 10.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.9), 2.0)
				draw_line(a + Vector2(-16, 0), a + Vector2(16, 0), Color(1, 1, 1, 0.8), 1.5)
				draw_line(a + Vector2(0, -16), a + Vector2(0, 16), Color(1, 1, 1, 0.8), 1.5)


var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var save: Dictionary
var boats: Node3D
var interiors: Node3D
var progress: Node  # fisher XP
var playing := ""  # "skip", "darts" (modal); the race runs alongside normal play
var _layer: CanvasLayer
var _gauge: Gauge
var _title: Label
var _info: Label
var _t := 0.0
# skipping
var _skips := 0
var _stone: Sprite3D
var _stone_from := Vector3.ZERO
var _stone_to := Vector3.ZERO
var _hop_len := 0.0
var _phase := ""
# darts
var _darts := 0
var _score := 0
var _steady := 0.0
# the race
var _racing := false
var _race_i := 0
var _race_t := 0.0
var _buoys: Array[Node3D] = []
var _start_buoy: Node3D
var _marker: MeshInstance3D


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, sv: Dictionary, b: Node3D, i: Node3D) -> void:
	world = w
	player = p
	hud = h
	audio = a
	save = sv
	boats = b
	interiors = i
	_layer = CanvasLayer.new()
	_layer.layer = 14
	_layer.visible = false
	add_child(_layer)
	_gauge = Gauge.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_gauge)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 90.0
	top.offset_left = -400.0
	top.offset_right = 400.0
	_layer.add_child(top)
	_title = UI.label("", 36, UI.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_title)
	_info = UI.label("", 20, UI.CREAM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_info)
	_stone = Sprite3D.new()
	_stone.texture = load("res://art/decor/skip_stone.png")
	_stone.pixel_size = 1.0 / 24.0
	_stone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_stone.visible = false
	add_child(_stone)
	_build_buoys()


func records() -> Dictionary:
	return save.records


# --- what you can start -------------------------------------------------------------------

func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if playing != "":
		return {}
	var p2 := Vector2(pos.x, pos.z)
	if not player.riding and not interiors.is_inside():
		var d := p2.distance_to(SKIP_SPOT)
		if d < 3.0:
			return {"kind": "skip", "dist": d, "text": "Space: Skip a stone"}
	if player.riding and not _racing:
		var d2 := p2.distance_to(RACE_START)
		if d2 < 9.0:
			return {"kind": "race", "dist": 0.5, "text": "Space: Start the bay race"}
	return {}


func use(it: Dictionary) -> void:
	match str(it.kind):
		"skip":
			_start_skip()
		"race":
			_start_race()


## Darts: started from the dartboard inside the tavern.
func start_darts() -> void:
	if playing != "":
		return
	playing = "darts"
	_darts = 0
	_score = 0
	_steady = 0.0
	_gauge.darts = []
	_gauge.mode = "darts"
	_open("Darts", "Hold Space to steady your aim, let go to throw. Three darts.   Esc: stop")


func _open(title: String, info: String) -> void:
	_layer.visible = true
	_title.text = title
	_info.text = Glyphs.plain(info)
	hud.modal = true
	player.can_move = false
	_t = 0.0


func _close() -> void:
	playing = ""
	_layer.visible = false
	_stone.visible = false
	hud.modal = false
	hud.block_input(0.3)
	player.can_move = true


func _process(delta: float) -> void:
	_t += delta
	_spin_buoys(delta)
	if _racing:
		_race(delta)
	match playing:
		"skip":
			_skip(delta)
		"darts":
			_dart(delta)
	if playing != "":
		_gauge.queue_redraw()


# --- stone skipping ---------------------------------------------------------------------------

func _start_skip() -> void:
	playing = "skip"
	_skips = 0
	_phase = "power"
	_gauge.mode = "power"
	_open("Stone skipping", "Space to throw: stop the bar in the green.   Esc: stop")


func _skip(delta: float) -> void:
	if Input.is_action_just_pressed("cancel"):
		_close()
		return
	match _phase:
		"power":
			_gauge.value = 0.5 + 0.5 * sin(_t * 3.2 - PI * 0.5)
			if Input.is_action_just_pressed("action"):
				var q := 1.0 - clampf(absf(_gauge.value - 0.73) / 0.4, 0.0, 1.0)  # how well thrown
				_hop_len = lerpf(2.5, 7.0, q)
				_gauge.good = lerpf(0.08, 0.22, q)
				var dir: Vector3 = player.facing
				dir.y = 0.0
				dir = dir.normalized()
				player.face(dir)
				player.pose = "cast"
				_stone_from = player.global_position + Vector3(0.0, 1.2, 0.0) + dir * 0.4
				_stone_to = _stone_from + dir * _hop_len * 1.4
				_stone_to.y = float(world.water_level_at(_stone_to.x, _stone_to.z))
				_stone.visible = true
				_phase = "fly"
				_t = 0.0
				audio.play("whoosh", -6.0, 1.3)
		"fly":
			var k := minf(_t / 0.45, 1.0)
			var p := _stone_from.lerp(_stone_to, k)
			p.y += sin(k * PI) * 0.6
			_stone.global_position = p
			if k >= 1.0:
				if not world.is_water(_stone_to.x, _stone_to.z):
					_skip_end("Clack! It landed on dry ground.")
					return
				_bounce()
		"ring":
			var dur := maxf(0.32, 0.8 * pow(0.92, _skips))
			_gauge.value = 3.0 - 2.4 * (_t / dur)
			var p2 := _stone_from.lerp(_stone_to, minf(_t / dur, 1.0))
			p2.y += sin(minf(_t / dur, 1.0) * PI) * 0.35 * maxf(0.3, _hop_len / 6.0)
			_stone.global_position = p2
			if Input.is_action_just_pressed("action"):
				if absf(_gauge.value - 1.0) <= _gauge.good:
					_bounce()
				else:
					_skip_end("Plop. %s" % _skip_count_text())
				return
			if _gauge.value < 1.0 - _gauge.good:
				_skip_end("Plop. %s" % _skip_count_text())


func _bounce() -> void:
	_skips += 1
	audio.play("plop", -4.0, 1.2 + _skips * 0.05)
	_splash_ring(_stone_to)
	_hop_len *= 0.82
	_gauge.good *= 0.93
	var dir := (_stone_to - _stone_from)
	dir.y = 0.0
	dir = dir.normalized()
	_stone_from = _stone_to
	_stone_to = _stone_from + dir * _hop_len
	_stone_to.y = float(world.water_level_at(_stone_to.x, _stone_to.z))
	_phase = "ring"
	_gauge.mode = "ring"
	_t = 0.0
	_info.text = Glyphs.plain("%d skip%s! {action} when the ring meets the circle." % [_skips, "" if _skips == 1 else "s"])
	if not world.is_water(_stone_to.x, _stone_to.z):
		_skip_end("It skipped right up onto the sand! %s" % _skip_count_text())


func _skip_count_text() -> String:
	return "%d skip%s." % [_skips, "" if _skips == 1 else "s"]


func _skip_end(line: String) -> void:
	_splash_ring(_stone.global_position)
	_stone.visible = false
	player.pose = ""
	var rec: Dictionary = records()
	var best := int(rec.get("skip", 0))
	var msg := line
	if _skips > best:
		rec["skip"] = _skips
		if best > 0:
			msg += "  A new record!"
			audio.play("fanfare1", -4.0)
	msg += _prize("skip", _skips, SKIP_PRIZES, "Pip")
	SaveGame.write(save)
	hud.toast(msg)
	_close()


## First time over each prize line pays out.
func _prize(game: String, score: float, prizes: Array, who: String, lower_better := false) -> String:
	var rec: Dictionary = records()
	var paid: Array = rec.get(game + "_paid", [])
	var out := ""
	for i in prizes.size():
		var line: float = float(prizes[i][0])
		var ok := score <= line if lower_better else score >= line
		if ok and not paid.has(str(i)):
			paid.append(str(i))
			var shells := int(prizes[i][1])
			save.shells = int(save.shells) + shells
			hud.set_shells(save.shells)
			audio.play("coin", -2.0)
			if progress:
				progress.add(30 + shells / 10)
			out += "  %s's prize: +%d Shells!" % [who, shells]
	rec[game + "_paid"] = paid
	return out


func _splash_ring(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.2
	t.outer_radius = 0.26
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.7)
	t.material = m
	ring.mesh = t
	add_child(ring)
	ring.global_position = Vector3(at.x, float(world.water_level_at(at.x, at.z)) + 0.03, at.z)
	ring.scale = Vector3(1.0, 0.1, 1.0)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5.0, 0.1, 5.0), 1.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.chain().tween_callback(ring.queue_free)


# --- darts --------------------------------------------------------------------------------------

func _dart(delta: float) -> void:
	if _darts >= 3:
		return
	if Input.is_action_just_pressed("cancel"):
		_close()
		return
	var holding := Input.is_action_pressed("action")
	_steady = clampf(_steady + (delta if holding else -delta * 2.0), 0.0, 2.2)
	# a steady hand for about a second, then it starts to shake
	var wobble := 0.45 * (1.0 - smoothstep(0.0, 0.9, _steady)) + 0.6 * smoothstep(1.2, 2.2, _steady) + 0.05
	_gauge.aim = Vector2(sin(_t * 1.7) + 0.5 * sin(_t * 3.9 + 1.0), cos(_t * 1.3) + 0.5 * sin(_t * 4.7)) * wobble * 0.7
	if Input.is_action_just_released("action"):
		var p := _gauge.aim
		_gauge.darts.append(p)
		var r := p.length()
		var pts := 0
		if r <= 0.05:
			pts = 60
		elif r <= 0.12:
			pts = 40
		elif r <= 1.0:
			pts = int(round(30.0 * (1.0 - r))) + 5
		_score += pts
		_darts += 1
		_steady = 0.0
		audio.play("thud", -4.0, 1.4)
		_info.text = "%s! %d points. Total %d.%s" % ["Bullseye" if pts == 60 else ("Thunk" if pts > 0 else "Missed the board"), pts, _score,
			"" if _darts >= 3 else "   Dart %d of 3" % (_darts + 1)]
		if _darts >= 3:
			var rec: Dictionary = records()
			var best := int(rec.get("darts", 0))
			var msg := "Darts: %d points." % _score
			if _score > best:
				rec["darts"] = _score
				if best > 0:
					msg += "  A new record!"
			msg += _prize("darts", _score, DART_PRIZES, "Rosa")
			SaveGame.write(save)
			hud.toast(msg)
			await get_tree().create_timer(1.0).timeout
			_close()


# --- the bay race ---------------------------------------------------------------------------------

func _buoy(at: Vector2, start: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(at.x, 0.0, at.y)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.2, 0.18)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.94, 0.9)
	for i in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.35 - i * 0.06
		c.bottom_radius = 0.4 - i * 0.06
		c.height = 0.4
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = red if i % 2 == 0 else white
		mi.position.y = 0.2 + i * 0.4
		root.add_child(mi)
	if start:
		var flag := QuadMesh.new()
		flag.size = Vector2(0.8, 0.5)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(1.0, 0.85, 0.3)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material = fm
		var f := MeshInstance3D.new()
		f.mesh = flag
		f.position = Vector3(0.4, 1.9, 0.0)
		root.add_child(f)
	return root


func _build_buoys() -> void:
	_start_buoy = _buoy(RACE_START, true)
	for i in RACE.size() - 1:
		var b := _buoy(RACE[i], false)
		b.visible = false
		_buoys.append(b)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.6
	ring.outer_radius = 3.0
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.85, 0.3, 0.6)
	ring.material = rm
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.scale = Vector3(1.0, 0.15, 1.0)
	_marker.visible = false
	add_child(_marker)


func _spin_buoys(_delta: float) -> void:
	var wl: float = world.sea_level
	var all: Array[Node3D] = [_start_buoy]
	all.append_array(_buoys)
	for b in all:
		b.global_position.y = wl - 0.1 + sin(_t * 1.5 + b.global_position.x) * 0.06
		b.rotation.z = sin(_t * 1.1 + b.global_position.z) * 0.06


func _start_race() -> void:
	_racing = true
	_race_i = 0
	_race_t = -3.0
	for b in _buoys:
		b.visible = true
	_show_marker()
	_gauge.mode = ""
	_layer.visible = true
	_title.text = "Bay race"
	audio.play("pin", -2.0, 0.8)
	hud.toast("Bay race! Round each buoy in turn and back to the start. Ready...")


func _show_marker() -> void:
	var at: Vector2 = RACE[_race_i]
	_marker.visible = true
	_marker.global_position = Vector3(at.x, float(world.sea_level) + 0.1, at.y)


func _race(delta: float) -> void:
	if not player.riding:
		_end_race("You stepped ashore, so the race is off.")
		return
	var was := _race_t
	_race_t += delta
	if was < 0.0:
		if int(ceil(was)) != int(ceil(_race_t)):
			audio.play("pin", -2.0, 1.0 if _race_t < 0.0 else 1.5)
		_info.text = "Starts in %d..." % int(ceil(-_race_t)) if _race_t < 0.0 else "Go!"
		return
	_marker.rotation.y += delta
	_marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 5.0)) * Vector3(1.0, 0.15, 1.0)
	_info.text = "%s     Buoy %d of %d" % [_clock(_race_t), _race_i + 1, RACE.size()]
	var at: Vector2 = RACE[_race_i]
	var p := player.global_position
	if Vector2(p.x, p.z).distance_to(at) < 7.0:
		audio.play("coin", -6.0, 1.0 + _race_i * 0.08)
		_race_i += 1
		if _race_i >= RACE.size():
			var rec: Dictionary = records()
			var best := float(rec.get("race", 0.0))
			var msg := "Finished the bay race in %s." % _clock(_race_t)
			if best <= 0.0 or _race_t < best:
				rec["race"] = _race_t
				if best > 0.0:
					msg += "  A new record!"
			msg += _prize("race", _race_t, RACE_PRIZES, "Bosun Pell", true)
			audio.play("fanfare2", -2.0)
			_end_race(msg)
			return
		_show_marker()


func _end_race(msg: String) -> void:
	_racing = false
	_marker.visible = false
	for b in _buoys:
		b.visible = false
	if playing == "":
		_layer.visible = false
	SaveGame.write(save)
	hud.toast(msg)


static func _clock(t: float) -> String:
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]


## For the Journal.
func journal_lines() -> Array[String]:
	var rec: Dictionary = records()
	var out: Array[String] = []
	var skip := int(rec.get("skip", 0))
	out.append("[b]Stone skipping[/b] (the beach by your hut): best %s. Pip pays out at 5 and 10 skips." % (("%d skips" % skip) if skip > 0 else "none yet"))
	var race := float(rec.get("race", 0.0))
	out.append("[b]The bay race[/b] (the buoy off Gullhaven's middle dock, in a boat): best %s. Bosun Pell pays out under 2:00 and 1:35." % (_clock(race) if race > 0.0 else "none yet"))
	var darts := int(rec.get("darts", 0))
	out.append("[b]Darts[/b] (the Gull & Anchor tavern): best %s. Rosa pays out at 100 and 150." % (("%d points" % darts) if darts > 0 else "none yet"))
	return out
