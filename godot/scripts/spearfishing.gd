extends CanvasLayer
## Spearfishing: a breath-hold dive from your boat over clear water, seen side-on.
## Swim with {move}, fire the speargun with {action} (it takes a moment to reload), and
## come up with {cancel}. Your breath runs out in about half a minute; jellyfish sting it
## away faster. Faster, rarer fish dart off when you get close. Up to five fish fit on your
## stringer, and they're all yours when you surface.

const Sea := preload("res://scripts/sea.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const BREATH := 32.0
const STRINGER := 5
const FISH_ON_SCREEN := 7
const WATER := {
	"reef": [Color(0.3, 0.78, 0.86), Color(0.04, 0.27, 0.46)], "kelp": [Color(0.32, 0.62, 0.52), Color(0.03, 0.16, 0.18)],
	"shallows": [Color(0.55, 0.88, 0.86), Color(0.16, 0.46, 0.56)], "wreck": [Color(0.28, 0.47, 0.6), Color(0.03, 0.07, 0.16)],
	"lagoon": [Color(0.45, 0.92, 0.86), Color(0.1, 0.46, 0.62)], "seagrass": [Color(0.38, 0.76, 0.66), Color(0.07, 0.28, 0.33)],
}
const FLOOR := {"reef": Color(0.9, 0.8, 0.62), "kelp": Color(0.32, 0.28, 0.24), "shallows": Color(0.92, 0.84, 0.66),
	"wreck": Color(0.3, 0.3, 0.32), "lagoon": Color(0.96, 0.9, 0.78), "seagrass": Color(0.62, 0.6, 0.45)}


## Draws the whole dive.
class Scene extends Control:
	var dive: CanvasLayer

	func _draw() -> void:
		var d: CanvasLayer = dive
		var s := size
		var top: Color = d.col_top
		var deep: Color = d.col_deep
		var ground: Color = d.col_floor
		var bands := 24
		for i in bands:
			var k := float(i) / bands
			draw_rect(Rect2(0.0, s.y * k, s.x, s.y / bands + 1.0), top.lerp(deep, k))
		# the surface, far above
		draw_rect(Rect2(0.0, 0.0, s.x, d.surface_y()), Color(0.85, 0.95, 1.0, 0.25))
		for i in 12:
			var x := fposmod(i * 190.0 + d.t * 30.0, s.x + 200.0) - 100.0
			draw_line(Vector2(x, d.surface_y()), Vector2(x + 60.0, d.surface_y()), Color(1, 1, 1, 0.5), 3.0)
		# light shafts
		for i in 6:
			var x := s.x * (0.1 + 0.17 * i) + sin(d.t * 0.4 + i) * 40.0
			var w := 60.0 + 30.0 * sin(i * 1.7)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w * 2.6 + 120.0, s.y), Vector2(x + 120.0, s.y)]),
				Color(1.0, 1.0, 0.9, 0.05))
		# far rocks
		for r: Dictionary in d.rocks:
			var c: Color = deep.lerp(top, 0.25)
			c.a = 0.7
			draw_colored_polygon(r.poly, c)
		# seabed
		var fy: float = d.floor_y()
		draw_rect(Rect2(0.0, fy, s.x, s.y - fy), ground)
		for i in 40:
			var x := fposmod(i * 97.0, s.x)
			draw_rect(Rect2(x, fy + 6.0 + fposmod(i * 37.0, s.y - fy - 10.0), 6.0, 3.0), ground.darkened(0.2))
		# kelp, seagrass, coral or the wreck
		for p: Dictionary in d.plants:
			var base: Vector2 = p.at
			var h: float = p.h
			var col: Color = p.col
			if p.kind == "coral":
				draw_circle(base + Vector2(0, -h * 0.4), h * 0.4, col)
				draw_circle(base + Vector2(-h * 0.3, -h * 0.25), h * 0.28, col.lightened(0.15))
				draw_circle(base + Vector2(h * 0.3, -h * 0.3), h * 0.3, col.darkened(0.1))
			else:
				var pts := PackedVector2Array()
				for j in 10:
					var k := float(j) / 9.0
					pts.append(base + Vector2(sin(d.t * 1.2 + base.x * 0.01 + k * 3.0) * 18.0 * k, -h * k))
				draw_polyline(pts, col, 7.0 if p.kind == "kelp" else 4.0)
		if d.zone == "wreck":
			var wx := s.x * 0.62
			draw_colored_polygon(PackedVector2Array([Vector2(wx - 260, fy + 10), Vector2(wx - 220, fy - 120), Vector2(wx + 240, fy - 150),
				Vector2(wx + 300, fy + 10)]), Color(0.16, 0.14, 0.13, 0.9))
			draw_line(Vector2(wx + 20, fy - 140), Vector2(wx + 40, fy - 380), Color(0.16, 0.14, 0.13, 0.9), 12.0)
		# jellyfish
		for j: Dictionary in d.jellies:
			var at: Vector2 = j.pos
			draw_circle(at, 22.0, Color(0.95, 0.7, 0.95, 0.55))
			for k in 4:
				var x := at.x - 14.0 + k * 9.0
				draw_line(Vector2(x, at.y + 8.0), Vector2(x + sin(d.t * 3.0 + k) * 6.0, at.y + 52.0), Color(0.95, 0.75, 0.95, 0.5), 2.0)
		# fish
		for f: Dictionary in d.fish:
			var tex: Texture2D = f.tex
			if tex == null:
				continue
			var w: float = f.w
			var h := w * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
			var at: Vector2 = f.pos
			var flip := float(f.dir) > 0.0  # the art faces left
			draw_set_transform(at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
			draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# spears
		for sp: Dictionary in d.spears:
			var p: Vector2 = sp.pos
			var dir: float = sp.dir
			draw_line(p - Vector2(dir * 70.0, 0.0), p, Color(0.85, 0.85, 0.8), 4.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(dir * 14.0, 0), p + Vector2(0, -6), p + Vector2(0, 6)]), Color(0.9, 0.9, 0.85))
		_draw_diver(d)
		# bubbles
		for b: Dictionary in d.bubbles:
			draw_arc(b.pos, float(b.r), 0.0, TAU, 10, Color(1, 1, 1, 0.6), 2.0)
		if d.hurt > 0.0:
			draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.2, 0.2, d.hurt * 0.3))

	func _draw_diver(d: CanvasLayer) -> void:
		var p: Vector2 = d.diver
		var f: float = d.facing
		var kick := sin(d.t * (9.0 if d.moving else 3.0)) * 10.0
		var suit := Color(0.12, 0.16, 0.28)
		# fins
		draw_colored_polygon(PackedVector2Array([p + Vector2(-f * 48, -4), p + Vector2(-f * 86, -14 + kick), p + Vector2(-f * 86, 8 + kick)]),
			Color(0.95, 0.75, 0.2))
		# legs and body
		draw_line(p + Vector2(-f * 10, 0), p + Vector2(-f * 50, -2 + kick * 0.3), suit, 12.0)
		draw_line(p + Vector2(-f * 10, 4), p + Vector2(-f * 50, 6 - kick * 0.3), suit, 12.0)
		draw_circle(p + Vector2(f * 6, 0), 16.0, suit)
		draw_line(p + Vector2(-f * 8, 0), p + Vector2(f * 26, 0), suit, 22.0)
		# head and mask
		draw_circle(p + Vector2(f * 42, -4), 12.0, Color(0.85, 0.66, 0.5))
		draw_rect(Rect2(p + Vector2(f * 42 + (0.0 if f > 0 else -12.0), -10), Vector2(12.0, 8.0)), Color(0.3, 0.8, 0.9))
		draw_line(p + Vector2(f * 36, -14), p + Vector2(f * 30, -30), Color(0.95, 0.75, 0.2), 4.0)  # snorkel
		# speargun
		var ready: bool = d.reload <= 0.0
		draw_line(p + Vector2(f * 24, 10), p + Vector2(f * 84, 8), Color(0.35, 0.25, 0.18), 6.0)
		if ready:
			draw_line(p + Vector2(f * 30, 6), p + Vector2(f * 100, 6), Color(0.85, 0.85, 0.8), 3.0)


var kit: Node
var fishing: Node
var sea: Node
var hud: CanvasLayer
var audio: Node
var is_open := false
var zone := "reef"
var col_top := Color(0.3, 0.78, 0.86)
var col_deep := Color(0.04, 0.27, 0.46)
var col_floor := Color(0.9, 0.8, 0.62)
var t := 0.0
var breath := BREATH
var diver := Vector2.ZERO
var facing := 1.0
var moving := false
var reload := 0.0
var hurt := 0.0
var fish: Array[Dictionary] = []
var spears: Array[Dictionary] = []
var jellies: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var rocks: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var caught: Array = []  # [entry, cm]
var _vel := Vector2.ZERO
var _pool: Array = []
var _rng := RandomNumberGenerator.new()
var _scene: Scene
var _breath_bar: Control
var _breath_fill: ColorRect
var _status: Label
var _hint: Label
var _ending := 0.0


func setup(k: Node, f: Node, s: Node, h: CanvasLayer, a: Node) -> void:
	kit = k
	fishing = f
	sea = s
	hud = h
	audio = a
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rng.randomize()
	_scene = Scene.new()
	_scene.dive = self
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scene)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 20.0
	top.offset_left = -300.0
	top.offset_right = 300.0
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top)
	var title := UI.label("Breath", 22, UI.CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	_breath_bar = ColorRect.new()
	(_breath_bar as ColorRect).color = Color(0.04, 0.05, 0.1, 0.9)
	_breath_bar.custom_minimum_size = Vector2(600.0, 22.0)
	top.add_child(_breath_bar)
	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.6, 0.9, 1.0)
	_breath_fill.position = Vector2(3.0, 3.0)
	_breath_fill.size = Vector2(594.0, 16.0)
	_breath_bar.add_child(_breath_fill)
	_status = UI.label("", 22, UI.GOLD, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_status)
	_hint = Glyphs.bind(UI.label("", 20, UI.CREAM), "{move} swim   {action} fire the speargun   {cancel} surface")
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -50.0
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func surface_y() -> float:
	return _scene.size.y * 0.08


func floor_y() -> float:
	return _scene.size.y * 0.84


func start(where: String) -> void:
	zone = where if WATER.has(where) else "reef"
	col_top = WATER[zone][0]
	col_deep = WATER[zone][1]
	col_floor = FLOOR[zone]
	is_open = true
	visible = true
	get_tree().paused = true
	hud.modal = true
	t = 0.0
	breath = BREATH
	reload = 0.0
	hurt = 0.0
	_ending = 0.0
	caught.clear()
	fish.clear()
	spears.clear()
	bubbles.clear()
	jellies.clear()
	var s := get_viewport().get_visible_rect().size
	_scene.size = s
	diver = Vector2(s.x * 0.3, s.y * 0.25)
	_vel = Vector2.ZERO
	facing = 1.0
	_pool = _fish_pool()
	_build_scenery(s)
	for i in FISH_ON_SCREEN:
		_spawn_fish(true)
	for i in (2 if zone in ["reef", "lagoon", "shallows"] else 1):
		jellies.append({"pos": Vector2(_rng.randf_range(s.x * 0.4, s.x * 0.9), _rng.randf_range(s.y * 0.25, s.y * 0.7)),
			"v": Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-8.0, 8.0))})
	audio.play("splash", 0.0, 0.8)
	audio.set_amb("bubbles", 0.6)
	_status.text = "Stringer 0/%d" % STRINGER


func _fish_pool() -> Array:
	var E: Dictionary = sea.env
	var out: Array = []
	for e: Dictionary in sea.items:
		if str(e.cat) != "fish" or str(e.how) != "fish" or str(e.z) != zone or not sea.cond_ok(e, E):
			continue
		if Sea.size_class(e) > 2:
			continue
		out.append([e, float(sea.rarw[mini(int(e.r), sea.rarw.size() - 1)])])
	return out


func _build_scenery(s: Vector2) -> void:
	rocks.clear()
	plants.clear()
	var fy := floor_y()
	for i in 5:
		var x := _rng.randf_range(0.0, s.x)
		var w := _rng.randf_range(160.0, 360.0)
		var h := _rng.randf_range(80.0, 220.0)
		rocks.append({"poly": PackedVector2Array([Vector2(x - w * 0.5, fy + 4), Vector2(x - w * 0.3, fy - h * 0.7), Vector2(x, fy - h),
			Vector2(x + w * 0.35, fy - h * 0.6), Vector2(x + w * 0.5, fy + 4)])})
	var kind := "grass"
	match zone:
		"kelp":
			kind = "kelp"
		"reef", "lagoon":
			kind = "coral"
	var n := 26 if kind == "kelp" else 18
	for i in n:
		var col := Color(0.2, 0.45, 0.2)
		var h := _rng.randf_range(60.0, 140.0)
		if kind == "kelp":
			col = Color(0.35, 0.42, 0.15).lerp(Color(0.5, 0.45, 0.1), _rng.randf())
			h = _rng.randf_range(s.y * 0.35, s.y * 0.7)
		elif kind == "coral":
			col = [Color(0.95, 0.45, 0.5), Color(0.95, 0.65, 0.3), Color(0.6, 0.45, 0.85), Color(0.35, 0.8, 0.7)][_rng.randi() % 4]
			h = _rng.randf_range(40.0, 110.0)
		plants.append({"at": Vector2(_rng.randf_range(0.0, s.x), fy + _rng.randf_range(2.0, 20.0)), "h": h, "col": col, "kind": kind})


func _spawn_fish(anywhere: bool) -> void:
	var e: Variant = Sea.pick_w(_pool, _rng.randf())
	if e == null:
		return
	var s := _scene.size
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	var x := _rng.randf_range(0.0, s.x) if anywhere else (-120.0 if dir > 0.0 else s.x + 120.0)
	var y := _rng.randf_range(surface_y() + 80.0, floor_y() - 40.0)
	var cm := Sea.roll_size(e, _rng.randf())
	var d := Sea.difficulty(e)
	fish.append({"e": e, "tex": fishing.icon_for(str(e.id)), "pos": Vector2(x, y), "dir": dir, "base_y": y, "cm": cm,
		"w": clampf(cm * 2.4, 46.0, 240.0), "speed": 50.0 + d * 26.0, "skit": d >= 3, "dart": 0.0, "ph": _rng.randf() * TAU})


func _process(delta: float) -> void:
	if not is_open:
		return
	t += delta
	var s := _scene.size
	if _ending > 0.0:
		_ending -= delta
		if _ending <= 0.0:
			_surface()
		_scene.queue_redraw()
		return
	# swimming
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = input.length() > 0.1
	_vel = _vel.lerp(input * 330.0, minf(delta * 3.0, 1.0))
	diver += _vel * delta
	diver.x = clampf(diver.x, 60.0, s.x - 60.0)
	diver.y = clampf(diver.y, surface_y() + 30.0, floor_y() - 20.0)
	if absf(input.x) > 0.2:
		facing = signf(input.x)
	# breath
	breath -= delta * (1.15 if moving else 0.85)
	hurt = maxf(hurt - delta * 2.0, 0.0)
	var frac := clampf(breath / BREATH, 0.0, 1.0)
	_breath_fill.size.x = 594.0 * frac
	_breath_fill.color = Color(1.0, 0.4, 0.35) if frac < 0.25 else Color(0.6, 0.9, 1.0)
	if breath <= 0.0:
		hud.toast("Out of breath! You kick for the surface.")
		_surface()
		return
	if frac < 0.25 and int(t * 3.0) % 3 == 0:
		_status.add_theme_color_override("font_color", UI.BAD)
	else:
		_status.add_theme_color_override("font_color", UI.GOLD)
	# shooting
	reload -= delta
	if Input.is_action_just_pressed("action") and reload <= 0.0:
		reload = 0.75
		spears.append({"pos": diver + Vector2(facing * 100.0, 6.0), "dir": facing, "life": 0.55})
		audio.play("whoosh", -2.0, 1.5)
	if Input.is_action_just_pressed("cancel"):
		_surface()
		return
	_step_spears(delta, s)
	_step_fish(delta, s)
	_step_jellies(delta, s)
	# bubbles from the snorkel
	if _rng.randf() < delta * (6.0 if moving else 2.5):
		bubbles.append({"pos": diver + Vector2(facing * 34.0, -26.0), "r": _rng.randf_range(3.0, 7.0)})
	var keep: Array[Dictionary] = []
	for b in bubbles:
		b.pos = (b.pos as Vector2) + Vector2(sin(t * 4.0 + float(b.r)) * 20.0, -90.0) * delta
		if (b.pos as Vector2).y > surface_y():
			keep.append(b)
	bubbles = keep
	_scene.queue_redraw()


func _step_spears(delta: float, s: Vector2) -> void:
	var keep: Array[Dictionary] = []
	for sp in spears:
		sp.pos = (sp.pos as Vector2) + Vector2(float(sp.dir) * 1100.0, 0.0) * delta
		sp.life = float(sp.life) - delta
		var hit := -1
		for i in fish.size():
			var f := fish[i]
			var fp: Vector2 = f.pos
			var half_w := float(f.w) * 0.45
			var half_h := float(f.w) * 0.22 + 6.0
			var tip: Vector2 = sp.pos
			if absf(tip.x - fp.x) < half_w and absf(tip.y - fp.y) < half_h:
				hit = i
				break
		if hit >= 0:
			var f := fish[hit]
			caught.append([f.e, f.cm])
			fish.remove_at(hit)
			audio.play("good", -2.0)
			audio.play("splash", -6.0, 1.3)
			_status.text = "Speared %s!   Stringer %d/%d" % [_with_article(str((f.e as Dictionary).n)), caught.size(), STRINGER]
			if caught.size() >= STRINGER:
				_status.text = "Your stringer's full! Heading up..."
				_ending = 1.2
			continue
		if float(sp.life) > 0.0 and (sp.pos as Vector2).x > -50.0 and (sp.pos as Vector2).x < s.x + 50.0:
			keep.append(sp)
	spears = keep


func _step_fish(delta: float, s: Vector2) -> void:
	var keep: Array[Dictionary] = []
	for f in fish:
		var fp: Vector2 = f.pos
		var spd := float(f.speed)
		f.dart = maxf(float(f.dart) - delta, 0.0)
		if bool(f.skit) and float(f.dart) <= 0.0 and fp.distance_to(diver) < 190.0:
			f.dart = 0.8
			f.dir = signf(fp.x - diver.x) if absf(fp.x - diver.x) > 1.0 else float(f.dir)
			f.base_y = clampf(fp.y + _rng.randf_range(-120.0, 120.0), surface_y() + 60.0, floor_y() - 40.0)
		if float(f.dart) > 0.0:
			spd *= 2.8
		fp.x += float(f.dir) * spd * delta
		fp.y = lerpf(fp.y, float(f.base_y) + sin(t * 1.5 + float(f.ph)) * 18.0, minf(delta * 2.0, 1.0))
		f.pos = fp
		if fp.x > -200.0 and fp.x < s.x + 200.0:
			keep.append(f)
	fish = keep
	while fish.size() < FISH_ON_SCREEN and not _pool.is_empty():
		_spawn_fish(false)


func _step_jellies(delta: float, s: Vector2) -> void:
	for j in jellies:
		var p: Vector2 = j.pos
		var v: Vector2 = j.v
		p += (v + Vector2(0.0, sin(t * 1.3) * 12.0)) * delta
		if p.x < 40.0 or p.x > s.x - 40.0:
			v.x = -v.x
		if p.y < surface_y() + 60.0 or p.y > floor_y() - 60.0:
			v.y = -v.y
		j.pos = p
		j.v = v
		if hurt <= 0.0 and p.distance_to(diver) < 46.0:
			breath -= 6.0
			hurt = 1.0
			_vel = (diver - p).normalized() * 420.0
			audio.play("error", -2.0)
			_status.text = "Ouch! A jellyfish sting. Breath lost."


func _surface() -> void:
	is_open = false
	visible = false
	hud.modal = false
	audio.set_amb("bubbles", 0.0)
	audio.play("splash", -2.0, 1.1)
	get_tree().set_deferred("paused", false)
	var got := caught.duplicate()
	caught.clear()
	kit.call_deferred("dive_done", got)


static func _with_article(n: String) -> String:
	return ("an " if n.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + n
