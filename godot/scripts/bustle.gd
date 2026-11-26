extends Node3D
## Gullhaven, bustling. On top of the town the world file builds (the shops, the docks, the
## shopkeepers) this adds:
##   - more of a town: a chapel with a bell tower, a smokehouse, a net loft, the Salty Pillow
##     inn, a schoolhouse, a harbour warehouse and more cottages (all enterable);
##   - a market square: striped stalls (fish, veg, flowers, bread, trinkets) with stallholders,
##     a fountain with a stone gull, benches and bunting;
##   - harbour clutter: lobster pots, rope, fish drying racks, rowboats on the sand, buoys,
##     a cart, a signpost, chimney smoke and planters by the shop doors;
##   - townsfolk who go about their day (the market and docks in the morning, the square at
##     noon, the tavern of an evening, home at night), chatting as they pass, fishers on the
##     docks who really catch things, children playing round the fountain, a busker and a
##     town crier with the news;
##   - animals: dogs, chickens, goats, ducks, seals on the docks and pelicans on the posts;
##   - fishing boats moored at the docks and others sailing out and back.
## Townsfolk can be talked to; some have side quests (sidequests.gd).

const Models := preload("res://scripts/models.gd")
const Billboard := preload("res://scripts/billboard.gd")
const Character := preload("res://scripts/character.gd")
const Boats := preload("res://scripts/boats.gd")

const TOWN := Vector3(410.0, 0.0, 575.0)
const ACTIVE := 150.0  # only bother when you're this close
const WALK := [0, 1, 0, 2]

# new buildings (kind, x, z, w, d, h, rot, wall, roof, name)
const BUILDINGS := [
	["hall", 356, 548, 9, 8, 4.6, 0, "plaster", "roof_blue", "Chapel of the Tides"],
	["house", 428, 546, 6, 5, 3.0, 0, "stone", "roof_red", "Smokehouse"],
	["house", 360, 610, 6, 5, 3.6, 0, "timber", "roof_green", "Net Loft"],
	["tavern", 372, 616, 9, 7, 4.2, 0, "timber", "roof_blue", "The Salty Pillow"],
	["hall", 350, 585, 8, 6, 3.6, 0, "plaster", "roof_red", "Schoolhouse"],
	["shop", 426, 530, 10, 6, 4.0, 0, "planks", "roof_green", "Harbour Warehouse"],
	["house", 350, 562, 5, 5, 3.0, 0, "plaster", "roof_blue", "Cottage"],
	["house", 372, 532, 5, 5, 3.2, 0, "timber", "roof_red", "Cottage"],
	["house", 380, 535, 5, 5, 3.0, 1, "stone", "roof_green", "Cottage"],
	["house", 362, 590, 5, 5, 3.2, 0, "plaster", "roof_red", "Cottage"],
	["house", 368, 545, 5, 5, 3.0, 0, "timber", "roof_blue", "Cottage"],
	["house", 380, 622, 5, 5, 3.0, 0, "plaster", "roof_green", "Cottage"],
]
const STALLS := [["stall_veg", 416, 571, "Ada Turnbull"], ["stall_fish", 430.5, 580.5, "Bart Mackerel"],
	["stall_bread", 416, 598, "Teddy Crumb"], ["stall_flowers", 421, 599, "Rosie Bloom"], ["stall_trinkets", 426, 603, "Magpie Mo"]]
const FIRST := ["Ada", "Alf", "Bea", "Bertie", "Cal", "Clem", "Dot", "Edie", "Fen", "Flo", "Gus", "Hattie", "Ivy", "Jem", "Kit", "Lou",
	"Mabel", "Ned", "Ola", "Percy", "Quin", "Ros", "Sid", "Tam", "Una", "Vi", "Wilf", "Wren", "Archie", "Bo", "Cora", "Dez", "Elsie"]
const LAST := ["Brine", "Cockle", "Dunn", "Ferris", "Gale", "Haddock", "Keel", "Ling", "Marsh", "Netley", "Oakes", "Pike", "Reed",
	"Salt", "Tern", "Wade", "Whelk", "Yarrow", "Pollock", "Skerry"]
const CHAT := ["Fine morning for it!", "Mackerel's running, they say.", "Did you hear? A kraken past the reef!", "Mind the gulls, they're bold today.",
	"Juniper's buns are still warm.", "Tide's on the turn.", "Lovely day for the market.", "My Bert caught a bass this long!",
	"Storm coming, I can feel it in my knees.", "The bell's ringing for noon.", "Fresh crab at Bart's stall!", "Have you tried the smokehouse kippers?",
	"Rosa's doing fish pie tonight.", "Who left a lobster pot on the steps?", "Ooh, look at that boat!", "The Salty Pillow's got a new fiddler.",
	"Lost my hat to the wind again.", "Morning!", "Busy down the docks today.", "That's a fine catch, fisher!", "Have you seen my dog?",
	"They say the Gull's Eye still shines out there somewhere.", "Back to work, then.", "Mind your step on the quay."]
const NIGHT_CHAT := ["Another pint, Rosa!", "Goodnight, all!", "Look at those stars.", "One more song!", "Home to bed, I think."]
const CRIER := ["Hear ye! Fresh fish at the market today!", "Hear ye! A sea serpent was seen off the reef!", "Hear ye! Fish pie at the Gull & Anchor!",
	"Hear ye! Mind the high tide on the south beach!", "Hear ye! The museum wants big fish!", "Hear ye! Treasure maps wash up for those who look!",
	"Hear ye! Market's open till sundown!"]
const KID_LINES := ["Can't catch me!", "You're it!", "Wheee!", "Ha ha!", "Tag!"]

var main: Node
var world: Node3D
var _root: Node3D
var _people: Array = []  # {node, name, look, home, pos, target, state, t, speed, kind, bubble, bubble_t, walk, facing, quest}
var _animals: Array = []  # {node, kind, home, r, target, t, speed, water}
var _boats: Array = []  # {node, from, out, t, period, phase}
var _smoke: Array = []
var _blocks: Array[Rect2] = []
var _poi := {}
var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _crier_t := 20.0
var _fishers: Array = []
var _active := true
var quest_hook: Callable  # (person) -> Dictionary of talk overrides, from sidequests.gd


func setup(m: Node) -> void:
	main = m
	world = main.harbour
	_rng.seed = 7741
	_root = Node3D.new()
	_root.name = "Bustle"
	add_child(_root)
	_build_buildings()
	_collect_blocks()
	_build_square()
	_build_harbour_clutter()
	_build_smoke()
	_make_pois()
	_spawn_people()
	_spawn_animals()
	_spawn_boats()
	main.town.providers.append(self)


# --- the town -------------------------------------------------------------------------------------

func _town_dict() -> Dictionary:
	for t in world.meta.towns:
		if str(t.id) == "gullhaven":
			return t
	return {}


func _build_buildings() -> void:
	var t := _town_dict()
	var builder: RefCounted = world.builder
	for b in BUILDINGS:
		var x := float(b[1])
		var z := float(b[2])
		if world.is_water(x, z):
			continue
		var h := 0.0
		for dx in [-0.5, 0.5]:
			for dz in [-0.5, 0.5]:
				h = maxf(h, float(world.height_at(x + dx * float(b[3]), z + dz * float(b[4]))))
		var d := {"kind": b[0], "x": x, "z": z, "w": b[3], "d": b[4], "h": b[5], "rot": b[6], "wall": b[7], "roof": b[8],
			"name": b[9], "sign": "", "role": "", "y": h}
		builder.building(_root, d, t)
	# the chapel's bell tower, beside it
	var tower := Models.make("town", "bell_tower")
	if tower:
		_root.add_child(tower)
		tower.global_position = Vector3(349.0, float(world.height_at(349.0, 547.0)), 547.0)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.2, 8.0, 2.2)
		col.shape = box
		col.position.y = 4.0
		body.add_child(col)
		tower.add_child(body)


## Building footprints (people walk round them).
func _collect_blocks() -> void:
	for b in world.buildings:
		if str(b.get("town", "")) != "gullhaven":
			continue
		var node: Node3D = b.node
		if not is_instance_valid(node):
			continue
		var size: Vector3 = b.size
		var r := float(b.rot)
		var w := size.x
		var d := size.z
		if absf(sin(r)) > 0.5:
			w = size.z
			d = size.x
		var p := node.global_position
		_blocks.append(Rect2(p.x - w * 0.5 - 0.5, p.z - d * 0.5 - 0.5, w + 1.0, d + 1.0))
	_blocks.append(Rect2(347.4, 545.4, 3.2, 3.2))


func _free(x: float, z: float) -> bool:
	if world.is_water(x, z) or not world.walkable(x, z):
		var on_dock := false
		for dk in world.docks:
			if (dk.rect as Rect2).has_point(Vector2(x, z)):
				on_dock = true
		if not on_dock:
			return false
	for r in _blocks:
		if r.has_point(Vector2(x, z)):
			return false
	return true


func _place(group: String, name: String, x: float, z: float, turn := 0.0, scale_by := 1.0, solid := Vector2.ZERO) -> Node3D:
	var n := Models.make(group, name)
	if n == null:
		return null
	_root.add_child(n)
	n.global_position = Vector3(x, float(world.stand_height(x, z)), z)
	n.rotation.y = turn
	n.scale = Vector3.ONE * scale_by
	if solid != Vector2.ZERO:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(solid.x, 1.6, solid.y)
		col.shape = box
		col.position.y = 0.8
		body.add_child(col)
		n.add_child(body)
		var c := Vector2(x, z)
		var half := Vector2(maxf(solid.x, solid.y), maxf(solid.x, solid.y)) * 0.5 + Vector2(0.3, 0.3)
		_blocks.append(Rect2(c - half, half * 2.0))
	return n


func _build_square() -> void:
	_place("town", "fountain", 420.5, 588.0, 0.0, 1.0, Vector2(4.4, 4.4))
	for s in STALLS:
		_place("town", str(s[0]), float(s[1]), float(s[2]), 0.0, 1.0, Vector2(2.7, 1.3))
	for b in [[420.5, 592.8, 0.0], [416.0, 588.0, PI * 0.5], [425.0, 584.0, PI]]:
		_place("outdoor", "bench", float(b[0]), float(b[1]), float(b[2]))
	# bunting across the square
	for line in [[Vector3(414.5, 0, 577.0), Vector3(436.0, 0, 577.0)], [Vector3(414.5, 0, 596.5), Vector3(424.5, 0, 596.5)],
			[Vector3(414.5, 0, 568.0), Vector3(414.5, 0, 607.0)]]:
		_bunting(line[0], line[1])


func _bunting(a: Vector3, b: Vector3) -> void:
	var cols := [Color(1.0, 1.0, 1.0), Color(0.3, 0.55, 1.4), Color(1.5, 1.3, 0.3), Color(0.5, 1.4, 0.5), Color(1.4, 1.4, 1.4)]
	var ya := float(world.stand_height(a.x, a.z))
	var yb := float(world.stand_height(b.x, b.z))
	for p in [a, b]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.06
		cyl.height = 3.6
		pole.mesh = cyl
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.45, 0.32, 0.2)
		pole.material_override = pm
		_root.add_child(pole)
		pole.global_position = Vector3(p.x, float(world.stand_height(p.x, p.z)) + 1.8, p.z)
	var n := int(a.distance_to(b) / 0.6)
	for i in n:
		var k := (i + 0.5) / n
		var p := a.lerp(b, k)
		var flag := Models.make("town", "bunting_flag")
		if flag == null:
			return
		var c: Color = cols[i % cols.size()]
		if c != Color(1, 1, 1):
			Models.tint(flag, c * Color(0.6, 0.6, 0.6))
		_root.add_child(flag)
		flag.global_position = Vector3(p.x, lerpf(ya, yb, k) + 3.5 - sin(k * PI) * 0.7, p.z)
		flag.rotation.y = atan2(-(b.z - a.z), b.x - a.x)


func _build_harbour_clutter() -> void:
	for p in [[442.0, 552.0], [442.0, 586.0], [441.5, 603.0]]:
		_place("town", "lobster_pots", p[0], p[1], PI * 0.5, 1.0, Vector2(1.0, 1.0))
	for p in [[442.5, 568.0], [442.2, 597.5], [449.0, 561.8], [455.0, 578.8]]:
		_place("town", "rope_coil", p[0], p[1])
	for p in [[452.0, 543.0], [459.0, 543.5]]:
		_place("town", "drying_rack", p[0], p[1], 0.0, 1.0, Vector2(2.0, 0.8))
	for p in [[430.0, 616.0, 0.4], [437.0, 621.0, -0.2], [444.0, 611.0, 1.2], [462.0, 545.0, 2.9]]:
		_place("town", "rowboat", p[0], p[1], p[2], 1.0, Vector2(3.0, 1.2))
	for p in [[488.0, 568.0], [494.0, 586.0], [478.0, 603.0], [500.0, 550.0]]:
		var bu := Models.make("town", "buoy")
		if bu:
			_root.add_child(bu)
			bu.global_position = Vector3(p[0], float(world.water_level_at(p[0], p[1])), p[1])
			_animals.append({"node": bu, "kind": "buoy", "home": bu.global_position, "t": _rng.randf() * 5.0})
	_place("town", "cart", 411.0, 568.5, 0.3, 1.0, Vector2(1.8, 1.2))
	_place("town", "signpost", 396.5, 568.0, 0.0)
	# planters either side of the shop doors
	for b in world.buildings:
		if str(b.get("town", "")) != "gullhaven" or str(b.role) == "":
			continue
		var node: Node3D = b.node
		var size: Vector3 = b.size
		for side in [-1.0, 1.0]:
			var local := Vector3(side * minf(size.x * 0.5 - 0.6, 2.0), 0.0, size.z * 0.5 + 0.45)
			var at := node.global_transform * local
			var pl := Models.make("outdoor", "planter")
			if pl:
				_root.add_child(pl)
				pl.global_position = Vector3(at.x, float(world.stand_height(at.x, at.z)), at.z)
				pl.rotation.y = node.rotation.y
				pl.scale = Vector3(0.7, 0.8, 0.7)


func _build_smoke() -> void:
	var low: bool = OS.has_feature("web") and DisplayServer.is_touchscreen_available()
	for b in world.buildings:
		if str(b.get("town", "")) != "gullhaven" or not (str(b.kind) in ["house", "tavern"]):
			continue
		var node: Node3D = b.node
		var size: Vector3 = b.size
		var top := node.global_transform * Vector3(size.x * 0.28, size.y + 2.4, -0.6)
		var p := CPUParticles3D.new()
		p.amount = 6 if low else 12
		p.lifetime = 4.0
		p.preprocess = 4.0
		p.direction = Vector3(0.25, 1.0, 0.1)
		p.spread = 12.0
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 0.9
		p.gravity = Vector3(0.12, 0.05, 0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(1.0, 1.6))
		p.scale_amount_curve = curve
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.85, 0.85, 0.88, 0.35)
		mat.vertex_color_use_as_albedo = true
		mesh.material = mat
		p.mesh = mesh
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.8))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = grad
		_root.add_child(p)
		p.global_position = top
		_smoke.append(p)


# --- where people go -----------------------------------------------------------------------------

func _make_pois() -> void:
	_poi = {
		"market": [Vector3(416, 0, 573), Vector3(430.5, 0, 582.6), Vector3(416, 0, 600), Vector3(421, 0, 601), Vector3(426, 0, 605),
			Vector3(419, 0, 580), Vector3(424, 0, 590)],
		"square": [Vector3(418, 0, 584), Vector3(423, 0, 592), Vector3(424, 0, 582), Vector3(417, 0, 592), Vector3(420, 0, 580)],
		"docks": [Vector3(452, 0, 560), Vector3(460, 0, 560), Vector3(455, 0, 577), Vector3(466, 0, 577), Vector3(452, 0, 594),
			Vector3(442, 0, 560), Vector3(442, 0, 577), Vector3(442, 0, 592)],
		"tavern": [Vector3(429, 0, 596), Vector3(432, 0, 597), Vector3(372, 0, 621), Vector3(375, 0, 621)],
		"streets": [Vector3(390, 0, 565), Vector3(380, 0, 583), Vector3(400, 0, 600), Vector3(400, 0, 545), Vector3(410, 0, 583),
			Vector3(385, 0, 565), Vector3(356, 0, 554), Vector3(350, 0, 590), Vector3(370, 0, 575)],
		"beach": [Vector3(428, 0, 612), Vector3(436, 0, 616), Vector3(450, 0, 542), Vector3(440, 0, 625)],
	}


func _routine_pick(p: Dictionary) -> Vector3:
	var hour := float(main.sea.env.get("hour", 12.0))
	var weights := {}
	if hour < 6.0 or hour >= 23.0:
		weights = {"home": 8.0, "tavern": 1.0}
	elif hour < 11.0:
		weights = {"market": 4.0, "docks": 4.0, "streets": 2.0, "beach": 1.0}
	elif hour < 15.0:
		weights = {"square": 4.0, "market": 3.0, "streets": 2.0, "beach": 2.0, "docks": 1.0}
	elif hour < 19.0:
		weights = {"streets": 3.0, "market": 2.0, "docks": 2.0, "square": 2.0, "beach": 1.0}
	else:
		weights = {"tavern": 5.0, "square": 2.0, "home": 2.0, "streets": 1.0}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			if k == "home":
				return p.home
			var list: Array = _poi[k]
			var v: Vector3 = list[_rng.randi() % list.size()]
			return v + Vector3(_rng.randf_range(-1.2, 1.2), 0.0, _rng.randf_range(-1.2, 1.2))
	return p.home


# --- people ---------------------------------------------------------------------------------------

func _random_look() -> Dictionary:
	var hats := ["", "", "beanie", "cap", "bucket", "straw", "bandana", "captain"]
	var styles := ["short", "bob", "long", "ponytail", "bun", "spiky", "bald"]
	var tops := ["tee", "coat", "vest", "overalls", "apron"]
	var colours := ["#c84a3a", "#3a6ab0", "#e8b23a", "#5f8f5a", "#8a5ac8", "#2f8a8a", "#e8e2d0", "#3a3a40", "#d8783a", "#e07aa0"]
	var hairs := ["#2a1a10", "#6a4028", "#c8a060", "#e8d8b0", "#8a3a20", "#3a3a3a", "#d0d0d0", "#f0f0f0"]
	var look := Character.default_look()
	look.merge({"skin": Character.SKIN_ORDER[_rng.randi() % Character.SKIN_ORDER.size()], "hair": hairs[_rng.randi() % hairs.size()],
		"style": styles[_rng.randi() % styles.size()], "hat": hats[_rng.randi() % hats.size()],
		"hatc": colours[_rng.randi() % colours.size()], "shirt": colours[_rng.randi() % colours.size()],
		"top": tops[_rng.randi() % tops.size()], "garment": colours[_rng.randi() % colours.size()],
		"pants": ["#2e3f6e", "#3a3a40", "#5a4a3a", "#4a5a3a", "#6a3a3a"][_rng.randi() % 5],
		"legs": "dress" if _rng.randf() < 0.3 else "trousers", "beard": "" if _rng.randf() < 0.7 else "full"}, true)
	return look


func _person(name: String, at: Vector3, kind: String, look := {}) -> Dictionary:
	if look.is_empty():
		look = _random_look()
	var tex := Character.texture(look)
	if tex == null:
		return {}
	var s := Billboard.sprite(tex, 1.0 / 26.0, 5, 4, 46.0)
	_root.add_child(s)
	s.global_position = Vector3(at.x, float(world.stand_height(at.x, at.z)), at.z)
	var bubble := Label3D.new()
	bubble.font = load("res://art/fonts/pixelify_sans_bold.woff2")
	bubble.font_size = 22
	bubble.outline_size = 8
	bubble.pixel_size = 0.0011  # same size on screen however far away
	bubble.fixed_size = true
	bubble.width = 420.0
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.modulate = Color(1.0, 0.97, 0.88)
	bubble.outline_modulate = Color(0.08, 0.06, 0.12)
	bubble.position = Vector3(0.0, 2.35, 0.0)
	bubble.visible = false
	bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.add_child(bubble)
	var p := {"node": s, "name": name, "look": look, "home": s.global_position, "pos": s.global_position, "target": s.global_position,
		"state": "idle", "t": _rng.randf_range(0.5, 6.0), "speed": _rng.randf_range(1.1, 1.7), "kind": kind, "bubble": bubble,
		"bubble_t": 0.0, "walk": 0.0, "facing": Vector3.BACK, "stuck": 0.0}
	_people.append(p)
	return p


func _spawn_people() -> void:
	# stallholders, standing behind their stalls
	for s in STALLS:
		var p := _person(str(s[3]), Vector3(float(s[1]), 0.0, float(s[2]) - 0.95), "vendor")
		if not p.is_empty():
			p.facing = Vector3.BACK
	# townsfolk with homes at the cottages and houses
	var homes: Array = []
	for b in world.buildings:
		if str(b.get("town", "")) == "gullhaven":
			var door: Vector3 = b.door
			if _free(door.x, door.z):
				homes.append(door)
	var n := 22
	for i in n:
		var home: Vector3 = homes[i % homes.size()] if not homes.is_empty() else TOWN
		var nm := "%s %s" % [FIRST[_rng.randi() % FIRST.size()], LAST[_rng.randi() % LAST.size()]]
		var start := _routine_pick({"home": home})
		if not _free(start.x, start.z):
			start = home
		var p := _person(nm, start, "walker")
		if not p.is_empty():
			p.home = home
	# fishers on the docks, legs over the edge
	for f in [[449.5, 561.4], [458.5, 561.4], [468.0, 561.4], [452.5, 578.4], [472.0, 578.4], [461.0, 595.4]]:
		var p := _person("%s %s" % [FIRST[_rng.randi() % FIRST.size()], LAST[_rng.randi() % LAST.size()]], Vector3(f[0], 0, f[1]), "fisher")
		if p.is_empty():
			continue
		p.facing = Vector3.BACK
		p.t = _rng.randf_range(10.0, 40.0)
		var rod := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.012
		cyl.bottom_radius = 0.025
		cyl.height = 2.2
		rod.mesh = cyl
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.45, 0.3, 0.18)
		rod.material_override = rm
		(p.node as Node3D).add_child(rod)
		rod.position = Vector3(0.25, 1.4, 0.6)
		rod.rotation = Vector3(deg_to_rad(55.0), 0.0, 0.0)
		_fishers.append(p)
	# children round the fountain
	for i in 2:
		var p := _person(["Wren", "Lottie's cousin Kit"][i], Vector3(420.5, 0, 584.0 + i * 8.0), "kid")
		if not p.is_empty():
			p.speed = 2.6
			p.t = i * PI
	# a busker by the fountain, and the town crier at the crossroads
	var busk := _person("Fiddler Finn", Vector3(424.6, 0, 589.0), "busker")
	if not busk.is_empty():
		busk.facing = Vector3.LEFT
	var crier := _person("Crier Bartholomew", Vector3(398.0, 0, 568.5), "crier")
	if not crier.is_empty():
		crier.facing = Vector3.BACK


func person(name: String) -> Dictionary:
	for p in _people:
		if str(p.name) == name:
			return p
	return {}


func say(p: Dictionary, text: String, secs := 3.5) -> void:
	var b: Label3D = p.bubble
	b.text = text
	b.visible = true
	p.bubble_t = secs


func _process(delta: float) -> void:
	var me: Vector3 = main.player.global_position
	var near: bool = Vector2(me.x - TOWN.x, me.z - TOWN.z).length() < ACTIVE and not main.interiors.is_inside()
	if near != _active:
		_active = near
		_root.visible = near
	if not near:
		return
	var cam: Camera3D = main.cam
	_crier_t -= delta
	for p in _people:
		_step_person(p, delta, cam, me)
	for a in _animals:
		_step_animal(a, delta)
	for b in _boats:
		_step_boat(b, delta)


func _step_person(p: Dictionary, delta: float, cam: Camera3D, me: Vector3) -> void:
	var node: Sprite3D = p.node
	p.bubble_t = float(p.bubble_t) - delta
	(p.bubble as Label3D).visible = float(p.bubble_t) > 0.0
	var kind := str(p.kind)
	var moving := false
	match kind:
		"walker":
			moving = _walk(p, delta)
		"kid":
			p.t = float(p.t) + delta * 0.55
			var c := Vector3(420.5, 0.0, 588.0)
			var at := c + Vector3(cos(float(p.t)) * 3.6, 0.0, sin(float(p.t)) * 3.6)
			p.facing = Vector3(-sin(float(p.t)), 0.0, cos(float(p.t)))
			node.global_position = Vector3(at.x, float(world.stand_height(at.x, at.z)), at.z)
			moving = true
			if _rng.randf() < delta * 0.08:
				say(p, KID_LINES[_rng.randi() % KID_LINES.size()], 1.8)
		"fisher":
			p.t = float(p.t) - delta
			if float(p.t) <= 0.0:
				p.t = _rng.randf_range(25.0, 70.0)
				_fisher_catch(p)
		"busker":
			if float(p.bubble_t) < -2.0:
				say(p, ["~ la la la ~", "~ hey ho, the tide ~", "~ a fisher's life ~", "~ fiddle-dee ~"][_rng.randi() % 4], 3.0)
		"crier":
			if _crier_t <= 0.0:
				_crier_t = _rng.randf_range(25.0, 40.0)
				say(p, _crier_line(), 5.0)
		"vendor":
			if _rng.randf() < delta * 0.03 and me.distance_to(node.global_position) < 18.0:
				say(p, ["Fresh today!", "Come and have a look!", "Two for a Shell!", "Lovely and ripe!", "Best in Gullhaven!"][_rng.randi() % 5], 2.5)
	# look at you when you're close and they're standing still
	if not moving and me.distance_to(node.global_position) < 3.0 and kind != "fisher":
		p.facing = (me - node.global_position).normalized()
	var row := Billboard.row_for(p.facing, cam)
	var col := 0
	if moving:
		p.walk = float(p.walk) + delta * 8.0
		col = WALK[int(p.walk) % 4]
	elif kind == "fisher":
		row = Billboard.UP if absf(cam.global_rotation.y) < 1.5 else Billboard.DOWN
		col = 3
	node.frame = row * 5 + col


func _walk(p: Dictionary, delta: float) -> bool:
	var node: Sprite3D = p.node
	var pos := node.global_position
	if str(p.state) == "idle":
		p.t = float(p.t) - delta
		if float(p.t) <= 0.0:
			p.target = _routine_pick(p)
			p.state = "go"
			p.stuck = 0.0
			node.visible = true
		elif node.visible and float(p.bubble_t) < -6.0 and _rng.randf() < delta * 0.05:
			var hour := float(main.sea.env.get("hour", 12.0))
			say(p, (NIGHT_CHAT if hour >= 19.0 or hour < 6.0 else CHAT)[_rng.randi() % (NIGHT_CHAT if hour >= 19.0 or hour < 6.0 else CHAT).size()])
		return false
	var target: Vector3 = p.target
	var to := Vector2(target.x - pos.x, target.z - pos.z)
	if to.length() < 0.4:
		p.state = "idle"
		p.t = _rng.randf_range(4.0, 14.0)
		# home at night: go in
		if target.distance_to(p.home) < 0.6:
			var hour := float(main.sea.env.get("hour", 12.0))
			if hour < 6.0 or hour >= 22.0:
				node.visible = false
				p.t = _rng.randf_range(30.0, 90.0)
		return false
	var dir := to.normalized()
	var step := dir * float(p.speed) * delta
	var next := Vector2(pos.x, pos.z) + step
	if not _free(next.x, next.y):
		# try going round
		for ang in [0.7, -0.7, 1.4, -1.4, 2.1, -2.1]:
			var alt := Vector2(pos.x, pos.z) + step.rotated(ang)
			if _free(alt.x, alt.y):
				next = alt
				dir = step.rotated(ang).normalized()
				break
		p.stuck = float(p.stuck) + delta
		if float(p.stuck) > 6.0 or not _free(next.x, next.y):
			p.state = "idle"
			p.t = _rng.randf_range(0.5, 2.0)
			return false
	p.facing = Vector3(dir.x, 0.0, dir.y)
	node.global_position = Vector3(next.x, float(world.stand_height(next.x, next.y)), next.y)
	return true


func _crier_line() -> String:
	var lines: Array = CRIER.duplicate()
	if main.get("empire") and int(main.empire.E().trips) > 0:
		lines.append("Hear ye! A new fishing fleet sails from Gran's jetty!")
	if main.save.has("monsters") and not (main.save.monsters as Dictionary).is_empty():
		lines.append("Hear ye! A brave fisher drove off a sea monster!")
	return str(lines[_rng.randi() % lines.size()])


func _fisher_catch(p: Dictionary) -> void:
	var node: Sprite3D = p.node
	var ids: Array = []
	for id in ["mackerel", "whiting", "bream", "flathead", "tailor", "salmon", "herring", "garfish", "leatherjacket", "trevally"]:
		if Models.has("fish", id):
			ids.append(id)
	if ids.is_empty():
		var dir := DirAccess.open("res://models/fish")
		if dir:
			for f in dir.get_files():
				if f.ends_with(".glb") and ids.size() < 20:
					ids.append(f.get_basename())
	if ids.is_empty():
		return
	var fish := Models.make("fish", str(ids[_rng.randi() % ids.size()]))
	if fish == null:
		return
	fish.scale = Vector3.ONE * 0.35
	_root.add_child(fish)
	var start := node.global_position + Vector3(0.4, -0.6, 2.2)
	var end := node.global_position + Vector3(0.0, 1.9, 0.2)
	var tw := fish.create_tween()
	tw.tween_method(func(k: float) -> void:
		fish.global_position = start.lerp(end, k) + Vector3(0.0, sin(k * PI) * 1.2, 0.0)
		fish.rotation = Vector3(0.0, -PI * 0.5, sin(k * 20.0) * 0.4), 0.0, 1.0, 1.1)
	tw.tween_interval(1.4)
	tw.tween_callback(fish.queue_free)
	say(p, ["Got one!", "Supper!", "A beauty!", "Ha! Another!", "Tiddler..."][_rng.randi() % 5], 2.5)


# --- talking to them ---------------------------------------------------------------------------------

func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	if not _active:
		return {}
	var best := {}
	var best_d := 1.7
	for p in _people:
		var node: Sprite3D = p.node
		if not node.visible:
			continue
		var d := Vector2(node.global_position.x - pos.x, node.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			var text := "Space: Talk to %s" % p.name
			if quest_hook.is_valid():
				var q: Dictionary = quest_hook.call(p, true)
				if q.has("prompt"):
					text = str(q.prompt)
			best = {"kind": "townsfolk", "person": p, "dist": d, "text": text}
	return best


func use(it: Dictionary) -> void:
	var p: Dictionary = it.person
	var node: Sprite3D = p.node
	p.state = "idle"
	p.t = 6.0
	p.facing = (main.player.global_position - node.global_position).normalized()
	if quest_hook.is_valid():
		var q: Dictionary = quest_hook.call(p, false)
		if q.has("handled"):
			return
	var lines: Array = []
	match str(p.kind):
		"vendor":
			lines = ["Everything's fresh this morning, love.", "Come back tomorrow, there'll be more!"]
		"fisher":
			lines = ["Shh, you'll scare the fish.", "They're biting better off the end of the dock, mind."]
		"kid":
			lines = ["Wanna play tag? You're it!"]
		"busker":
			lines = ["A song for a Shell? No? Here's one for free, then."]
		"crier":
			lines = [_crier_line(), "News of the town, every hour on the hour!"]
		_:
			lines = [CHAT[_rng.randi() % CHAT.size()], CHAT[_rng.randi() % CHAT.size()]]
	main.dialogue.say(str(p.name), lines, node.texture)


# --- animals ----------------------------------------------------------------------------------------

func _spawn_animals() -> void:
	var spots := [
		["dog", 420.0, 580.0, 10.0, 1.6], ["dog", 445.0, 600.0, 8.0, 1.8], ["dog", 380.0, 565.0, 8.0, 1.4],
		["chicken", 366.0, 566.0, 3.5, 0.6], ["chicken", 367.0, 567.0, 3.5, 0.6], ["chicken", 365.0, 568.0, 3.5, 0.6],
		["chicken", 368.0, 565.0, 3.5, 0.6], ["chicken", 387.0, 557.0, 3.0, 0.6],
		["goat", 345.0, 572.0, 4.0, 0.5], ["goat", 344.0, 576.0, 4.0, 0.5],
		["duck", 455.0, 620.0, 5.0, 0.5], ["duck", 456.0, 621.0, 5.0, 0.5], ["duck", 457.0, 619.0, 5.0, 0.5], ["duck", 470.0, 615.0, 4.0, 0.5],
		["seal", 476.0, 560.2, 0.0, 0.0], ["seal", 469.5, 594.0, 0.0, 0.0],
		["pelican", 462.0, 558.7, 0.0, 0.0], ["pelican", 474.0, 579.3, 0.0, 0.0], ["pelican", 456.0, 596.3, 0.0, 0.0],
	]
	for s in spots:
		var kind := str(s[0])
		var x := float(s[1])
		var z := float(s[2])
		var n := Models.make("animals", kind)
		if n == null:
			continue
		_root.add_child(n)
		var water := kind == "duck"
		var y := float(world.water_level_at(x, z)) if water else float(world.stand_height(x, z))
		n.global_position = Vector3(x, y, z)
		n.rotation.y = _rng.randf() * TAU
		_animals.append({"node": n, "kind": kind, "home": Vector3(x, y, z), "r": float(s[3]), "speed": float(s[4]), "target": Vector3(x, y, z),
			"t": _rng.randf_range(1.0, 5.0), "water": water, "walk": 0.0})


func _step_animal(a: Dictionary, delta: float) -> void:
	var n: Node3D = a.node
	a.t = float(a.t) - delta
	match str(a.kind):
		"buoy":
			var h: Vector3 = a.home
			n.global_position.y = float(world.water_level_at(h.x, h.z)) + sin(float(a.t) * 1.3) * 0.08
			n.rotation.z = sin(float(a.t) * 0.9) * 0.12
			return
		"seal":
			n.rotation.z = sin(Time.get_ticks_msec() * 0.0012 + float(a.home.x)) * 0.05
			if float(a.t) <= 0.0:
				a.t = _rng.randf_range(6.0, 15.0)
				var tw := n.create_tween()
				tw.tween_property(n, "rotation:x", 0.35, 0.25)
				tw.tween_property(n, "rotation:x", 0.0, 0.35)
			return
		"pelican":
			if float(a.t) <= 0.0:
				a.t = _rng.randf_range(3.0, 9.0)
				var tw := n.create_tween()
				tw.tween_property(n, "rotation:y", n.rotation.y + _rng.randf_range(-1.2, 1.2), 0.4)
			return
	if float(a.t) > 0.0 and n.global_position.distance_to(a.target) < 0.2:
		n.position.y = lerpf(n.position.y, (a.target as Vector3).y, 0.2)
		return
	var target: Vector3 = a.target
	var pos := n.global_position
	var to := Vector2(target.x - pos.x, target.z - pos.z)
	if to.length() < 0.2:
		var home: Vector3 = a.home
		var ang := _rng.randf() * TAU
		var r := _rng.randf() * float(a.r)
		var t := home + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var ok: bool = world.is_water(t.x, t.z) if bool(a.water) else _free(t.x, t.z)
		if ok:
			a.target = Vector3(t.x, 0.0, t.z)
		a.t = _rng.randf_range(1.5, 6.0) * (0.4 if str(a.kind) == "dog" else 1.0)
		return
	var step := to.normalized() * float(a.speed) * delta
	var nx := pos.x + step.x
	var nz := pos.z + step.y
	var y := float(world.water_level_at(nx, nz)) if bool(a.water) else float(world.stand_height(nx, nz))
	a.walk = float(a.walk) + delta * 12.0
	var hop := absf(sin(float(a.walk))) * (0.05 if str(a.kind) != "duck" else 0.0)
	n.global_position = Vector3(nx, y + hop, nz)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(-step.y, step.x), 0.2)
	if str(a.kind) == "chicken" and _rng.randf() < delta * 0.5:
		n.rotation.z = 0.4  # peck
	else:
		n.rotation.z = lerpf(n.rotation.z, 0.0, 0.2)


# --- boats --------------------------------------------------------------------------------------------

func _spawn_boats() -> void:
	var kinds := ["row", "dinghy", "skiff", "trawler", "skiff", "dinghy", "trawler"]
	var paints: Array = Boats.PAINT
	# moored along the docks
	var moor := [[452.0, 557.4, PI * 0.5], [466.0, 557.4, PI * 0.5], [458.0, 574.4, PI * 0.5], [476.0, 581.6, PI * 0.5],
		[450.0, 591.4, PI * 0.5], [462.0, 598.6, PI * 0.5]]
	for i in moor.size():
		var m: Array = moor[i]
		if not world.is_water(float(m[0]), float(m[1])):
			continue
		var info: Dictionary = Boats.boat_info(str(kinds[i % kinds.size()]))
		var node: Node3D = main.boats.build_model(info, Color.html(str(paints[i % paints.size()])), false)
		_root.add_child(node)
		node.global_position = Vector3(float(m[0]), float(world.water_level_at(float(m[0]), float(m[1]))), float(m[1]))
		node.rotation.y = float(m[2])
		_boats.append({"node": node, "home": node.global_position, "t": _rng.randf() * 6.0, "sail": false})
	# and three out working: out of the harbour and back again, over and over
	for i in 3:
		var info: Dictionary = Boats.boat_info(["trawler", "skiff", "dinghy"][i])
		var node: Node3D = main.boats.build_model(info, Color.html(str(paints[(i + 3) % paints.size()])), false)
		_root.add_child(node)
		var skipper := _person("Skipper %s" % LAST[(i * 7) % LAST.size()], Vector3(480, 0, 570), "boat")
		if not skipper.is_empty():
			(skipper.node as Node3D).reparent(node, false)
			(skipper.node as Node3D).position = Vector3(0.0, 0.45, 0.4)
			_people.erase(skipper)
		var lane_z := 565.0 + i * 14.0
		_boats.append({"node": node, "sail": true, "a": Vector3(486.0, 0.0, lane_z), "b": Vector3(560.0 + i * 25.0, 0.0, lane_z - 20.0 + i * 15.0),
			"t": i * 40.0, "period": 150.0 + i * 30.0})


func _step_boat(b: Dictionary, delta: float) -> void:
	var n: Node3D = b.node
	b.t = float(b.t) + delta
	if not bool(b.sail):
		var h: Vector3 = b.home
		n.global_position.y = float(world.water_level_at(h.x, h.z)) + sin(float(b.t) * 1.1) * 0.05
		n.rotation.z = sin(float(b.t) * 0.8) * 0.04
		return
	var period := float(b.period)
	var k := fmod(float(b.t), period) / period
	var a: Vector3 = b.a
	var c: Vector3 = b.b
	var go := k < 0.5
	var u := k * 2.0 if go else (k - 0.5) * 2.0
	u = u * u * (3.0 - 2.0 * u)
	var p := a.lerp(c, u) if go else c.lerp(a, u)
	var side := (c - a).cross(Vector3.UP).normalized() * (2.5 if go else -2.5)
	p += side * sin(u * PI)
	if not world.is_water(p.x, p.z):
		return
	var dir := (c - a).normalized() * (1.0 if go else -1.0)
	n.global_position = Vector3(p.x, float(world.water_level_at(p.x, p.z)), p.z)
	n.rotation.y = atan2(-dir.x, -dir.z)
	n.rotation.z = sin(float(b.t) * 1.2) * 0.05
