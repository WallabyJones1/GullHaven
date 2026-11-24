extends RefCounted
## Builds the towns from world.json: buildings (facing any of four ways, with signs,
## awnings, chimneys, a windmill), docks on posts, stone quays, street lamps, the
## lighthouse, the river bridge, props, townsfolk and cats, and your fishing hut.
## Placeholder shapes use the web game's pixel textures; a Blender export dropped into
## res://models/ (house.glb, lighthouse.glb, dock.glb, stall.glb, lamp.glb) replaces them.

const Billboard := preload("res://scripts/billboard.gd")

const SIGN_FONT := "res://art/fonts/pixelify_sans_bold.woff2"
# door direction (0 east, 1 south, 2 west, 3 north) -> rotation about Y for a front on local +Z
const ROT := [PI * 0.5, 0.0, -PI * 0.5, PI]

var world: Node3D
var _mats := {}
var _sign_font: Font


func _init(w: Node3D) -> void:
	world = w
	_sign_font = load(SIGN_FONT)


# --- towns -------------------------------------------------------------------

func build_town(t: Dictionary) -> void:
	var root := Node3D.new()
	root.name = str(t.id)
	world.add_child(root)
	var y := float(t.h)
	for b in t.buildings:
		building(root, b, t)
	for q in t.get("quays", []):
		quay(root, q, y)
	for dk in t.get("docks", []):
		dock(root, dk, y)
	for l in t.get("lamps", []):
		lamp(root, Vector3(float(l[0]), world.height_at(float(l[0]), float(l[1])), float(l[1])))
	for p in t.get("props", []):
		prop(root, str(p[0]), Vector3(float(p[1]), world.height_at(float(p[1]), float(p[2])), float(p[2])))
	if t.has("lighthouse"):
		lighthouse(root, Vector3(float(t.lighthouse.x), y, float(t.lighthouse.z)))
	for person in t.get("people", []):
		folk(root, person, t)
	# a few cats about town
	var coats := ["ginger", "black", "tabby", "calico", "tux", "siamese", "grey", "cream", "tortie", "bicolor"]
	var n := 4 if t.id == "gullhaven" else (2 if t.id == "willowford" else 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(t.id))
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, float(t.r) * 0.6)
		var pos := Vector3(float(t.x) + cos(a) * r, 0.0, float(t.z) + sin(a) * r)
		if world.is_water(pos.x, pos.z):
			continue
		pos.y = world.height_at(pos.x, pos.z)
		cat(root, coats[rng.randi() % coats.size()], pos)


func building(parent: Node3D, b: Dictionary, t: Dictionary) -> void:
	var size := Vector3(float(b.w), float(b.h), float(b.d))
	var y := float(b.get("y", t.h))
	var rot: float = ROT[int(b.rot)]
	var pivot := StaticBody3D.new()
	pivot.position = Vector3(float(b.x), y, float(b.z))
	pivot.rotation.y = rot
	parent.add_child(pivot)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y + 2.0, size.z)
	col.shape = shape
	col.position.y = (size.y + 2.0) * 0.5
	pivot.add_child(col)
	var kind := str(b.kind)
	# where you stand to go in: just outside the door
	var door := pivot.global_transform * Vector3(0.0, 0.0, size.z * 0.5 + 0.9)
	world.buildings.append({"name": str(b.name), "kind": kind, "role": str(b.role), "town": str(t.id), "door": door,
		"rot": rot, "size": size, "node": pivot, "y": y})
	if kind == "house" and _use_model("house", pivot):
		return
	if kind == "mill":
		_mill(pivot, size, b)
		return
	var walls := _mesh_box(size, Vector3(0.0, size.y * 0.5, 0.0), _mat(str(b.wall)))
	walls.visibility_range_end = 260.0
	pivot.add_child(walls)
	var roof_h := 2.2 if kind != "museum" else 2.8
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z + 0.8, roof_h, size.x + 0.8)
	prism.material = _mat(str(b.roof))
	var roof := MeshInstance3D.new()
	roof.mesh = prism
	roof.position = Vector3(0.0, size.y + roof_h * 0.5, 0.0)
	roof.rotation.y = PI * 0.5
	roof.visibility_range_end = 260.0
	pivot.add_child(roof)
	if kind == "house" or kind == "tavern" or kind == "lodge":
		pivot.add_child(_mesh_box(Vector3(0.6, 1.4, 0.6), Vector3(size.x * 0.28, size.y + 1.6, -0.6), _mat("stone")))
	var front := size.z * 0.5 + 0.02
	pivot.add_child(_quad(Vector2(1.1, 1.9), Vector3(0.0, 0.95, front), _flat(Color(0.34, 0.21, 0.14))))
	# windows: more on bigger buildings, and a second row on tall ones
	var cols := maxi(1, int(size.x / 3.0))
	for i in cols:
		var wx := -size.x * 0.5 + (i + 0.5) * size.x / cols
		if absf(wx) < 1.0:
			continue
		pivot.add_child(_quad(Vector2(0.9, 0.9), Vector3(wx, size.y * 0.42 + 0.4, front), _window_mat()))
		if size.y > 4.0:
			pivot.add_child(_quad(Vector2(0.8, 0.8), Vector3(wx, size.y * 0.78, front), _window_mat()))
	# side windows so the town looks lived-in from every angle
	for side in [-1.0, 1.0]:
		var sx: float = side * (size.x * 0.5 + 0.02)
		var q := _quad(Vector2(0.8, 0.8), Vector3(sx, size.y * 0.5, 0.0), _window_mat())
		q.rotation.y = side * PI * 0.5
		pivot.add_child(q)
	if str(b.sign) != "":
		_sign(pivot, str(b.sign), Vector3(0.0, 2.35, front + 0.05))
		if kind == "shop":
			var awn := _mesh_box(Vector3(2.4, 0.08, 1.1), Vector3(0.0, 2.15, front + 0.5), _mat(str(b.roof)))
			awn.rotation.x = deg_to_rad(-14.0)
			pivot.add_child(awn)
	if kind == "tavern":
		for bx in [-1.3, 1.3]:
			pivot.add_child(_mesh_cylinder(0.32, 0.32, 0.9, Vector3(bx, 0.45, front + 0.5), _mat("timber")))
	if kind == "hall":
		pivot.add_child(_mesh_cylinder(0.06, 0.06, 6.0, Vector3(size.x * 0.5 - 0.5, 3.0, front + 1.0), _flat(Color(0.8, 0.8, 0.8))))
		var flag := _quad(Vector2(1.4, 0.9), Vector3(size.x * 0.5 + 0.25, 5.4, front + 1.0), _flat(Color(0.2, 0.4, 0.8)))
		pivot.add_child(flag)
	if kind == "museum":
		for cx in [-size.x * 0.35, -size.x * 0.12, size.x * 0.12, size.x * 0.35]:
			pivot.add_child(_mesh_cylinder(0.3, 0.3, size.y, Vector3(cx, size.y * 0.5, front + 0.6), _mat("plaster")))
	if kind == "lodge":
		pivot.add_child(_mesh_box(Vector3(size.x, 0.2, 2.0), Vector3(0.0, 0.1, front + 1.0), _mat("planks")))


func _mill(pivot: Node3D, size: Vector3, b: Dictionary) -> void:
	var tower := _mesh_cylinder(size.x * 0.32, size.x * 0.45, size.y, Vector3(0.0, size.y * 0.5, 0.0), _mat(str(b.wall)))
	pivot.add_child(tower)
	var cap := _mesh_cylinder(0.1, size.x * 0.4, 2.0, Vector3(0.0, size.y + 1.0, 0.0), _mat(str(b.roof)))
	pivot.add_child(cap)
	pivot.add_child(_quad(Vector2(1.1, 1.9), Vector3(0.0, 0.95, size.x * 0.45 + 0.02), _flat(Color(0.34, 0.21, 0.14))))
	_sign(pivot, str(b.sign), Vector3(0.0, 2.35, size.x * 0.45 + 0.1))
	var hub := Node3D.new()
	hub.position = Vector3(0.0, size.y - 0.6, size.x * 0.4 + 0.4)
	pivot.add_child(hub)
	for i in 4:
		var blade := _mesh_box(Vector3(0.6, 5.0, 0.08), Vector3(0.0, 2.5, 0.0), _mat("planks"))
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		arm.add_child(blade)
		hub.add_child(arm)
	world.spinners.append(hub)


func _sign(parent: Node3D, text: String, at: Vector3) -> void:
	var board := _mesh_box(Vector3(text.length() * 0.24 + 0.6, 0.5, 0.06), at, _flat(Color(0.95, 0.9, 0.78)))
	parent.add_child(board)
	var l := Label3D.new()
	l.text = text
	l.font = _sign_font
	l.font_size = 40
	l.pixel_size = 0.0075
	l.modulate = Color(0.28, 0.18, 0.12)
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = at + Vector3(0.0, 0.0, 0.04)
	l.visibility_range_end = 80.0
	parent.add_child(l)


func quay(parent: Node3D, q: Dictionary, y: float) -> void:
	var x0 := float(q.x0)
	var x1 := float(q.x1)
	var z0 := float(q.z0)
	var z1 := float(q.z1)
	var depth := 3.2
	_box(parent, Vector3(x1 - x0, y + depth, z1 - z0), Vector3((x0 + x1) * 0.5, (y - depth) * 0.5, (z0 + z1) * 0.5), _mat("stone"))


func dock(parent: Node3D, dk: Dictionary, y: float) -> void:
	var r: Array = dk.rect
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var top := y - 0.1
	var centre := Vector3((x0 + x1) * 0.5, top - 0.1, (z0 + z1) * 0.5)
	var size := Vector3(x1 - x0, 0.2, z1 - z0)
	if not _use_model("dock", null, centre):
		_box(parent, size, centre, _mat("planks"))
		var long_x := size.x > size.z
		var n := int(maxf(size.x, size.z) / 3.5) + 1
		for i in n + 1:
			var t := float(i) / n
			for s in [-0.42, 0.42]:
				var side: float = s
				var px: float = lerpf(x0, x1, t) if long_x else centre.x + side * size.x
				var pz: float = centre.z + side * size.z if long_x else lerpf(z0, z1, t)
				_cylinder(parent, 0.11, 3.4, Vector3(px, top - 1.7, pz), _mat("timber"))
	else:
		_box(parent, size, centre, null)
	world.docks.append({"rect": Rect2(x0, z0, x1 - x0, z1 - z0), "y": top, "moor": dk.get("moor", null)})


func lamp(parent: Node3D, at: Vector3) -> void:
	if not _use_model("lamp", null, at):
		var iron := _flat(Color(0.18, 0.17, 0.22))
		parent.add_child(_mesh_cylinder(0.06, 0.06, 2.6, at + Vector3(0.0, 1.3, 0.0), iron))
		parent.add_child(_mesh_box(Vector3(0.34, 0.4, 0.34), at + Vector3(0.0, 2.75, 0.0), _window_mat(4.0)))
	var light := OmniLight3D.new()
	light.position = at + Vector3(0.0, 2.7, 0.0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 20.0
	light.shadow_enabled = false
	parent.add_child(light)
	world.lamps.append(light)


func lighthouse(parent: Node3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.8
	shape.height = 12.0
	col.shape = shape
	col.position.y = 6.0
	body.add_child(col)
	world.buildings.append({"name": "Lighthouse", "kind": "lighthouse", "role": "lighthouse", "town": "gullhaven",
		"door": at + Vector3(-2.4, 0.0, 0.0), "rot": -PI * 0.5, "size": Vector3(3.4, 9.0, 3.4), "node": body, "y": at.y})
	if not _use_model("lighthouse", body, Vector3.ZERO):
		var white := _mat("plaster")
		var red := _flat(Color(0.78, 0.26, 0.22))
		body.add_child(_mesh_cylinder(1.25, 1.7, 9.0, Vector3(0.0, 4.5, 0.0), white))
		body.add_child(_mesh_cylinder(1.48, 1.55, 1.2, Vector3(0.0, 5.2, 0.0), red))
		body.add_child(_mesh_cylinder(1.75, 1.75, 0.3, Vector3(0.0, 9.15, 0.0), _mat("stone")))
		body.add_child(_mesh_cylinder(0.95, 0.95, 1.3, Vector3(0.0, 9.95, 0.0), _window_mat(5.0)))
		body.add_child(_mesh_cylinder(0.08, 1.25, 1.1, Vector3(0.0, 11.15, 0.0), red))
		var door := _quad(Vector2(1.0, 1.9), Vector3(-1.62, 0.95, 0.0), _flat(Color(0.34, 0.21, 0.14)))
		door.rotation.y = -PI * 0.5
		body.add_child(door)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0.0, 10.0, 0.0)
	light.light_color = Color(1.0, 0.86, 0.55)
	light.omni_range = 16.0
	parent.add_child(light)
	world.lamps.append(light)
	world.beam = SpotLight3D.new()
	world.beam.position = at + Vector3(0.0, 10.0, 0.0)
	world.beam.light_color = Color(1.0, 0.92, 0.7)
	world.beam.spot_range = 70.0
	world.beam.spot_angle = 9.0
	world.beam.light_volumetric_fog_energy = 4.0
	parent.add_child(world.beam)


func prop(parent: Node3D, kind: String, at: Vector3) -> void:
	match kind:
		"crates":
			for o in [Vector3(0.0, 0.35, 0.0), Vector3(0.75, 0.35, 0.1), Vector3(0.35, 1.05, 0.05)]:
				_box(parent, Vector3(0.7, 0.7, 0.7), at + o, _mat("planks"))
		"barrels":
			for o in [Vector3(0.0, 0.45, 0.0), Vector3(0.7, 0.45, -0.3)]:
				_cylinder(parent, 0.33, 0.9, at + o, _mat("timber"))
		"nets":
			var n := _mesh_box(Vector3(1.6, 0.25, 1.2), at + Vector3(0.0, 0.12, 0.0), _flat(Color(0.3, 0.45, 0.4)))
			parent.add_child(n)
		"stall":
			if _use_model("stall", null, at):
				return
			_box(parent, Vector3(3.2, 1.0, 1.2), at + Vector3(0.0, 0.5, 0.0), _mat("timber"))
			for x in [-1.5, 1.5]:
				parent.add_child(_mesh_cylinder(0.07, 0.07, 2.4, at + Vector3(x, 1.2, -0.5), _mat("timber")))
				parent.add_child(_mesh_cylinder(0.07, 0.07, 2.0, at + Vector3(x, 1.0, 0.6), _mat("timber")))
			var awning := _mesh_box(Vector3(3.6, 0.1, 1.9), at + Vector3(0.0, 2.3, 0.05), _mat("roof_red"))
			awning.rotation.x = deg_to_rad(-12.0)
			parent.add_child(awning)


func folk(parent: Node3D, p: Dictionary, t: Dictionary) -> void:
	var path := "res://art/chars2/%s.png" % str(p.sheet)
	if not ResourceLoader.exists(path):
		path = "res://art/chars2/villager_a.png"
	var s := Billboard.sprite(load(path), 1.0 / 26.0, 5, 4, 46.0)
	var pos := Vector3(float(p.x), 0.0, float(p.z))
	pos.y = world.stand_height(pos.x, pos.z)
	s.position = pos
	parent.add_child(s)
	var who := str(p.name)
	if world.folk.has(who):
		who = "%s of %s" % [who, str(t.name)]
	world.folk[who] = {"node": s, "home": pos, "role": str(p.role), "town": str(t.id), "town_name": str(t.name),
		"inside": str(p.get("inside", ""))}
	world.walkers.append({"node": s, "home": pos, "kind": "folk", "dir": Vector3.BACK, "t": randf() * 4.0})


func cat(parent: Node3D, coat: String, pos: Vector3) -> void:
	var path := "res://art/cats2/%s.png" % coat
	if not ResourceLoader.exists(path):
		return
	var c := Billboard.sprite(load(path), 1.0 / 40.0, 5, 4, 29.0)
	c.position = pos
	parent.add_child(c)
	world.cats.append(c)
	world.walkers.append({"node": c, "home": pos, "kind": "cat", "dir": Vector3.BACK, "t": randf() * 3.0, "target": pos, "rest": ""})


## The bridge over the river mouth. Broken, it has a gap in the middle you can't cross.
func bridge(b: Dictionary, repaired: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridge"
	world.add_child(root)
	var x := float(b.x)
	var z := float(b.z)
	var length := float(b.length)
	var deck_y := 1.6
	var z0 := z - length * 0.5
	var segs := 9
	for i in segs:
		var gap := not repaired and (i == segs / 2 or i == segs / 2 + 1)
		if gap:
			continue
		var cz := z0 + (i + 0.5) * length / segs
		_box(root, Vector3(3.2, 0.25, length / segs + 0.02), Vector3(x, deck_y, cz), _mat("planks"))
		if i % 2 == 0:
			for s in [-1.4, 1.4]:
				_cylinder(root, 0.14, 4.0, Vector3(x + s, deck_y - 2.0, cz), _mat("timber"))
	# ramps up from the banks
	for end in [-1.0, 1.0]:
		var ez: float = z + end * (length * 0.5 + 2.5)
		var ramp := _box(root, Vector3(3.2, 0.25, 5.4), Vector3(x, deck_y - 0.45, ez), _mat("planks"))
		ramp.rotation.x = end * deg_to_rad(10.0)
	# rails
	for s in [-1.55, 1.55]:
		if repaired:
			root.add_child(_mesh_box(Vector3(0.1, 0.1, length), Vector3(x + s, deck_y + 0.9, z), _mat("timber")))
	if not repaired:
		_sign(root, "BRIDGE OUT", Vector3(x, deck_y + 1.2, z0 + 3.0))
	return root


## Your fishing hut on the beach: a tumbledown shack to start with, and its jetty.
func hut(h: Dictionary, tier: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Hut"
	world.add_child(root)
	var y := float(h.y)
	var pos := Vector3(float(h.x), y, float(h.z))
	var sizes := [Vector3(4.0, 2.6, 3.6), Vector3(5.5, 3.0, 4.5), Vector3(7.0, 3.4, 5.5), Vector3(9.0, 4.2, 6.5)]
	var walls := ["planks", "timber", "plaster", "stone"]
	var roofs := ["roof_red", "roof_blue", "roof_green", "roof_red"]
	var t := clampi(tier, 0, 3)
	var b := {"kind": "hut", "x": pos.x, "z": pos.z, "y": y, "w": sizes[t].x, "h": sizes[t].y, "d": sizes[t].z, "rot": int(h.rot),
		"wall": walls[t], "roof": roofs[t], "name": "Your Hut", "sign": "", "role": "hut"}
	building(root, b, {"id": "hut", "h": y})
	var j: Dictionary = h.jetty
	dock(root, {"rect": j.rect, "moor": [float(j.x) + float(j.w) + 2.0, float(j.z) + 3.0]}, y)
	lamp(root, pos + Vector3(sizes[t].x * 0.5 + 1.0, 0.0, 2.0))
	return root


# --- helpers -------------------------------------------------------------------

func _use_model(slot: String, parent: Node3D, at := Vector3.ZERO) -> bool:
	var path := "res://models/%s.glb" % slot
	if not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Node3D
	if parent:
		parent.add_child(inst)
	else:
		inst.position = at
		world.add_child(inst)
	return true


func _mat(tex_name: String) -> StandardMaterial3D:
	if _mats.has(tex_name):
		return _mats[tex_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/tex/%s.png" % tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = 0.92
	_mats[tex_name] = m
	return m


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


## Glass that glows warmly at night (DayNight drives the glow).
func _window_mat(strength := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.27, 0.36)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.74, 0.4)
	m.emission_energy_multiplier = 0.0
	m.set_meta("glow", strength)
	world.glow_mats.append(m)
	return m


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi


## A box with a collider. A null material makes an invisible collider (for models).
func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	if mat:
		var mi := _mesh_box(size, Vector3.ZERO, mat)
		mi.visibility_range_end = 220.0
		body.add_child(mi)
	parent.add_child(body)
	return body


func _mesh_cylinder(top: float, bottom: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.visibility_range_end = 220.0
	return mi


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	body.add_child(_mesh_cylinder(radius, radius, height, Vector3.ZERO, mat))
	parent.add_child(body)


func _quad(size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.visibility_range_end = 160.0
	return mi
