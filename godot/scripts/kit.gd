extends Node3D
## Your kit, the other ways to fish (all from the Kit tab at Hale's Tackle, as your fisher
## level allows). {tool} (G, or X on a pad) offers whatever can be used where you are:
##   Crab pots: drop one in the water (shallows, estuary, kelp, reef, a wreck, the lake...).
##     It soaks for a few town hours, then haul it up for crabs, lobsters and crayfish you
##     can't catch any other way. Crab bait in the pot means more, and better.
##   Cast net: throw it over the water and pull it in when it's sunk (the gold mark). A good
##     pull brings in several small fish and a load of live bait.
##   Trolling: let lines out behind your boat and keep moving. Fast open-water fish strike
##     out of nowhere; then it's a fight.
##   Speargun: stop the boat over clear water and dive (spearfishing.gd).

const Sea := preload("res://scripts/sea.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const POT_ZONES := ["harbour", "shallows", "estuary", "reef", "kelp", "wreck", "seagrass", "lagoon", "lake", "deep"]
const NET_ZONES := ["harbour", "shallows", "estuary", "reef", "kelp", "wreck", "seagrass", "lagoon", "lake", "blue"]
const TROLL_ZONES := ["blue", "reef", "kelp", "wreck", "shallows", "lagoon", "deep", "seagrass"]
const DIVE_ZONES := ["reef", "kelp", "shallows", "wreck", "lagoon", "seagrass"]
const FAST_SHAPES := ["torp", "gar", "tuna", "marlin", "sail", "mahi", "shark"]
const SOAK := 240.0  # town minutes (four town hours, four real minutes) before a pot's worth hauling
const HAUL_RANGE := 4.5
const NET_BAIT := {"estuary": "prawn", "shallows": "prawn", "seagrass": "prawn", "lake": "worm", "harbour": "pilchard",
	"reef": "livebait", "kelp": "livebait", "wreck": "livebait", "lagoon": "livebait", "blue": "pilchard"}

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var fishing: Node
var boats: Node3D
var school: Node3D
var dialogue: CanvasLayer
var progress: Node
var interiors: Node3D
var spear: CanvasLayer  # the dive (spearfishing.gd)
var troll_on := false
var _buoys: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _troll_t := 0.0
var _troll_lines: MeshInstance3D
var _troll_mesh: ImmediateMesh
var _lures: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _net_ring: MeshInstance3D
var _net := ""  # "", "fly", "sink"
var _net_t := 0.0
var _net_at := Vector3.ZERO
var _net_from := Vector3.ZERO
var _t := 0.0


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
	for pot in save.pots:
		_buoys.append(_make_buoy(Vector3(float(pot.x), 0.0, float(pot.z))))
	_troll_mesh = ImmediateMesh.new()
	_troll_lines = MeshInstance3D.new()
	_troll_lines.mesh = _troll_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.9, 0.8)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_troll_lines.material_override = lm
	_troll_lines.visible = false
	add_child(_troll_lines)
	_net_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.55
	torus.outer_radius = 1.7
	torus.rings = 24
	torus.ring_segments = 4
	_net_ring.mesh = torus
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = Color(0.92, 0.88, 0.75, 0.85)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_ring.material_override = nm
	_net_ring.visible = false
	add_child(_net_ring)


func has_any() -> bool:
	return not (save.kit as Dictionary).is_empty()


func _have(k: String) -> int:
	return int((save.kit as Dictionary).get(k, 0))


func _process(delta: float) -> void:
	_t += delta
	_bob_buoys()
	_update_troll(delta)
	_update_net(delta)
	if Input.is_action_just_pressed("tool") and int(fishing.state) == 0 and not hud.input_blocked() and _net == "":
		if interiors and interiors.is_inside():
			return
		open_kit()


# --- choosing what to use ------------------------------------------------------------------

func open_kit() -> void:
	if not has_any():
		hud.toast("Your kit's empty. Hale's Tackle sells crab pots, cast nets and more (the Kit tab), as your fisher level grows.")
		audio.play("error", -8.0)
		return
	var opts: Array = []  # [label, callable]
	var why: Array[String] = []
	var spot := _water_ahead(3.0, 6.0)
	if _have("pot") > 0:
		var left := _have("pot") - (save.pots as Array).size()
		if left <= 0:
			why.append("all your crab pots are out")
		elif spot == Vector3.INF:
			why.append("face open water to drop a pot")
		elif str(world.zone_at(spot.x, spot.z)) not in POT_ZONES:
			why.append("crab pots won't reach the bottom out here")
		elif _pot_near(spot, 5.0) >= 0:
			why.append("there's a pot right there already")
		else:
			opts.append(["Drop a crab pot (%d left)" % left, _drop_pot.bind(spot)])
	if _have("net") > 0:
		var net_spot := _water_ahead(4.0, 7.0)
		if net_spot != Vector3.INF and str(world.zone_at(net_spot.x, net_spot.z)) in NET_ZONES:
			opts.append(["Throw the cast net", _throw_net.bind(net_spot)])
		else:
			why.append("face open water to throw the net")
	if _have("troll") > 0:
		if boats.aboard:
			opts.append(["Reel in the trolling lines" if troll_on else "Let out the trolling lines", _toggle_troll])
		else:
			why.append("trolling needs a boat")
	if _have("spear") > 0:
		if not boats.aboard:
			why.append("dive from your boat")
		elif absf(float(boats.speed)) > 0.6:
			why.append("stop the boat to dive")
		else:
			var bp: Vector3 = boats.boat.global_position
			var z := str(world.zone_at(bp.x, bp.z))
			if z in DIVE_ZONES:
				opts.append(["Dive with the speargun", _dive.bind(z)])
			else:
				why.append("the water's too murky or deep to dive here (try the reef, kelp, shallows or a wreck)")
	if opts.is_empty():
		hud.toast("Can't use your kit here: %s." % ", ".join(why))
		audio.play("error", -8.0)
		return
	if opts.size() == 1:
		(opts[0][1] as Callable).call()
		return
	var labels: Array = []
	for o in opts:
		labels.append(str(o[0]))
	labels.append("Never mind")
	dialogue.say("Your kit", ["What will you use?"], null, labels, _chose.bind(opts))


func _chose(i: int, opts: Array) -> void:
	if i >= 0 and i < opts.size():
		(opts[i][1] as Callable).call()


## The nearest open water in front of you, between near and far metres away.
func _water_ahead(near: float, far: float) -> Vector3:
	var f: Vector3 = player.facing
	var dir := Vector3(f.x, 0.0, f.z).normalized()
	var d := near
	while d <= far:
		var p := player.global_position + dir * d
		if world.is_water(p.x, p.z):
			return Vector3(p.x, 0.0, p.z)
		d += 0.5
	return Vector3.INF


# --- crab pots ----------------------------------------------------------------------------

func soak_time() -> float:
	return SOAK * (progress.less("sea_legs") if progress else 1.0)


func _drop_pot(at: Vector3) -> void:
	var baited := int(save.bait.get("crabbait", 0)) > 0
	if baited:
		save.bait["crabbait"] = int(save.bait.crabbait) - 1
		hud.refresh_bait()
	var pot := {"x": at.x, "z": at.z, "zone": str(world.zone_at(at.x, at.z)), "t": sea.now(), "bait": baited}
	save.pots.append(pot)
	_buoys.append(_make_buoy(at))
	SaveGame.write(save)
	audio.play("plop", -2.0, 0.7)
	audio.play("splash", -6.0, 0.8)
	var hours := int(round(soak_time() / 60.0))
	var tip := " Baited with crab bait." if baited else " Crab bait (from the general store) would bring in more."
	hud.toast("Pot's down. Come back in about %d town hours to haul it up.%s" % [hours, tip])


func _pot_near(at: Vector3, r: float) -> int:
	var pots: Array = save.pots
	for i in pots.size():
		var p: Dictionary = pots[i]
		if Vector2(float(p.x) - at.x, float(p.z) - at.z).length() < r:
			return i
	return -1


## For town.nearest(): a pot you're close enough to haul.
func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	var pots: Array = save.pots
	var best := {}
	var best_d := HAUL_RANGE
	for i in pots.size():
		var p: Dictionary = pots[i]
		var d := Vector2(float(p.x) - pos.x, float(p.z) - pos.z).length()
		if d < best_d:
			best_d = d
			var ready: bool = float(sea.now()) - float(p.t) >= soak_time()
			best = {"kind": "pot", "i": i, "dist": d,
				"text": "{action} Haul up your crab pot" if ready else "{action} Check your crab pot (still soaking)"}
	return best


func use(it: Dictionary) -> void:
	var i := int(it.i)
	var pots: Array = save.pots
	if i >= pots.size():
		return
	var p: Dictionary = pots[i]
	var left: float = soak_time() - (float(sea.now()) - float(p.t))
	if left > 0.0:
		var mins := int(ceil(left / 60.0))
		dialogue.say("Your crab pot", ["Still soaking. Give it about %d more town hour%s." % [mins, "" if mins == 1 else "s"]], null,
			["Leave it", "Bring it back in (empty)"], _pull_empty.bind(i))
		return
	_haul(i)


func _pull_empty(choice: int, i: int) -> void:
	if choice != 1:
		return
	_remove_pot(i)
	hud.toast("You pull the pot up and stow it. You can drop it anywhere with {tool}.")
	audio.play("whoosh", -6.0)


func _remove_pot(i: int) -> void:
	(save.pots as Array).remove_at(i)
	var b := _buoys[i]
	_buoys.remove_at(i)
	b.queue_free()
	SaveGame.write(save)


func _haul(i: int) -> void:
	var p: Dictionary = save.pots[i]
	var zone := str(p.zone)
	var baited := bool(p.get("bait", false))
	audio.play("crank", -2.0)
	audio.play("splash", -4.0, 0.9)
	# reset it where it is: it keeps fishing for you
	p["t"] = sea.now()
	p["bait"] = false
	if int(save.bait.get("crabbait", 0)) > 0:
		save.bait["crabbait"] = int(save.bait.crabbait) - 1
		p["bait"] = true
		hud.refresh_bait()
	var empty := 0.12 if baited else 0.3
	if _rng.randf() < empty:
		SaveGame.write(save)
		hud.toast("Empty, apart from a very offended hermit crab. The pot's back down." + ("" if baited else " Crab bait would help."))
		return
	var e: Variant = Sea.pick_w(_pot_table(zone, baited), _rng.randf())
	if e == null:
		hud.toast("Empty. The pot's back down for another soak.")
		return
	var cm := Sea.roll_size(e, _rng.randf())
	var v := Sea.roll_variant(e, _rng.randf(), sea.env)
	var again := "Re-baited and dropped again." if bool(p.bait) else "Dropped again."
	fishing.award(e, cm, v, "", "", "From your crab pot. %s" % again)


func _pot_table(zone: String, baited: bool) -> Array:
	var E: Dictionary = sea.env
	var out: Array = []
	for e: Dictionary in sea.items:
		if str(e.z) != zone or not sea.cond_ok(e, E):
			continue
		var r := int(e.r)
		var w := float(sea.rarw[mini(r, sea.rarw.size() - 1)])
		if str(e.how) == "pot":
			out.append([e, w * (1.0 + (0.5 * r if baited else 0.0))])
		elif str(e.cat) == "fish" and str(e.how) == "fish" and Sea.size_class(e) == 0 and r <= 1:
			out.append([e, w * 0.12])  # small bottom fish wander in too
	for id in ["old_boot", "tin_can", "seaweed_clump"]:
		if sea.by_id.has(id):
			out.append([sea.by_id[id], 1.0])
	return out


func _make_buoy(at: Vector3) -> Node3D:
	var b := Node3D.new()
	var float_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.22
	cyl.height = 0.32
	float_mesh.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.42, 0.18)
	float_mesh.material_override = m
	b.add_child(float_mesh)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = 0.9
	pole.mesh = pm
	pole.position = Vector3(0.0, 0.55, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.3, 0.24, 0.18)
	pole.material_override = pmat
	b.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.3, 0.2, 0.02)
	flag.mesh = fm
	flag.position = Vector3(0.16, 0.88, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.98, 0.85, 0.3)
	fmat.emission_enabled = true
	fmat.emission = Color(0.6, 0.45, 0.1)
	flag.material_override = fmat
	b.add_child(flag)
	b.position = Vector3(at.x, float(world.water_level_at(at.x, at.z)), at.z)
	add_child(b)
	return b


func _bob_buoys() -> void:
	var pots: Array = save.pots
	for i in mini(_buoys.size(), pots.size()):
		var b := _buoys[i]
		var p: Dictionary = pots[i]
		var level: float = world.water_level_at(float(p.x), float(p.z))
		b.position.y = level + sin(_t * 2.0 + i) * 0.05
		b.rotation.z = sin(_t * 1.6 + i * 2.0) * 0.12
		# the flag goes up when it's worth hauling
		var flag := b.get_child(2) as MeshInstance3D
		flag.visible = sea.now() - float(p.t) >= soak_time()


# --- the cast net ---------------------------------------------------------------------------

func _throw_net(at: Vector3) -> void:
	_net = "fly"
	_net_t = 0.0
	_net_at = at
	_net_from = player.global_position + Vector3(0.0, 1.4, 0.0)
	player.can_move = false
	player.face((at - player.global_position).normalized())
	hud.modal = true
	audio.play("whoosh", -2.0, 0.8)
	_net_ring.visible = true
	_net_ring.scale = Vector3(0.2, 1.0, 0.2)


func _update_net(delta: float) -> void:
	if _net == "":
		return
	_net_t += delta
	var level: float = world.water_level_at(_net_at.x, _net_at.z)
	if _net == "fly":
		var k := clampf(_net_t / 0.7, 0.0, 1.0)
		var p := _net_from.lerp(Vector3(_net_at.x, level + 0.05, _net_at.z), k)
		p.y += sin(k * PI) * 1.6
		_net_ring.position = p
		var sc := lerpf(0.2, 1.0, k)
		_net_ring.scale = Vector3(sc, 1.0, sc)
		if k >= 1.0:
			_net = "sink"
			_net_t = 0.0
			audio.play("splash", -2.0, 0.8)
			hud.set_prompt("Let it sink... pull with {action} at the gold mark!")
	elif _net == "sink":
		var v := clampf(_net_t / 1.4, 0.0, 1.0)
		hud.show_power(v)
		_net_ring.position.y = level + 0.05 - v * 0.25
		var col: Color = (_net_ring.material_override as StandardMaterial3D).albedo_color
		col.a = 0.85 - v * 0.5
		(_net_ring.material_override as StandardMaterial3D).albedo_color = col
		if Input.is_action_just_pressed("action") or v >= 1.0:
			var pulled := v if v < 1.0 else 1.2
			_finish_net(pulled)


func _finish_net(v: float) -> void:
	hud.hide_power()
	hud.set_prompt("")
	_net = ""
	_net_ring.visible = false
	(_net_ring.material_override as StandardMaterial3D).albedo_color = Color(0.92, 0.88, 0.75, 0.85)
	hud.modal = false
	player.can_move = true
	hud.block_input(0.3)
	audio.play("reel", -4.0, 0.7)
	var quality := "poor"
	if v >= 0.78 and v <= 0.92:
		quality = "perfect"
	elif v >= 0.6 and v < 1.0:
		quality = "good"
	var zone := str(world.zone_at(_net_at.x, _net_at.z))
	var at2 := Vector2(_net_at.x, _net_at.z)
	var rich: bool = school.near_frenzy(at2) or school.lure_landed(at2) < 2.5
	school.lure_cleared()
	var count := _rng.randi_range(0, 1)
	var bait_n := 1
	match quality:
		"perfect":
			count = _rng.randi_range(3, 5)
			bait_n = 8
		"good":
			count = _rng.randi_range(1, 3)
			bait_n = 5
	if rich:
		count += 2
	var bait_k := str(NET_BAIT.get(zone, "pilchard"))
	if rich:
		bait_n += 4
	if sea.bait.has(bait_k) and bait_n > 0:
		save.bait[bait_k] = int(save.bait.get(bait_k, 0)) + bait_n
		hud.refresh_bait()
	var pool := _net_table(zone)
	var caught: Array = []
	for i in count:
		var e: Variant = Sea.pick_w(pool, _rng.randf())
		if e != null:
			caught.append(e)
	var bait_note := ""
	if bait_n > 0 and sea.bait.has(bait_k):
		bait_note = "%d %s for your bait tin." % [bait_n, str(sea.bait[bait_k].n).to_lower()]
	if caught.is_empty():
		hud.toast(("A %s pull. No fish this time. %s" % [quality, bait_note]).strip_edges())
		SaveGame.write(save)
		return
	# the best one gets the card; the rest go straight in the books
	caught.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.r) > int(b.r))
	var others: Array[String] = []
	for j in range(1, caught.size()):
		var o: Dictionary = caught[j]
		fishing.award_quiet(o, Sea.roll_size(o, _rng.randf()))
		others.append(str(o.n))
	var lead: Dictionary = caught[0]
	var note := "A %s pull!" % quality
	if not others.is_empty():
		note += " Also in the net: %s." % ", ".join(others)
	if bait_note != "":
		note += " " + bait_note
	fishing.award(lead, Sea.roll_size(lead, _rng.randf()), "", "", "", note)


func _net_table(zone: String) -> Array:
	var E: Dictionary = sea.env
	var out: Array = []
	for e: Dictionary in sea.items:
		if str(e.cat) != "fish" or str(e.how) != "fish" or str(e.z) != zone or not sea.cond_ok(e, E):
			continue
		var r := int(e.r)
		if r > 1 or Sea.size_class(e) > 1:
			continue
		out.append([e, float(sea.rarw[r]) * (1.5 if Sea.size_class(e) == 0 else 0.6)])
	return out


# --- trolling --------------------------------------------------------------------------------

func _toggle_troll() -> void:
	troll_on = not troll_on
	_troll_lines.visible = troll_on
	if troll_on:
		_troll_t = 4.0
		audio.play("reel", -4.0, 0.6)
		hud.toast("Lines out. Keep her moving over open water, the reef or the kelp, and wait for a strike.")
	else:
		audio.play("reel", -4.0, 1.2)
		hud.toast("Lines in.")


func _update_troll(delta: float) -> void:
	if not troll_on:
		return
	if not boats.aboard or boats.boat == null:
		troll_on = false
		_troll_lines.visible = false
		return
	var b: Vector3 = boats.boat.global_position
	var fwd: Vector3 = boats.forward()
	var side := fwd.cross(Vector3.UP).normalized()
	var stern := b - fwd * 1.6 + Vector3(0.0, 0.6, 0.0)
	for k in 2:
		var want := b - fwd * (9.0 + k * 3.0) + side * (2.2 if k == 0 else -2.2)
		want.y = float(world.water_level_at(want.x, want.z))
		_lures[k] = _lures[k].lerp(want, minf(delta * 3.0, 1.0)) if _lures[k] != Vector3.ZERO else want
	_troll_mesh.clear_surfaces()
	_troll_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 2:
		_troll_mesh.surface_add_vertex(stern + side * (0.4 if k == 0 else -0.4))
		_troll_mesh.surface_add_vertex(_lures[k])
	_troll_mesh.surface_end()
	if int(fishing.state) != 0:
		return
	_troll_t -= delta
	if _troll_t > 0.0:
		return
	_troll_t = 1.0
	var spd := absf(float(boats.speed))
	var zone := str(world.zone_at(b.x, b.z))
	if spd < 2.5 or zone not in TROLL_ZONES:
		return
	var chance := 0.03 + (0.05 if school.near_frenzy(Vector2(b.x, b.z)) else 0.0)
	if _rng.randf() > chance:
		return
	var k2 := _rng.randi_range(0, 1)
	var e: Variant = _troll_pick(zone)
	if e == null:
		return
	troll_on = false
	_troll_lines.visible = false
	boats.speed = float(boats.speed) * 0.3
	hud.toast("Fish on! Something hammered the trolling lure!")
	cam.shake(0.5)
	fishing.troll_strike(e, _lures[k2])


func _troll_pick(zone: String) -> Variant:
	var table: Array = sea.hook_table(zone, "metal", int(fishing.rod_tier()), -1, 1.4)
	var fast: Array = []
	for x: Array in table:
		var e: Dictionary = x[0]
		if str(e.cat) in ["fish", "legend"] and str(e.art) in FAST_SHAPES:
			fast.append([e, float(x[1]) * (1.0 + Sea.size_class(e) * 0.6)])
	if fast.is_empty():
		for x: Array in table:
			if str((x[0] as Dictionary).cat) == "fish":
				fast.append(x)
	return Sea.pick_w(fast, _rng.randf())


# --- spearfishing -------------------------------------------------------------------------

func _dive(zone: String) -> void:
	if troll_on:
		_toggle_troll()
	spear.start(zone)


## Called by the dive when you surface, with what you speared.
func dive_done(caught: Array) -> void:
	hud.block_input(0.4)
	if caught.is_empty():
		hud.toast("You surface empty-handed, lungs burning. The fish will be there next time.")
		return
	caught.sort_custom(func(a: Array, b: Array) -> bool: return int((a[0] as Dictionary).r) > int((b[0] as Dictionary).r))
	var others: Array[String] = []
	for j in range(1, caught.size()):
		var o: Array = caught[j]
		fishing.award_quiet(o[0], float(o[1]))
		others.append(str((o[0] as Dictionary).n))
	var lead: Array = caught[0]
	var note := "Speared on a breath-hold dive."
	if not others.is_empty():
		note += " Also on your stringer: %s." % ", ".join(others)
	fishing.award(lead[0], float(lead[1]), "", "", "", note)
