extends Node3D
## Builds the Phase 0 harbour diorama: quay, beach, dock, houses, lighthouse, lamps,
## trees, a moored boat, townsfolk and cats, over a shader-driven sea.
##
## Placeholder shapes stand in for the real models. Drop a Blender export into
## res://models/ with a slot name (house.glb, lighthouse.glb, dock.glb, boat.glb,
## stall.glb, lamp.glb, tree.glb) and it replaces the placeholder automatically.
##
## World layout: +X is east, -Z is north (into the screen). Land is to the north,
## the sea is to the south, toward the camera. 16 texture pixels = 1 metre.

const PIXEL := 1.0 / 16.0
const LAND_TOP := 0.6

var spawn_point := Vector3(0.0, LAND_TOP + 0.1, -2.5)
var sea_level := 0.0  # moves with the tide (DayNight sets it)
var stall_point := Vector3(10.0, LAND_TOP, -3.4)  # where you stand to shop
var folk := {}  # name -> {node: Sprite3D, home: Vector3}
var cats: Array[Sprite3D] = []
var _sea: MeshInstance3D
var water_material: ShaderMaterial
var lamps: Array[OmniLight3D] = []
var glow_mats: Array[StandardMaterial3D] = []
var beam: SpotLight3D
var boat: Node3D
var _mats := {}
var _walkers := []  # cats and townsfolk that wander a little
# Things standing in the water (x, z rectangles): the dock, its T-end and the rowboat.
var _solid: Array[Rect2] = [Rect2(1.9, 0.0, 3.2, 14.1), Rect2(0.4, 11.6, 6.2, 2.8), Rect2(5.8, 5.0, 1.6, 3.7)]
var _t := 0.0


func build() -> void:
	_build_sea()
	_build_land()
	_build_dock()
	_build_town()
	_build_lighthouse()
	_build_lamps()
	_build_scenery()
	_build_boat()
	_build_people()


func _process(delta: float) -> void:
	_t += delta
	if _sea:
		_sea.position.y = sea_level
	if boat:
		boat.position.y = sin(_t * 1.4) * 0.05 - 0.05
		boat.rotation.z = sin(_t * 1.1) * 0.03
		boat.rotation.x = sin(_t * 0.9 + 1.0) * 0.02
	for w in _walkers:
		_update_walker(w, delta)


## True when (x, z) is open water: not the town, the beach, the dock or the boat.
## Worked out from the layout rather than physics so it is cheap and safe to call
## from anywhere, any frame.
func is_water(x: float, z: float) -> bool:
	if x < -36.0 or x > 40.0 or z < -34.0 or z > 45.0:
		return false
	if z < 0.2 and x > -12.0 and x < 34.0:
		return false  # the town block and its quay
	if x <= -12.0 and beach_y(z) > sea_level - 0.05:
		return false  # the beach, above the waterline (it moves with the tide)
	for r in _solid:
		if r.has_point(Vector2(x, z)):
			return false
	return true


## How deep the water is at (x, z); 0 on land.
func water_depth(x: float, z: float) -> float:
	if not is_water(x, z):
		return 0.0
	if x <= -12.0 and z < 6.1:
		return sea_level - beach_y(z)
	return sea_level + 2.4


## The two fishing grounds: the beach side is the Sandy Shallows.
func zone_at(x: float, _z: float) -> String:
	return "shallows" if x < -12.0 else "harbour"


## What's underfoot, for footstep sounds: wood, sand, stone or grass.
func surface_at(x: float, z: float) -> String:
	for r in _solid:
		if r.has_point(Vector2(x, z)):
			return "wood"
	if x <= -12.0 and z > -4.2:
		return "sand"
	if x > -12.0 and x < 34.0 and z > -3.95:
		return "stone"
	if (absf(x - 1.0) < 1.5 and z > -11.0) or (absf(z + 10.5) < 1.1 and x > -10.0 and x < 20.0):
		return "sand"
	return "grass"


## Height of the beach surface at z (it slopes from the grass down under the sea).
func beach_y(z: float) -> float:
	return clampf(LAND_TOP - (z + 4.0) * 0.12, -0.6, LAND_TOP)


# --- the sea ---------------------------------------------------------------------

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 160.0)
	plane.subdivide_width = 100
	plane.subdivide_depth = 80
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	plane.material = water_material
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3(0.0, 0.0, 10.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	_sea = sea
	# The seabed shows through the shallows and darkens with depth.
	_box(Vector3(200.0, 0.4, 160.0), Vector3(0.0, -2.6, 10.0), _mat("seabed"), false)


# --- land: a stone quay with grass on top, and a sandy beach to the west ----------

func _build_land() -> void:
	var stone := _mat("stone")
	var grass := _mat("grass")
	# The town block: stone walls dropping into the sea, a grass cap on top.
	_box(Vector3(46.0, 3.0, 34.0), Vector3(11.0, LAND_TOP - 1.5, -17.0), stone)
	_box(Vector3(45.6, 0.12, 33.0), Vector3(11.0, LAND_TOP - 0.05, -17.5), grass, false)
	# The western block behind the beach.
	_box(Vector3(24.0, 3.0, 30.0), Vector3(-24.0, LAND_TOP - 1.5, -19.0), stone)
	_box(Vector3(24.0, 0.12, 30.0), Vector3(-24.0, LAND_TOP - 0.05, -19.0), grass, false)
	# The beach: a sand ramp from the grass edge (z = -4) down under the sea (z = 6),
	# matching beach_y().
	var ramp := _box(Vector3(24.0, 0.6, 10.2), Vector3(-24.0, -0.3, 1.0), _mat("sand"))
	ramp.rotation.x = atan(0.12)
	# A cobbled street along the quay and a dirt lane up to the houses.
	_box(Vector3(46.0, 0.06, 3.0), Vector3(11.0, LAND_TOP - 0.01, -2.4), _mat("cobble"), false)
	_box(Vector3(3.0, 0.06, 7.0), Vector3(1.0, LAND_TOP - 0.01, -7.4), _mat("path"), false)
	_box(Vector3(30.0, 0.06, 2.2), Vector3(5.0, LAND_TOP - 0.01, -10.5), _mat("path"), false)


# --- the dock: planks on posts, reaching out into the harbour --------------------

func _build_dock() -> void:
	if _use_model("dock", Vector3(3.5, 0.0, 6.0)):
		return
	var planks := _mat("planks")
	_box(Vector3(3.0, 0.2, 14.0), Vector3(3.5, 0.45, 7.0), planks)
	_box(Vector3(6.0, 0.2, 2.6), Vector3(3.5, 0.45, 13.0), planks)  # the T at the end
	var timber := _mat("timber")
	for z in [1.5, 5.0, 8.5, 12.0, 14.0]:
		for x in [2.15, 4.85]:
			_cylinder(0.12, 3.2, Vector3(x, -1.1, z), timber)
	for x in [0.7, 6.3]:
		_cylinder(0.12, 3.2, Vector3(x, -1.1, 13.9), timber)


# --- houses along the lane ---------------------------------------------------------

func _build_town() -> void:
	var specs := [
		[Vector3(-26.0, 0.0, -14.0), Vector3(6.0, 3.0, 5.0), "plaster", "roof_red"],
		[Vector3(-16.0, 0.0, -15.0), Vector3(5.0, 3.4, 5.0), "timber", "roof_blue"],
		[Vector3(-6.0, 0.0, -14.5), Vector3(6.5, 3.2, 5.5), "plaster", "roof_green"],
		[Vector3(9.0, 0.0, -15.5), Vector3(7.0, 3.6, 5.5), "stone", "roof_red"],
		[Vector3(19.0, 0.0, -14.5), Vector3(5.5, 3.0, 5.0), "plaster", "roof_blue"],
		[Vector3(27.0, 0.0, -16.0), Vector3(5.0, 3.2, 5.0), "timber", "roof_red"],
	]
	for s in specs:
		_house(s[0], s[1], s[2], s[3])
	_stall(Vector3(10.0, LAND_TOP, -4.6))


func _house(base: Vector3, size: Vector3, wall: String, roof: String) -> void:
	var at := Vector3(base.x, LAND_TOP, base.z)
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y + 2.0, size.z)
	col.shape = shape
	col.position.y = (size.y + 2.0) * 0.5
	body.add_child(col)
	if _use_model("house", at, body):
		return
	var walls := _mesh_box(size, Vector3(0.0, size.y * 0.5, 0.0), _mat(wall))
	body.add_child(walls)
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z + 0.8, 2.2, size.x + 0.8)
	prism.material = _mat(roof)
	var roof_mesh := MeshInstance3D.new()
	roof_mesh.mesh = prism
	roof_mesh.position = Vector3(0.0, size.y + 1.1, 0.0)
	roof_mesh.rotation.y = PI * 0.5
	body.add_child(roof_mesh)
	body.add_child(_mesh_box(Vector3(0.6, 1.4, 0.6), Vector3(size.x * 0.28, size.y + 1.6, -0.6), _mat("stone")))
	# A door and lit windows facing the street (and the camera).
	var front := size.z * 0.5 + 0.02
	body.add_child(_quad(Vector2(1.0, 1.8), Vector3(0.0, 0.9, front), _flat(Color(0.32, 0.2, 0.14))))
	for wx in [-size.x * 0.3, size.x * 0.3]:
		body.add_child(_quad(Vector2(0.9, 0.9), Vector3(wx, size.y * 0.58, front), _window_mat()))


func _stall(at: Vector3) -> void:
	if _use_model("stall", at):
		return
	var timber := _mat("timber")
	_box(Vector3(3.2, 1.0, 1.2), at + Vector3(0.0, 0.5, 0.0), timber)
	for x in [-1.5, 1.5]:
		_cylinder(0.07, 2.4, at + Vector3(x, 1.2, -0.5), timber, false)
		_cylinder(0.07, 2.0, at + Vector3(x, 1.0, 0.6), timber, false)
	var awning := _mesh_box(Vector3(3.6, 0.1, 1.9), at + Vector3(0.0, 2.3, 0.05), _mat("roof_red"))
	awning.rotation.x = deg_to_rad(-12.0)
	add_child(awning)


# --- the lighthouse on the eastern point ----------------------------------------

func _build_lighthouse() -> void:
	var at := Vector3(31.0, LAND_TOP, -4.0)
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.8
	shape.height = 12.0
	col.shape = shape
	col.position.y = 6.0
	body.add_child(col)
	if not _use_model("lighthouse", at, body):
		var white := _mat("plaster")
		var red := _flat(Color(0.78, 0.26, 0.22))
		body.add_child(_mesh_cylinder(1.25, 1.7, 9.0, Vector3(0.0, 4.5, 0.0), white))
		body.add_child(_mesh_cylinder(1.48, 1.55, 1.2, Vector3(0.0, 5.2, 0.0), red))
		body.add_child(_mesh_cylinder(1.75, 1.75, 0.3, Vector3(0.0, 9.15, 0.0), _mat("stone")))
		var glass := _window_mat(5.0)
		body.add_child(_mesh_cylinder(0.95, 0.95, 1.3, Vector3(0.0, 9.95, 0.0), glass))
		body.add_child(_mesh_cylinder(0.08, 1.25, 1.1, Vector3(0.0, 11.15, 0.0), red))
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0.0, 10.0, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.55)
	lamp.omni_range = 16.0
	add_child(lamp)
	lamps.append(lamp)
	beam = SpotLight3D.new()
	beam.position = at + Vector3(0.0, 10.0, 0.0)
	beam.light_color = Color(1.0, 0.92, 0.7)
	beam.spot_range = 60.0
	beam.spot_angle = 9.0
	beam.light_volumetric_fog_energy = 4.0
	add_child(beam)


# --- street lamps ------------------------------------------------------------------

func _build_lamps() -> void:
	for x in [-9.0, 1.5, 14.0, 25.0]:
		_lamp(Vector3(x, LAND_TOP, -0.9))
	_lamp(Vector3(-20.0, LAND_TOP, -4.8))  # at the top of the beach
	_lamp(Vector3(5.8, 0.55, 13.9))
	_lamp(Vector3(-4.0, LAND_TOP, -11.0))
	_lamp(Vector3(14.0, LAND_TOP, -11.0))


func _lamp(at: Vector3) -> void:
	if not _use_model("lamp", at):
		var iron := _flat(Color(0.18, 0.17, 0.22))
		_cylinder(0.06, 2.6, at + Vector3(0.0, 1.3, 0.0), iron, false)
		add_child(_mesh_box(Vector3(0.34, 0.4, 0.34), at + Vector3(0.0, 2.75, 0.0), _window_mat(4.0)))
	var light := OmniLight3D.new()
	light.position = at + Vector3(0.0, 2.7, 0.0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = lamps.size() < 4
	add_child(light)
	lamps.append(light)


# --- trees, bushes, crates and barrels (pixel sprites and small props) -------------

func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var tree_tex := []
	for i in 5:
		tree_tex.append(load("res://art/props/tree%d.png" % i))
	var use_tree_model := ResourceLoader.exists("res://models/tree.glb")
	var spots := 0
	while spots < 46:
		var x := rng.randf_range(-34.0, 33.0)
		var z := rng.randf_range(-33.0, -20.0)
		if absf(x - 1.0) < 2.5:
			continue
		spots += 1
		var at := Vector3(x, LAND_TOP, z)
		if use_tree_model:
			_use_model("tree", at)
		else:
			var weights := [0, 0, 0, 3, 3, 4, 1, 2]
			var tree := _sprite(tree_tex[weights[rng.randi() % weights.size()]], at)
			tree.pixel_size = PIXEL * 1.5  # trees tower over the townsfolk
	for i in 14:
		var x := rng.randf_range(-30.0, 30.0)
		_sprite(load("res://art/props/bush_flower.png" if i % 3 == 0 else "res://art/props/bush.png"), Vector3(x, LAND_TOP, rng.randf_range(-9.2, -8.2)))
	for i in 6:
		var rz := rng.randf_range(-4.0, -2.5)
		_sprite(load("res://art/props/reeds.png"), Vector3(rng.randf_range(-33.0, -14.0), beach_y(rz), rz))
	# Fish crates and barrels by the dock.
	var planks := _mat("planks")
	for p in [Vector3(6.2, LAND_TOP, -1.4), Vector3(6.9, LAND_TOP, -1.5), Vector3(6.5, LAND_TOP + 0.7, -1.45)]:
		_box(Vector3(0.7, 0.7, 0.7), p + Vector3(0.0, 0.35, 0.0), planks)
	for p in [Vector3(-0.6, LAND_TOP, -1.3), Vector3(0.1, LAND_TOP, -1.6)]:
		_cylinder(0.33, 0.9, p + Vector3(0.0, 0.45, 0.0), _mat("timber"))


func _build_boat() -> void:
	boat = Node3D.new()
	boat.name = "Rowboat"
	var holder := Node3D.new()
	holder.position = Vector3(6.6, 0.0, 7.0)
	add_child(holder)
	holder.add_child(boat)
	if ResourceLoader.exists("res://models/boat.glb"):
		var model: PackedScene = load("res://models/boat.glb")
		boat.add_child(model.instantiate())
		return
	var hull := _mat("planks")
	boat.add_child(_mesh_box(Vector3(1.4, 0.5, 3.0), Vector3(0.0, 0.15, 0.0), hull))
	var bow := PrismMesh.new()
	bow.size = Vector3(1.4, 0.9, 0.5)
	bow.material = hull
	var bow_mesh := MeshInstance3D.new()
	bow_mesh.mesh = bow
	bow_mesh.position = Vector3(0.0, 0.15, -1.7)
	bow_mesh.rotation = Vector3(-PI * 0.5, 0.0, 0.0)  # point the prism forward (north)
	boat.add_child(bow_mesh)
	boat.add_child(_mesh_box(Vector3(1.2, 0.08, 0.3), Vector3(0.0, 0.42, 0.3), _mat("timber")))


func _build_people() -> void:
	# name, sprite sheet, where they stand, which way they face
	var people := [
		["Juniper", "folk0", Vector3(-4.0, LAND_TOP, -9.6), 0],
		["Hale", "folk2", Vector3(12.0, LAND_TOP, -3.6), 0],
		["Old Marlo", "folk4", Vector3(4.6, 0.55, 12.4), 2],
		["Pip", "folk6", Vector3(-20.0, beach_y(-2.0), -2.0), 3],
	]
	for f in people:
		var s := _sprite(load("res://art/chars/%s.png" % f[1]), f[2], 3, 4)
		s.frame = f[3] * 3
		folk[f[0]] = {"node": s, "home": f[2]}
		_walkers.append({"node": s, "home": f[2], "kind": "folk", "row": f[3], "t": randf() * 4.0, "frames": 3})
	var coats := ["ginger", "black", "tabby", "calico"]
	var cat_spots := [Vector3(8.6, LAND_TOP, -3.4), Vector3(-2.0, LAND_TOP, -2.0), Vector3(3.5, 0.55, 4.0), Vector3(-12.0, LAND_TOP, -10.0)]
	for i in coats.size():
		var path: String = "res://art/cats/%s.png" % coats[i]
		if not ResourceLoader.exists(path):
			continue
		var c := _sprite(load(path), cat_spots[i], 2, 4)
		c.pixel_size = PIXEL * 0.75
		cats.append(c)
		_walkers.append({"node": c, "home": cat_spots[i], "kind": "cat", "row": 0, "t": randf() * 3.0, "frames": 2, "target": cat_spots[i]})


## Turn a townsperson to face a point (someone talking to them) for a few seconds.
func folk_face(who: String, toward: Vector3) -> void:
	if not folk.has(who):
		return
	var node: Sprite3D = folk[who].node
	for w in _walkers:
		if w.node == node:
			var d := toward - node.position
			if absf(d.x) > absf(d.z):
				w.row = 2 if d.x < 0.0 else 3
			else:
				w.row = 1 if d.z < 0.0 else 0
			w.t = 4.0
			node.frame = int(w.row) * 3


func _update_walker(w: Dictionary, delta: float) -> void:
	var s: Sprite3D = w.node
	w.t -= delta
	if w.kind == "folk":
		# Townsfolk stand about and glance around now and then.
		if w.t <= 0.0:
			w.t = randf_range(2.0, 5.0)
			w.row = [0, 0, 2, 3][randi() % 4]
		s.frame = int(w.row) * 3
		return
	# Cats potter between spots near home.
	var target: Vector3 = w.target
	var to := target - s.position
	to.y = 0.0
	if to.length() < 0.1 or w.t <= 0.0:
		if w.t <= 0.0:
			w.t = randf_range(2.5, 6.0)
			var home: Vector3 = w.home
			var cand := home + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-1.5, 1.5))
			w.target = cand if not is_water(cand.x, cand.z) else home
		s.frame = 0
		return
	var step := to.normalized() * minf(to.length(), 0.9 * delta)
	s.position += step
	# Cat sheets run down, left, right, up (one row each, two walk frames).
	var row := 0
	if absf(step.x) >= absf(step.z):
		row = 1 if step.x < 0.0 else 2
	else:
		row = 3 if step.z < 0.0 else 0
	s.frame = row * 2 + (int(_t * 6.0) % 2)


# --- helpers -------------------------------------------------------------------

## Instances res://models/<slot>.glb at the given position if it exists.
func _use_model(slot: String, at: Vector3, parent: Node3D = null) -> bool:
	var path := "res://models/%s.glb" % slot
	if not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = load(path)
	var inst := scene.instantiate() as Node3D
	if parent:
		parent.add_child(inst)
	else:
		inst.position = at
		add_child(inst)
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
	glow_mats.append(m)
	return m


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi


## A box with a collider (land, dock planks, crates).
func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := _mesh_box(size, Vector3.ZERO, mat)
	if not collide:
		mi.position = pos
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	add_child(body)
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
	return mi


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material, collide := true) -> void:
	var mi := _mesh_cylinder(radius, radius, height, Vector3.ZERO, mat)
	if not collide:
		mi.position = pos
		add_child(mi)
		return
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	add_child(body)


func _quad(size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi


## A pixel-art billboard standing on the ground at `at` (feet at the bottom edge).
func _sprite(tex: Texture2D, at: Vector3, hframes := 1, vframes := 1) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = hframes
	s.vframes = vframes
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.offset = Vector2(0.0, tex.get_height() / float(vframes) * 0.5)
	s.position = at
	add_child(s)
	return s
