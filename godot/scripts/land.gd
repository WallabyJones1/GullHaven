extends Node3D
## Harbour Life: things to do on land between (or instead of) fishing trips.
## - Gran's garden beside the hut: till a bed, plant seeds, water them (rain does it for
##   you), and harvest. One real second is one town minute, so a turnip takes six minutes.
## - Foraging: chop wood from any tree, pick berries off bramble bushes, herbs from ferns,
##   wildflowers, stones from the little rocks, and mushrooms that pop up in the woods.
## - Mining: veins of coal, copper, iron, silver, gold and ember crystal in quarries round
##   the coast. Each rock comes back the next town day.
## - Hunting: rabbits, pheasants and boar on the mainland, ducks by the water, red deer in
##   the highlands. Face one with a bow and press Space to aim, then again to loose.
## - Crafting at Gran's workbench and cooking at the pot in the yard (land_menu.gd).
## - Farmer Bramble, Delve the smith and Ash the hunter buy, sell and tell you things.
## Five land skills grow as you go, and everything you do earns fisher XP too.

const D := preload("res://scripts/land_data.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const TREE_PREFIX := ["oak", "autumn", "pine", "birch", "palm", "willow", "dead"]
const RANGE_TREE := 1.8
const RANGE_SMALL := 1.3
const RANGE_BOULDER := 2.4
const RANGE_ROCK := 1.9
const HUNT_RANGE := 16.0
const FORAGE_SPOTS := 3
const ANIMALS_NEAR := 3

signal land_event(kind: String, what: String, n: int)

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var progress: Node
var dialogue: CanvasLayer
var interiors: Node3D
var menu: CanvasLayer  # land_menu.gd
var _root: Node3D
var _beds: Array = []  # {node, soil, crop, i}
var _rocks: Array = []  # {id, kind, pos, node, rubble, quarry}
var _forage: Array = []  # {id, node}
var _animals: Array = []  # {kind, node, home, target, vel, flee, t, alert}
var _bench: Sprite3D
var _pot: Sprite3D
var _sign: Sprite3D
var _soil_tex: Texture2D
var _wet_tex: Texture2D
var _forage_wait := 4.0
var _animal_wait := 6.0
var _tick := 0.0
var _rng := RandomNumberGenerator.new()
var _near_pos := Vector3.INF
var _near_facing := Vector3.ZERO
var _near_res := {}
var _near_t := 0.0
var _busy := 0.0  # a swing in progress
var _aim := {}  # hunting: the animal you're aiming at and the aim bar
var _aim_layer: CanvasLayer
var _aim_bar: AimBar
var _aim_label: Label
var _anim_tex := {}


func setup(w: Node3D, p: CharacterBody3D, c: Camera3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node) -> void:
	world = w
	player = p
	cam = c
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	_rng.randomize()
	_soil_tex = load("res://art/tex/soil.png")
	_wet_tex = load("res://art/tex/soil_wet.png")
	for k in D.ANIMALS:
		_anim_tex[k] = load("res://art/land/animals/%s.png" % k)
	_root = Node3D.new()
	_root.name = "LandThings"
	add_child(_root)
	_prune_used()
	_build_yard()
	_build_garden()
	_build_quarries()
	_build_aim_ui()
	town.talk_hooks.append(_on_talk)
	town.providers.append(self)


## Before the world is built: clear the trees out of Gran's yard so the garden, the
## workbench and the cook pot are out in the open.
static func clear_yard(w: Node3D) -> void:
	var r := Rect2(412.5, 680.5, 18.5, 11.0)
	var veg: Dictionary = w._veg_list
	for c in veg.keys():
		var list: Array = veg[c]
		for i in range(list.size() - 1, -1, -1):
			var p: Array = list[i]
			if r.has_point(Vector2(float(p[0]), float(p[1]))):
				list.remove_at(i)


## Before the world is built: the new folk join their towns.
static func add_folk(meta: Dictionary) -> void:
	for f: Dictionary in D.FOLK:
		for t in meta.towns:
			if str(t.id) == str(f.town):
				var people: Array = t.get("people", [])
				var have := false
				for p in people:
					if str(p.name) == str(f.name):
						have = true
				if not have:
					people.append({"name": f.name, "sheet": f.sheet, "x": f.x, "z": f.z, "role": f.role})
					t["people"] = people


# --- the save ---------------------------------------------------------------------------

func L() -> Dictionary:
	return save.land


func day() -> int:
	return int(floor(sea.now() / 1440.0))


func count(id: String) -> int:
	if id.begins_with("mat:"):
		var m: Dictionary = save.materials
		return int(m.get(id.substr(4), 0))
	var items: Dictionary = L().items
	return int(items.get(id, 0))


## Add to your store (and your Field Notes). Returns "+3 turnips" style text.
func add_item(id: String, n: int) -> String:
	if n <= 0:
		return ""
	if id.begins_with("mat:"):
		return str(town.add_materials({id.substr(4): n}))
	var items: Dictionary = L().items
	items[id] = int(items.get(id, 0)) + n
	var notes: Dictionary = L().notes
	notes[id] = int(notes.get(id, 0)) + n
	return "+%d %s" % [n, D.item_name(id).to_lower()]


func take(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	if id.begins_with("mat:"):
		var m: Dictionary = save.materials
		m[id.substr(4)] = int(m.get(id.substr(4), 0)) - n
		hud.set_materials(m)
		return true
	var items: Dictionary = L().items
	items[id] = int(items.get(id, 0)) - n
	if int(items[id]) <= 0:
		items.erase(id)
	return true


func tool_tier(kind: String) -> int:
	var tools: Dictionary = L().tools
	return int(tools.get(kind, 0))


func set_tool(kind: String, tier: int) -> void:
	var tools: Dictionary = L().tools
	tools[kind] = maxi(int(tools.get(kind, 0)), tier)


func tool_name(kind: String) -> String:
	var t := tool_tier(kind)
	if t <= 0:
		return ""
	var list: Array = D.TOOLS[kind]
	return str(list[mini(t, list.size()) - 1].n)


func flag(k: String) -> bool:
	var f: Dictionary = L().flags
	return bool(f.get(k, false))


func set_flag(k: String, on := true) -> void:
	var f: Dictionary = L().flags
	f[k] = on


## How many different land finds are in your Field Notes.
func notes_count() -> int:
	var notes: Dictionary = L().notes
	var n := 0
	for id in notes:
		var it: Dictionary = D.ITEMS.get(id, {})
		if not it.is_empty() and str(it.cat) in ["crop", "forage", "ore", "gem", "bar", "game", "meal"]:
			n += 1
	return n


# --- skills -----------------------------------------------------------------------------

func skill_level(s: String) -> int:
	var sk: Dictionary = L().skills
	var rec: Dictionary = sk.get(s, {})
	return int(rec.get("lv", 1))


func add_xp(s: String, xp: int) -> void:
	var sk: Dictionary = L().skills
	if not sk.has(s):
		sk[s] = {"lv": 1, "xp": 0}
	var rec: Dictionary = sk[s]
	if int(rec.lv) < D.SKILL_MAX:
		rec.xp = int(rec.xp) + xp
		while int(rec.lv) < D.SKILL_MAX and int(rec.xp) >= D.skill_need(int(rec.lv)):
			rec.xp = int(rec.xp) - D.skill_need(int(rec.lv))
			rec.lv = int(rec.lv) + 1
			audio.play("lvl")
			hud.show_banner("%s %d" % [str(D.SKILLS[s].n), int(rec.lv)], str(D.SKILLS[s].d))
	if progress:
		progress.add(xp)


# --- building the yard, the garden and the quarries ----------------------------------------

func _sprite(tex: Texture2D, px: float, at: Vector3, fixed_y := true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if fixed_y else BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	_root.add_child(s)
	if tex:
		s.global_position = at + Vector3(0.0, tex.get_height() * px * 0.5, 0.0)
	else:
		s.global_position = at
	return s


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, float(world.height_at(x, z)), z)


func _build_yard() -> void:
	_bench = _sprite(load("res://art/land/workbench.png"), 1.0 / 28.0, _ground(D.BENCH.x, D.BENCH.y))
	_pot = _sprite(load("res://art/land/cookpot.png"), 1.0 / 28.0, _ground(D.POT.x, D.POT.y))
	var g: Dictionary = D.GARDEN
	_sign = _sprite(load("res://art/land/garden_sign.png"), 1.0 / 28.0, _ground(float(g.x0) - 1.0, float(g.z0) - 0.6))
	if not flag("bench_fixed"):
		_bench.modulate = Color(0.62, 0.55, 0.5)
		_bench.rotation.z = 0.06


func _build_garden() -> void:
	var g: Dictionary = D.GARDEN
	var beds: Array = L().beds
	var total: int = int(g.cols) * int(g.rows)
	while beds.size() < total:
		beds.append({"s": "wild"})
	for i in total:
		var cx := float(g.x0) + (float(i % int(g.cols)) + 0.5) * float(g.cell)
		var cz := float(g.z0) + (float(i / int(g.cols)) + 0.5) * float(g.cell)
		var node := Node3D.new()
		_root.add_child(node)
		node.global_position = _ground(cx, cz) + Vector3(0.0, 0.03, 0.0)
		var soil := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(float(g.cell) - 0.25, float(g.cell) - 0.25)
		var m := StandardMaterial3D.new()
		m.albedo_texture = _soil_tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 1.0
		q.material = m
		soil.mesh = q
		soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(soil)
		var crop := Sprite3D.new()
		crop.pixel_size = 1.0 / 18.0
		crop.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		crop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		crop.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		node.add_child(crop)
		_beds.append({"node": node, "soil": soil, "mat": m, "crop": crop, "i": i, "pos": Vector3(cx, node.global_position.y, cz)})
	_refresh_garden()


func _refresh_garden() -> void:
	var beds: Array = L().beds
	var open := bed_count()
	var now: float = sea.now()
	for b in _beds:
		var i := int(b.i)
		var rec: Dictionary = beds[i]
		var node: Node3D = b.node
		node.visible = i < open
		var m: StandardMaterial3D = b.mat
		var crop: Sprite3D = b.crop
		var state := str(rec.get("s", "wild"))
		if state == "wild":
			m.albedo_texture = _soil_tex
			m.albedo_color = Color(0.72, 0.82, 0.5)
		else:
			m.albedo_color = Color.WHITE
			m.albedo_texture = _wet_tex if float(rec.get("wet", 0.0)) > now else _soil_tex
		if state == "crop":
			var tex: Texture2D = load("res://art/land/crops/%s_%d.png" % [str(rec.crop), stage(rec)])
			crop.texture = tex
			crop.position = Vector3(0.0, tex.get_height() * crop.pixel_size * 0.5 - 0.05, 0.0)
			crop.visible = true
		else:
			crop.visible = false


func bed_count() -> int:
	return clampi(int(L().get("bed_count", D.START_BEDS)), D.START_BEDS, D.MAX_BEDS)


func stage(rec: Dictionary) -> int:
	if str(rec.get("s", "")) != "crop":
		return 0
	var info: Dictionary = D.CROPS.get(str(rec.crop), {})
	var k := float(rec.get("grow", 0.0)) / float(info.get("grow", 600))
	if k >= 1.0:
		return 3
	if k < 0.06:
		return 0
	return 1 if k < 0.4 else 2


func _build_quarries() -> void:
	var mined: Dictionary = L().mined
	for q: Dictionary in D.QUARRIES:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(q.id)) + 991
		var weights: Dictionary = q.kinds
		var placed: Array[Vector2] = []
		var tries := 0
		while placed.size() < int(q.count) and tries < 400:
			tries += 1
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * float(q.r)
			var x := float(q.x) + cos(a) * r
			var z := float(q.z) + sin(a) * r
			if not _rock_spot_ok(x, z, placed):
				continue
			placed.append(Vector2(x, z))
			var kind := _pick(weights, rng)
			var id := "%s:%d" % [str(q.id), placed.size()]
			var pos := _ground(x, z)
			var node := _sprite(load("res://art/land/ore_%s.png" % kind), 1.0 / 22.0, pos)
			var rub := _sprite(load("res://art/land/rubble.png"), 1.0 / 22.0, pos)
			var rec := {"id": id, "kind": kind, "pos": pos, "node": node, "rubble": rub, "quarry": str(q.id)}
			_rocks.append(rec)
			_show_rock(rec, int(mined.get(id, -99)) >= day())


func _rock_spot_ok(x: float, z: float, placed: Array[Vector2]) -> bool:
	var h: float = world.height_at(x, z)
	if world.is_water(x, z) or h < float(world.sea_level) + 0.5:
		return false
	var fl: int = world.flags_at(x, z)
	if fl & (int(world.F.town) | int(world.F.road) | int(world.F.deck)):
		return false
	for dx in [-1.5, 1.5]:
		for dz in [-1.5, 1.5]:
			if absf(float(world.height_at(x + dx, z + dz)) - h) > 0.9 or world.is_water(x + dx, z + dz):
				return false
	for p in placed:
		if p.distance_to(Vector2(x, z)) < 3.5:
			return false
	for b in world.buildings:
		var door: Vector3 = b.door
		if Vector2(door.x, door.z).distance_to(Vector2(x, z)) < 6.0:
			return false
	return not _tree_at(x, z, 3.2)  # out in the open, not hidden under a canopy


func _tree_at(x: float, z: float, r: float) -> bool:
	var c := Vector2i(int(x / 128.0), int(z / 128.0))
	var list: Array = world._veg_list.get(c, [])
	for p in list:
		if absf(float(p[0]) - x) < r and absf(float(p[1]) - z) < r:
			var nm: String = world.plant_names[int(p[2])]
			if not (nm.begins_with("flowers") or nm.begins_with("fern")):
				return true
	return false


func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return str(k)
	return str(weights.keys()[0])


func _show_rock(rec: Dictionary, spent: bool) -> void:
	var node: Sprite3D = rec.node
	var rub: Sprite3D = rec.rubble
	node.visible = not spent
	rub.visible = spent


# --- every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_root.visible = not world.indoor
	_busy = maxf(0.0, _busy - delta)
	if _busy <= 0.0 and player.pose == "cast" and _aim.is_empty() and str(player.get_meta("land_pose", "")) == "swing":
		player.pose = ""
		player.set_meta("land_pose", "")
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_grow()
		_respawn_rocks()
	if not world.indoor:
		_update_forage(delta)
		_update_animals(delta)
	if not _aim.is_empty():
		_update_aim(delta)


func _grow() -> void:
	var now: float = sea.now()
	var last := float(L().get("tick_t", now))
	var dt := clampf(now - last, 0.0, 2880.0)
	L()["tick_t"] = now
	var raining := str(sea.env.get("sky", "")) in ["rain", "storm"]
	var beds: Array = L().beds
	var changed := false
	for i in mini(beds.size(), bed_count()):
		var rec: Dictionary = beds[i]
		if str(rec.get("s", "")) != "crop":
			continue
		if raining:
			if float(rec.get("wet", 0.0)) < now + 30.0:
				changed = changed or float(rec.get("wet", 0.0)) < now
				rec.wet = now + 60.0
		var wet := float(rec.get("wet", 0.0))
		var watered := minf(now, wet) - last
		if watered > 0.0:
			var before := stage(rec)
			var mul := 1.5 if bool(rec.get("comp", false)) else 1.0
			rec.grow = float(rec.get("grow", 0.0)) + minf(watered, dt) * mul
			if stage(rec) != before:
				changed = true
		if wet < now and wet > last:
			changed = true  # dried out
	if changed or int(Time.get_ticks_msec() / 1000) % 10 == 0:
		_refresh_garden()


func _respawn_rocks() -> void:
	var mined: Dictionary = L().mined
	var today := day()
	for rec in _rocks:
		var node: Sprite3D = rec.node
		var spent := int(mined.get(str(rec.id), -99)) >= today
		if node.visible == spent:
			_show_rock(rec, spent)


func _prune_used() -> void:
	var used: Dictionary = L().used
	var today := day()
	for k in used.keys():
		if int(used[k]) < today:
			used.erase(k)
	var mined: Dictionary = L().mined
	for k in mined.keys():
		if int(mined[k]) < today - 1:
			mined.erase(k)


# --- what's in reach (town.nearest asks every provider) -------------------------------------

func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if world.indoor or _busy > 0.0 or not _aim.is_empty():
		return {}
	_near_t -= get_process_delta_time()
	if _near_t > 0.0 and pos.distance_to(_near_pos) < 0.15 and facing.dot(_near_facing) > 0.98:
		return _near_res
	_near_t = 0.12
	_near_pos = pos
	_near_facing = facing
	_near_res = _find_near(pos, facing)
	return _near_res


func _facing_ok(pos: Vector3, at: Vector3, facing: Vector3, close := 0.8) -> bool:
	var to := Vector2(at.x - pos.x, at.z - pos.z)
	if to.length() < close:
		return true
	return Vector2(facing.x, facing.z).normalized().dot(to.normalized()) > 0.35


func _find_near(pos: Vector3, facing: Vector3) -> Dictionary:
	var best := {}
	var best_d := 99.0
	var p2 := Vector2(pos.x, pos.z)
	# the yard
	for pair in [[_bench, "bench"], [_pot, "pot"]]:
		var s: Sprite3D = pair[0]
		var d := p2.distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < 1.8 and d < best_d and _facing_ok(pos, s.global_position, facing):
			best_d = d
			best = {"kind": str(pair[1]), "dist": d, "text": _yard_text(str(pair[1]))}
	# the garden
	var beds: Array = L().beds
	for b in _beds:
		if int(b.i) >= bed_count():
			continue
		var bp: Vector3 = b.pos
		var d := p2.distance_to(Vector2(bp.x, bp.z))
		if d < 1.3 and d < best_d and _facing_ok(pos, bp, facing, 1.2):
			best_d = d
			best = {"kind": "bed", "i": int(b.i), "dist": d, "text": _bed_text(beds[int(b.i)])}
	# rocks in the quarries
	var mined: Dictionary = L().mined
	var today := day()
	for rec in _rocks:
		var rp: Vector3 = rec.pos
		var d := p2.distance_to(Vector2(rp.x, rp.z))
		if d < RANGE_ROCK and d < best_d and int(mined.get(str(rec.id), -99)) < today and absf(rp.y - pos.y) < 2.5 and _facing_ok(pos, rp, facing):
			best_d = d
			var info: Dictionary = D.ORES[str(rec.kind)]
			var need := int(info.tier)
			var text := "Space: Mine the %s" % str(info.n).to_lower()
			if tool_tier("pick") < need:
				text = "%s: you need a %s" % [str(info.n), "pickaxe" if need <= 1 else str(D.TOOLS.pick[need - 1].n).to_lower()]
			best = {"kind": "rock", "rec": rec, "dist": d, "text": text}
	# forage on the ground
	for f in _forage:
		var node: Sprite3D = f.node
		var fp := node.global_position
		var d := p2.distance_to(Vector2(fp.x, fp.z))
		if d < RANGE_SMALL and d < best_d and _facing_ok(pos, fp, facing, 1.0):
			best_d = d
			best = {"kind": "forage", "f": f, "dist": d, "text": "Space: Pick up the %s" % D.item_name(str(f.id)).to_lower()}
	# the trees, bushes and rocks of the world
	var veg := _veg_near(pos, facing)
	if not veg.is_empty() and float(veg.dist) < best_d:
		best_d = float(veg.dist)
		best = veg
	# animals to hunt (further away, so only if nothing's right here)
	if best.is_empty():
		var a := _animal_in_sight(pos, facing)
		if not a.is_empty():
			best = a
	return best


func _yard_text(kind: String) -> String:
	if kind == "bench":
		if not flag("bench_fixed"):
			return "Space: Look at Gran's old workbench"
		return "Space: Use Gran's workbench"
	return "Space: Cook at the pot"


func _bed_text(rec: Dictionary) -> String:
	match str(rec.get("s", "wild")):
		"wild":
			return "Space: Dig over this bed" if tool_tier("hoe") > 0 else "An overgrown garden bed (you need a hoe)"
		"tilled":
			return "Space: Plant something"
		"crop":
			var nm := D.item_name(str(rec.crop)).to_lower()
			if stage(rec) >= 3:
				return "Space: Harvest the %ss" % nm if not nm.ends_with("s") else "Space: Harvest the %s" % nm
			if float(rec.get("wet", 0.0)) <= sea.now():
				return "Space: Water the %s" % nm if tool_tier("can") > 0 else "The %s needs water (you need a watering can)" % nm
			return "Space: Check on the %s" % nm
	return ""


func _veg_near(pos: Vector3, facing: Vector3) -> Dictionary:
	var used: Dictionary = L().used
	var today := day()
	var c := Vector2i(int(pos.x / 128.0), int(pos.z / 128.0))
	var best := {}
	var best_d := 99.0
	var reach := Rect2(pos.x - 2.6, pos.z - 2.6, 5.2, 5.2)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			if not reach.intersects(Rect2(cell.x * 128.0, cell.y * 128.0, 128.0, 128.0)):
				continue  # (almost always just the one cell you're standing in)
			var list: Array = world._veg_list.get(cell, [])
			for p in list:
				var x := float(p[0])
				var z := float(p[1])
				if absf(x - pos.x) > 2.6 or absf(z - pos.z) > 2.6:
					continue
				var nm: String = world.plant_names[int(p[2])]
				var what := _veg_kind(nm)
				if what == "":
					continue
				var rng_v := RANGE_TREE if what == "tree" else (RANGE_BOULDER if what == "boulder" else RANGE_SMALL)
				var d := Vector2(x - pos.x, z - pos.z).length()
				if d > rng_v or d >= best_d:
					continue
				var at := Vector3(x, float(world.height_at(x, z)), z)
				if absf(at.y - pos.y) > 2.0 or not _facing_ok(pos, at, facing, 0.9):
					continue
				var key := "%d:%d" % [int(round(x * 10.0)), int(round(z * 10.0))]
				if int(used.get(key, -99)) >= today:
					continue
				best_d = d
				best = {"kind": "veg", "what": what, "plant": nm, "key": key, "at": at, "dist": d, "text": _veg_text(what)}
	return best


func _veg_kind(nm: String) -> String:
	for pre in TREE_PREFIX:
		if nm.begins_with(pre):
			return "tree"
	if nm.begins_with("bush"):
		return "bush"
	if nm.begins_with("fern"):
		return "fern"
	if nm.begins_with("flowers"):
		return "flowers"
	if nm.begins_with("boulder"):
		return "boulder"
	if nm.begins_with("rock"):
		return "stones"
	return ""


func _veg_text(what: String) -> String:
	match what:
		"tree":
			return "Space: Chop some wood" if tool_tier("axe") > 0 else "A good tree for firewood (you need an axe)"
		"bush":
			return "Space: Pick blackberries"
		"fern":
			return "Space: Gather wild herbs"
		"flowers":
			return "Space: Pick wildflowers"
		"boulder":
			return "Space: Break off some stone" if tool_tier("pick") > 0 else "A big boulder (you need a pickaxe)"
		"stones":
			return "Space: Pick up some stones"
	return ""


# --- doing things -------------------------------------------------------------------------

func use(it: Dictionary) -> void:
	match str(it.get("kind", "")):
		"bench":
			_use_bench()
		"pot":
			if menu:
				menu.open_craft("pot")
		"bed":
			_use_bed(int(it.i))
		"rock":
			_mine(it.rec)
		"forage":
			_pick_up(it.f)
		"veg":
			_use_veg(it)
		"animal":
			_start_aim(it.a)
	_near_t = 0.0


func _swing(sound: String, pitch := 1.0) -> void:
	_busy = 0.4
	player.pose = "cast"
	player.set_meta("land_pose", "swing")
	audio.play(sound, -4.0, pitch, 0.08)


func _float(id: String, at: Vector3) -> void:
	var tex := D.icon(id)
	if tex and town.has_method("_float_icon"):
		town._float_icon(tex, at + Vector3(0.0, 1.0, 0.0))


func _use_veg(it: Dictionary) -> void:
	var what := str(it.what)
	var at: Vector3 = it.at
	var got := ""
	var mark := true
	match what:
		"tree":
			if tool_tier("axe") <= 0:
				hud.toast("You'll need an axe. Farmer Bramble sells them, or make one at Gran's workbench (3 wood, 3 stone).")
				audio.play("error", -8.0)
				return
			_swing("thud", 0.9)
			audio.play("step_wood", -2.0)
			var axe: Dictionary = D.TOOLS.axe[tool_tier("axe") - 1]
			var n := int(axe.wood) + skill_level("foraging") / 4 + (1 if _rng.randf() < 0.25 else 0)
			got = add_item("mat:wood", n)
			if _rng.randf() < 0.15:
				got += ", " + add_item("herbs", 1)
			add_xp("foraging", 6)
			_float("axe_stone", at)
			land_event.emit("chop", str(it.plant), 1)
		"bush":
			_swing("step_grass", 1.2)
			var n := _rng.randi_range(1, 3) + skill_level("foraging") / 3
			got = add_item("berries", n)
			add_xp("foraging", 4)
			_float("berries", at)
			land_event.emit("forage", "berries", n)
		"fern":
			_swing("step_grass", 1.1)
			var n := _rng.randi_range(1, 2) + skill_level("foraging") / 4
			got = add_item("herbs", n)
			add_xp("foraging", 3)
			_float("herbs", at)
			land_event.emit("forage", "herbs", n)
		"flowers":
			_swing("step_grass", 1.3)
			var n := _rng.randi_range(1, 2)
			got = add_item("wildflowers", n)
			add_xp("foraging", 2)
			_float("wildflowers", at)
			land_event.emit("forage", "wildflowers", n)
		"stones":
			_swing("step_stone", 1.1)
			var n := _rng.randi_range(1, 2)
			got = add_item("stone", n)
			add_xp("foraging", 2)
			_float("stone", at)
			land_event.emit("gather", "stone", n)
		"boulder":
			if tool_tier("pick") <= 0:
				hud.toast("That's a job for a pickaxe. Make one at Gran's workbench (3 wood, 4 stone).")
				audio.play("error", -8.0)
				return
			_swing("step_stone", 0.8)
			audio.play("snap", -10.0, 0.7)
			var n := _rng.randi_range(2, 4) + skill_level("mining") / 3
			got = add_item("stone", n)
			if _rng.randf() < 0.3:
				got += ", " + add_item("coal", 1)
			elif _rng.randf() < 0.2:
				got += ", " + add_item("copper_ore", 1)
			add_xp("mining", 5)
			_float("stone", at)
			land_event.emit("mine", "stone", n)
	if mark:
		var used: Dictionary = L().used
		used[str(it.key)] = day()
	hud.toast(got)
	SaveGame.write(save)


func _mine(rec: Dictionary) -> void:
	var info: Dictionary = D.ORES[str(rec.kind)]
	var need := int(info.tier)
	if tool_tier("pick") < need:
		var tool_n := "a pickaxe" if need <= 1 else "a %s" % str(D.TOOLS.pick[need - 1].n).to_lower()
		hud.toast("That %s needs %s." % [str(info.n).to_lower(), tool_n])
		audio.play("error", -8.0)
		return
	_swing("step_stone", 0.85)
	audio.play("snap", -8.0, 0.6, 0.1)
	var parts: Array[String] = []
	var bonus := skill_level("mining") / 3 + maxi(0, tool_tier("pick") - need)
	for drop: Array in info.drops:
		if _rng.randf() <= float(drop[1]):
			var n := _rng.randi_range(int(drop[2]), int(drop[3])) + (bonus if str(drop[0]) != "ember_crystal" and str(drop[0]) != "amethyst" else 0)
			parts.append(add_item(str(drop[0]), n))
			land_event.emit("mine", str(drop[0]), n)
	var mined: Dictionary = L().mined
	mined[str(rec.id)] = day()
	_show_rock(rec, true)
	add_xp("mining", int(info.xp))
	var pos: Vector3 = rec.pos
	_float(str(info.drops[0][0]), pos)
	hud.toast("Mined: %s. It'll be back tomorrow." % ", ".join(parts))
	SaveGame.write(save)


func _pick_up(f: Dictionary) -> void:
	_forage.erase(f)
	var node: Sprite3D = f.node
	var at := node.global_position
	node.queue_free()
	audio.play("pin", -6.0, 1.2)
	var id := str(f.id)
	var n := 1 + (1 if _rng.randf() < 0.1 * skill_level("foraging") else 0)
	hud.toast("Found: %s." % add_item(id, n))
	add_xp("foraging", 8 if id == "chanterelle" else 4)
	_float(id, at)
	land_event.emit("forage", id, n)
	SaveGame.write(save)


func _use_bench() -> void:
	if not flag("bench_fixed"):
		var short: Array[String] = []
		if count("mat:wood") < 6:
			short.append("%d wood" % (6 - count("mat:wood")))
		if count("stone") < 4:
			short.append("%d stone" % (4 - count("stone")))
		if not short.is_empty():
			dialogue.say("Gran's workbench", ["A leg's gone and the top's split, but it's a good bench under the moss.",
				"You could fix it with 6 wood and 4 stone. (You need %s more.)" % " and ".join(short),
				"Chop wood from any tree with an axe, and pick up stones from the little rocks round the coast."])
			return
		take("mat:wood", 6)
		take("stone", 4)
		set_flag("bench_fixed")
		_bench.modulate = Color.WHITE
		_bench.rotation.z = 0.0
		audio.play("good")
		audio.play("thud", -4.0)
		hud.toast("Gran's workbench is fixed! Make tools, furniture and more here.")
		add_xp("crafting", 15)
		land_event.emit("fix", "bench", 1)
		SaveGame.write(save)
		return
	if menu:
		menu.open_craft("bench")


func _use_bed(i: int) -> void:
	var beds: Array = L().beds
	var rec: Dictionary = beds[i]
	var now: float = sea.now()
	match str(rec.get("s", "wild")):
		"wild":
			if tool_tier("hoe") <= 0:
				hud.toast("You'll need a hoe to dig it over. Farmer Bramble sells them.")
				audio.play("error", -8.0)
				return
			_swing("step_sand", 0.8)
			rec.s = "tilled"
			add_xp("farming", 3)
			land_event.emit("till", "", 1)
			hud.toast("Dug over and ready for seeds.")
		"tilled":
			_choose_seed(i)
			return
		"crop":
			var crop := str(rec.crop)
			var nm := D.item_name(crop).to_lower()
			if stage(rec) >= 3:
				var info: Dictionary = D.CROPS[crop]
				var y: Array = info["yield"]
				var n := _rng.randi_range(int(y[0]), int(y[1])) + skill_level("farming") / 3
				_swing("pin", 1.1)
				audio.play("good", -6.0)
				hud.toast("Harvested: %s." % add_item(crop, n))
				add_xp("farming", int(info.xp))
				_float(crop, rec_pos(i))
				land_event.emit("harvest", crop, n)
				beds[i] = {"s": "tilled"}
			elif float(rec.get("wet", 0.0)) <= now:
				if tool_tier("can") <= 0:
					hud.toast("The %s is thirsty. You need a watering can (Farmer Bramble)." % nm)
					audio.play("error", -8.0)
					return
				_swing("splash", 1.4)
				rec.wet = now + float(D.WATER_MINUTES)
				add_xp("farming", 1)
				land_event.emit("water", crop, 1)
				hud.toast("Watered. It'll stay damp for half a day (rain waters it too).")
			else:
				var info2: Dictionary = D.CROPS[crop]
				var left := maxf(0.0, float(info2.grow) - float(rec.get("grow", 0.0)))
				var mul := 1.5 if bool(rec.get("comp", false)) else 1.0
				hud.toast("The %s is coming along: about %d minutes of watered growing to go." % [nm, int(ceil(left / mul))])
				audio.play("pin", -10.0)
				return
	_refresh_garden()
	SaveGame.write(save)


func rec_pos(i: int) -> Vector3:
	for b in _beds:
		if int(b.i) == i:
			return b.pos
	return player.global_position


func _choose_seed(i: int) -> void:
	var options: Array = []
	for crop in D.CROP_ORDER:
		var sid := "seed_%s" % crop
		if count(sid) > 0:
			options.append(sid)
	if options.is_empty():
		hud.toast("You've no seeds. Farmer Bramble sells them, just over there.")
		audio.play("error", -8.0)
		return
	var labels: Array = []
	for sid in options:
		labels.append("%s (%d)" % [D.item_name(str(sid)), count(str(sid))])
	if count("compost") > 0:
		labels.append("Dig in compost first (%d)" % count("compost"))
	labels.append("Not now")
	dialogue.say("Gran's garden", ["What will you plant here?"], null, labels, _planted.bind(i, options))


func _planted(choice: int, i: int, options: Array) -> void:
	var beds: Array = L().beds
	var rec: Dictionary = beds[i]
	if choice < 0:
		return
	if choice == options.size() and count("compost") > 0:
		take("compost", 1)
		rec["comp"] = true
		hud.toast("Compost dug in: whatever grows here grows half again as fast.")
		audio.play("step_sand", -4.0)
		call_deferred("_choose_seed", i)
		return
	if choice >= options.size():
		return
	var sid := str(options[choice])
	if not take(sid, 1):
		return
	var crop := str(D.ITEMS[sid].crop)
	var comp := bool(rec.get("comp", false))
	beds[i] = {"s": "crop", "crop": crop, "grow": 0.0, "wet": 0.0, "comp": comp}
	_swing("step_sand", 1.2)
	add_xp("farming", 2)
	land_event.emit("plant", crop, 1)
	hud.toast("Planted %s. Now give them some water." % D.item_name(crop).to_lower())
	_refresh_garden()
	SaveGame.write(save)


## Farmer Bramble digs you another bed.
func buy_bed() -> String:
	var n := bed_count()
	if n >= D.MAX_BEDS:
		return "That's all the room there is."
	var price := int(D.BED_PRICE[n])
	if int(save.shells) < price:
		return "You need %d more Shells." % (price - int(save.shells))
	save.shells = int(save.shells) - price
	L()["bed_count"] = n + 1
	hud.set_shells(save.shells)
	_refresh_garden()
	return ""


# --- forage that pops up ------------------------------------------------------------------

func _update_forage(delta: float) -> void:
	var here := player.global_position
	for f in _forage.duplicate():
		var node: Sprite3D = f.node
		if node.global_position.distance_to(here) > 60.0:
			_forage.erase(f)
			node.queue_free()
	for f in _forage:
		var node: Sprite3D = f.node
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + node.position.x)
		node.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.3, 1.25, 0.9), k)
	if _forage.size() >= FORAGE_SPOTS:
		return
	_forage_wait -= delta
	if _forage_wait > 0.0:
		return
	_forage_wait = _rng.randf_range(6.0, 14.0)
	for attempt in 16:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, 24.0)
		var x := here.x + cos(a) * r
		var z := here.z + sin(a) * r
		var mat: String = world.mat_at(x, z)
		if not FORAGE.has(mat) or world.is_water(x, z) or not world.walkable(x, z):
			continue
		if world.flags_at(x, z) & (int(world.F.town) | int(world.F.road)):
			continue
		var id := _pick_list(FORAGE[mat])
		var node := _sprite(D.icon(id), 1.0 / 22.0, _ground(x, z) + Vector3(0.0, 0.05, 0.0), false)
		_forage.append({"id": id, "node": node})
		return


const FORAGE := D.FORAGE


func _pick_list(list: Array) -> String:
	var total := 0.0
	for e: Array in list:
		total += float(e[1])
	var roll := _rng.randf() * total
	for e: Array in list:
		roll -= float(e[1])
		if roll <= 0.0:
			return str(e[0])
	return str(list[0][0])


# --- animals --------------------------------------------------------------------------------

func _update_animals(delta: float) -> void:
	var here := player.global_position
	for a in _animals.duplicate():
		var node: Sprite3D = a.node
		if node.global_position.distance_to(here) > 75.0:
			_remove_animal(a)
			continue
		if not _aim.is_empty() and _aim.a == a:
			continue
		_step_animal(a, delta, here)
	if _animals.size() >= ANIMALS_NEAR:
		return
	_animal_wait -= delta
	if _animal_wait > 0.0:
		return
	_animal_wait = _rng.randf_range(7.0, 16.0)
	for attempt in 14:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(14.0, 34.0)
		var x := here.x + cos(ang) * r
		var z := here.z + sin(ang) * r
		var kind := _animal_for(x, z)
		if kind == "":
			continue
		_spawn_animal(kind, x, z)
		return


func _animal_for(x: float, z: float) -> String:
	var fl: int = world.flags_at(x, z)
	if fl & (int(world.F.town) | int(world.F.road) | int(world.F.deck)):
		return ""
	if world.is_water(x, z):
		var zone: String = world.zone_at(x, z)
		if (zone in ["estuary", "lake"] or fl & int(world.F.river)) and world.water_depth(x, z) < 3.0:
			return "duck" if _rng.randf() < 0.7 else ""
		return ""
	if world.height_at(x, z) < float(world.sea_level) + 0.3:
		return ""
	var mat: String = world.mat_at(x, z)
	var high := bool(fl & int(world.F.highland))
	if high and mat in ["forest", "grass"]:
		return "deer" if _rng.randf() < 0.6 else "rabbit"
	if mat == "forest":
		var r := _rng.randf()
		if r < 0.3:
			return "boar"
		if r < 0.45 and z < 400.0:
			return "deer"
		return "rabbit" if r < 0.8 else ""
	if mat == "grass":
		return "rabbit" if _rng.randf() < 0.6 else "pheasant"
	return ""


func _spawn_animal(kind: String, x: float, z: float) -> void:
	var info: Dictionary = D.ANIMALS[kind]
	var tex: Texture2D = _anim_tex[kind]
	var node := Sprite3D.new()
	node.texture = tex
	node.hframes = 2
	node.pixel_size = float(info.px)
	node.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_root.add_child(node)
	var pos := Vector3(x, _animal_y(kind, x, z), z)
	node.global_position = pos + Vector3(0.0, tex.get_height() * float(info.px) * 0.5, 0.0)
	_animals.append({"kind": kind, "node": node, "home": pos, "target": pos, "pos": pos, "flee": 0.0, "t": 0.0, "walk": 0.0})


func _animal_y(kind: String, x: float, z: float) -> float:
	if kind == "duck" and world.is_water(x, z):
		return float(world.water_level_at(x, z)) - 0.05
	return float(world.height_at(x, z))


func _step_animal(a: Dictionary, delta: float, here: Vector3) -> void:
	var kind := str(a.kind)
	var info: Dictionary = D.ANIMALS[kind]
	var node: Sprite3D = a.node
	var pos: Vector3 = a.pos
	var to_player := Vector2(pos.x - here.x, pos.z - here.z)
	var startle := 4.0 if player.velocity.length() > 3.0 else 2.6
	if to_player.length() < startle and float(a.flee) <= 0.0:
		a.flee = 2.5
		if kind == "duck":
			audio.play("quack", -10.0, 1.0, 0.1)
	var speed := 0.9
	var target: Vector3 = a.target
	if float(a.flee) > 0.0:
		a.flee = float(a.flee) - delta
		speed = float(info.speed)
		var away := to_player.normalized()
		target = pos + Vector3(away.x, 0.0, away.y) * 4.0
	else:
		a.t = float(a.t) - delta
		if float(a.t) <= 0.0 or Vector2(target.x - pos.x, target.z - pos.z).length() < 0.3:
			a.t = _rng.randf_range(1.5, 4.0)
			var home: Vector3 = a.home
			var ang := _rng.randf() * TAU
			target = home + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(0.0, 6.0)
			if _rng.randf() < 0.4:
				target = pos  # graze for a bit
			a.target = target
	var dir := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var moving := dir.length() > 0.2
	if moving:
		var step := dir.normalized() * speed * delta
		var nx := pos.x + step.x
		var nz := pos.z + step.z
		var ok: bool = world.is_water(nx, nz) if kind == "duck" else (not world.is_water(nx, nz) and world.walkable(nx, nz))
		if kind == "duck":
			ok = true  # ducks paddle or waddle
		if ok:
			pos.x = nx
			pos.z = nz
		else:
			a.target = pos
		var right := cam.global_transform.basis.x
		node.flip_h = step.dot(right) > 0.0
	a.walk = float(a.walk) + delta * (8.0 if speed > 1.5 else 4.0)
	node.frame = (int(a.walk) % 2) if moving else 0
	pos.y = _animal_y(kind, pos.x, pos.z)
	a.pos = pos
	node.global_position = pos + Vector3(0.0, node.texture.get_height() * node.pixel_size * 0.5, 0.0)


func _remove_animal(a: Dictionary) -> void:
	_animals.erase(a)
	var node: Sprite3D = a.node
	if is_instance_valid(node):
		node.queue_free()


func _animal_in_sight(pos: Vector3, facing: Vector3) -> Dictionary:
	if tool_tier("bow") <= 0:
		return {}  # (without a bow, animals are just scenery, and never get in the way of a cast)
	var best := {}
	var best_d := HUNT_RANGE
	var f2 := Vector2(facing.x, facing.z).normalized()
	for a in _animals:
		var ap: Vector3 = a.pos
		var to := Vector2(ap.x - pos.x, ap.z - pos.z)
		var d := to.length()
		if d > best_d or d < 1.0:
			continue
		if f2.dot(to.normalized()) < 0.88:
			continue
		best_d = d
		var info: Dictionary = D.ANIMALS[str(a.kind)]
		var text := "Space: Aim at the %s" % str(info.n)
		if count("arrows") <= 0:
			text = "A %s (you're out of arrows)" % str(info.n)
		best = {"kind": "animal", "a": a, "dist": d + 3.0, "text": text}
	return best


# --- hunting: the aim bar -------------------------------------------------------------------

class AimBar:
	extends Control
	var marker := 0.0
	var zone_at := 0.5
	var zone_w := 0.15

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.07, 0.09, 0.17, 0.92))
		var zx := (zone_at - zone_w * 0.5) * size.x
		draw_rect(Rect2(zx, 0.0, zone_w * size.x, size.y), Color(0.45, 0.9, 0.5, 0.85))
		draw_rect(Rect2(zone_at * size.x - 2.0, 0.0, 4.0, size.y), Color(1.0, 0.95, 0.6))
		var mx := marker * size.x
		draw_rect(Rect2(mx - 3.0, -6.0, 6.0, size.y + 12.0), Color(1.0, 0.84, 0.45))
		draw_rect(r, Color(0.96, 0.86, 0.62), false, 3.0)


func _build_aim_ui() -> void:
	_aim_layer = CanvasLayer.new()
	_aim_layer.layer = 12
	add_child(_aim_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -230.0
	center.offset_bottom = -110.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_layer.add_child(center)
	var panel := UI.panel(14.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_aim_label = UI.label("", 22, UI.CREAM, true)
	_aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_aim_label)
	_aim_bar = AimBar.new()
	_aim_bar.custom_minimum_size = Vector2(440.0, 26.0)
	col.add_child(_aim_bar)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{action} loose the arrow when the gold line's in the green   {cancel} lower the bow"))
	_aim_layer.visible = false


func _start_aim(a: Dictionary) -> void:
	if not _animals.has(a):
		return
	var info: Dictionary = D.ANIMALS[str(a.kind)]
	if tool_tier("bow") <= 0:
		hud.toast("You'd need a bow. Ash the hunter in Willowford sells them, or make one at Gran's workbench.")
		audio.play("error", -8.0)
		return
	if count("arrows") <= 0:
		hud.toast("You're out of arrows. Make some at the workbench (1 wood, 1 stone for five), or buy them from Ash.")
		audio.play("error", -8.0)
		return
	var ap: Vector3 = a.pos
	var d := Vector2(ap.x - player.global_position.x, ap.z - player.global_position.z).length()
	var bow: Dictionary = D.TOOLS.bow[tool_tier("bow") - 1]
	var w := float(info.zone) * float(bow.aim) * (1.0 + 0.05 * skill_level("hunting")) * clampf(1.4 - d / 20.0, 0.6, 1.3)
	_aim = {"a": a, "t": 0.0, "speed": 1.1 + d / 12.0, "grace": 0.25, "left": 7.0}
	_aim_bar.zone_at = _rng.randf_range(0.25, 0.75)
	_aim_bar.zone_w = clampf(w, 0.05, 0.4)
	_aim_bar.marker = 0.0
	_aim_label.text = "Steady... a %s, %d m off. (%d arrows)" % [str(info.n), int(d), count("arrows")]
	_aim_layer.visible = true
	hud.modal = true
	player.can_move = false
	player.face(Vector3(ap.x - player.global_position.x, 0.0, ap.z - player.global_position.z))
	player.pose = "cast"
	audio.play("crank", -10.0, 1.4)


func _update_aim(delta: float) -> void:
	var a: Dictionary = _aim.a
	if not _animals.has(a):
		_end_aim()
		return
	_aim.t = float(_aim.t) + delta * float(_aim.speed)
	_aim_bar.marker = 0.5 - 0.5 * cos(float(_aim.t) * PI)
	_aim_bar.queue_redraw()
	_aim.grace = float(_aim.grace) - delta
	_aim.left = float(_aim.left) - delta
	if float(_aim.left) <= 0.0:
		hud.toast("The %s caught your scent and bolted." % str(D.ANIMALS[str(a.kind)].n))
		a.flee = 3.0
		_end_aim()
		return
	if Input.is_action_just_pressed("cancel"):
		_end_aim()
		return
	if float(_aim.grace) > 0.0 or not Input.is_action_just_pressed("action"):
		return
	take("arrows", 1)
	audio.play("whoosh", -2.0, 1.3)
	var hit := absf(_aim_bar.marker - _aim_bar.zone_at) <= _aim_bar.zone_w * 0.5
	if hit:
		_bagged(a)
	else:
		audio.play("miss", -6.0)
		a.flee = 3.5
		hud.toast("Missed! The %s's off like a shot." % str(D.ANIMALS[str(a.kind)].n))
		land_event.emit("miss", str(a.kind), 1)
	_end_aim()
	SaveGame.write(save)


func _bagged(a: Dictionary) -> void:
	var kind := str(a.kind)
	var info: Dictionary = D.ANIMALS[kind]
	audio.play("thud", -2.0)
	audio.play("good", -6.0)
	var parts: Array[String] = []
	for drop: Array in info.drops:
		if _rng.randf() <= float(drop[1]):
			parts.append(add_item(str(drop[0]), _rng.randi_range(int(drop[2]), int(drop[3]))))
	var ap: Vector3 = a.pos
	_float("meat", ap)
	add_xp("hunting", int(info.xp))
	land_event.emit("hunt", kind, 1)
	hud.toast("Got the %s: %s." % [str(info.n), ", ".join(parts)])
	_remove_animal(a)


func _end_aim() -> void:
	_aim = {}
	_aim_layer.visible = false
	hud.modal = false
	player.can_move = true
	player.pose = ""
	hud.block_input(0.25)


# --- the new folk -----------------------------------------------------------------------------

func _on_talk(who: String) -> bool:
	if not world.folk.has(who):
		return false
	var role := str(world.folk[who].role)
	if not role.begins_with("land:"):
		return false
	var key := role.substr(5)
	if menu:
		audio.play("click")
		menu.open_shop(key, who)
	return true


# --- for the bag and the game menu --------------------------------------------------------------

func bag_text() -> String:
	var items: Dictionary = L().items
	var out := ""
	var tools: Array[String] = []
	for kind in ["hoe", "can", "axe", "pick", "bow"]:
		var n := tool_name(kind)
		if n != "":
			tools.append(n)
	if not tools.is_empty():
		out += "[color=#8ad08a][b]Land tools[/b][/color]\n%s\n" % ", ".join(tools)
	if items.is_empty():
		return out
	var by_cat := {}
	for id in items:
		var it: Dictionary = D.ITEMS.get(id, {})
		var cat := str(it.get("cat", "craft"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append("%s %d" % [D.item_name(str(id)), int(items[id])])
	var names := {"crop": "From the garden", "seed": "Seeds", "forage": "Foraged", "ore": "Ore and stone", "gem": "Gems",
		"bar": "Metal bars", "game": "From the hunt", "meal": "Cooking", "craft": "Crafted"}
	for cat in ["crop", "seed", "forage", "ore", "gem", "bar", "game", "meal", "craft"]:
		if by_cat.has(cat):
			out += "[color=#8ad08a][b]%s[/b][/color]\n%s\n" % [names[cat], ", ".join(by_cat[cat])]
	return out


func skills_text() -> String:
	var out := "[color=#8ad08a][b]Harbour life[/b][/color]\n"
	var bits: Array[String] = []
	for s in D.SKILL_ORDER:
		bits.append("%s %d" % [str(D.SKILLS[s].n), skill_level(s)])
	out += "   ".join(bits) + "\n"
	out += "Field Notes: %d kinds of land finds   Garden beds: %d\n" % [notes_count(), bed_count()]
	return out
