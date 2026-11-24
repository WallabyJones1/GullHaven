extends Node3D
## The world: 1280 x 1024 m of coast, sea, river, lake and islands, loaded from
## res://world/ (made by tools/godot_world.py). Streams terrain around the player in
## 32 m chunks (with collision close by), keeps the sea under the camera, scatters plants,
## builds every town, and answers questions about any spot: how high, how deep, which
## fishing zone, which boat can go there, what's underfoot.

const Billboard := preload("res://scripts/billboard.gd")
const TownBuilder := preload("res://scripts/town_builder.gd")

const PLANT_SHADER := preload("res://shaders/plant.gdshader")
const CHUNK := 32
const VIEW_CHUNKS := 4
const KEEP_CHUNKS := 6
const COLLIDE_CHUNKS := 1
const BUILDS_PER_FRAME := 2
const VEG_CELL := 128
const TEX_FILES := {"grass": "grass", "sand": "sand", "rock": "rock", "dirt": "path", "cobble": "cobble",
	"forest": "forest", "mud": "mud", "pebble": "pebble"}
const SMALL_PLANTS := ["bush0", "bush1", "bush2", "bush_pink", "bush_white", "bush_yellow", "flowers0", "flowers1",
	"flowers2", "flowers3", "flowers4", "reeds0", "reeds1", "fern0", "fern1"]
const NO_COLLIDE := ["rock0", "rock1", "rock2"]

var W := 1280
var H := 1024
var heights: PackedFloat32Array
var mats: PackedByteArray
var zone_bytes: PackedByteArray
var tiers: PackedByteArray
var flag_bytes: PackedByteArray
var meta: Dictionary = {}
var zone_names: Array = []
var plant_names: Array = []
var F: Dictionary = {}
var sea_level := 0.0
var spawn_point := Vector3.ZERO
var water_material: ShaderMaterial
var terrain_material: ShaderMaterial
var lamps: Array[OmniLight3D] = []
var glow_mats: Array[StandardMaterial3D] = []
var beam: SpotLight3D
var folk := {}  # name -> {node, home, role, town, town_name, inside}
var cats: Array[Sprite3D] = []
var buildings: Array = []  # {name, kind, role, town, door, rot, size, node, y}
var docks: Array = []  # {rect: Rect2, y, moor}
var walkers: Array = []
var spinners: Array = []
var permits := {}  # unlocks from the save: permit_ranger, permit_ember, bridge
var hut_tier := 0
var focus: Node3D
var indoor := false  # the world is hidden while you're inside a building
var golden := false  # the Gull's Eye is back in the lighthouse lamp
var wind := 0.3  # 0 still to 1 gale, from the weather; plants sway with it
var _plant_mats: Array[ShaderMaterial] = []
var mill_fixed := true  # Willowford's mill sails turn (they're cracked until you mend them)
var bridge_node: Node3D
var gate_nodes: Array[Node3D] = []
var hut_node: Node3D
var builder: RefCounted
var _chunks := {}  # Vector2i -> {mesh, body}
var _veg := {}  # Vector2i -> Node3D
var _veg_list := {}  # Vector2i -> Array of [x, z, kind]
var _plant_meshes := {}
var _idx := {}  # step -> PackedInt32Array
var _sea: MeshInstance3D
var _t := 0.0


func load_world() -> void:
	var f := FileAccess.open("res://world/world.json", FileAccess.READ)
	if f == null:
		push_error("Missing res://world/world.json (run tools/godot_world.py)")
		return
	meta = JSON.parse_string(f.get_as_text())
	W = int(meta.size[0])
	H = int(meta.size[1])
	zone_names = meta.zones
	plant_names = meta.plants
	F = meta.flags
	sea_level = float(meta.get("sea_level", 0.0))
	var hf := FileAccess.open("res://world/height.bin", FileAccess.READ)
	heights = hf.get_buffer(W * H * 4).to_float32_array()
	var df := FileAccess.open("res://world/data.bin", FileAccess.READ)
	var data := df.get_buffer(W * H * 4)
	mats = data.slice(0, W * H)
	zone_bytes = data.slice(W * H, W * H * 2)
	tiers = data.slice(W * H * 2, W * H * 3)
	flag_bytes = data.slice(W * H * 3, W * H * 4)
	var sp: Array = meta.spawn
	spawn_point = Vector3(float(sp[0]), 0.0, float(sp[1]))
	spawn_point.y = height_at(spawn_point.x, spawn_point.z) + 0.2
	for p in meta.trees:
		var c := Vector2i(int(float(p[0]) / VEG_CELL), int(float(p[1]) / VEG_CELL))
		if not _veg_list.has(c):
			_veg_list[c] = []
		_veg_list[c].append(p)


func build() -> void:
	_make_materials()
	_build_sea()
	builder = TownBuilder.new(self)
	for t in meta.towns:
		builder.build_town(t)
	bridge_node = builder.bridge(meta.bridge, permits.has("bridge"))
	hut_node = builder.hut(meta.hut, hut_tier)
	rebuild_gates()
	_build_waterfall()
	# terrain around the start, all at once
	var c := _chunk_of(spawn_point)
	for dz in range(-VIEW_CHUNKS, VIEW_CHUNKS + 1):
		for dx in range(-VIEW_CHUNKS, VIEW_CHUNKS + 1):
			_build_chunk(c + Vector2i(dx, dz))
	for dz in range(-COLLIDE_CHUNKS, COLLIDE_CHUNKS + 1):
		for dx in range(-COLLIDE_CHUNKS, COLLIDE_CHUNKS + 1):
			_ensure_collision(c + Vector2i(dx, dz))
	_update_vegetation(spawn_point)


## The Gull's Eye is back: the lighthouse burns gold and reaches further.
func restore_light() -> void:
	golden = true
	if beam:
		beam.light_color = Color(1.0, 0.8, 0.38)
		beam.spot_range = 120.0
		beam.spot_angle = 11.0


## Hide (or show again) everything outdoors while you're inside a building.
func set_indoor(on: bool) -> void:
	indoor = on
	visible = not on


## Rebuild the bridge (repaired) or the hut (a new tier) after an unlock.
func rebuild_bridge() -> void:
	if bridge_node:
		bridge_node.queue_free()
	bridge_node = builder.bridge(meta.bridge, permits.has("bridge"))


func rebuild_gates() -> void:
	for g in gate_nodes:
		g.queue_free()
	gate_nodes.clear()
	for g in meta.gates:
		gate_nodes.append(builder.gate(g, permits.has(str(g.needs))))


func rebuild_hut(tier: int) -> void:
	hut_tier = tier
	if hut_node:
		# drop the old hut's door from the list before building the new one
		for i in range(buildings.size() - 1, -1, -1):
			if buildings[i].kind == "hut":
				buildings.remove_at(i)
		hut_node.queue_free()
	hut_node = builder.hut(meta.hut, tier)


func _process(delta: float) -> void:
	_t += delta
	var at := spawn_point
	if focus:
		at = focus.global_position
	# the sea follows the camera in 16 m steps (the waves are fixed to the world)
	var cam := get_viewport().get_camera_3d()
	var sea_at := at
	if cam:
		sea_at = cam.global_position
	_sea.position = Vector3(snappedf(sea_at.x, 16.0), sea_level, snappedf(sea_at.z, 16.0))
	_stream(at)
	_update_vegetation(at)
	if indoor:
		return
	for m in _plant_mats:
		m.set_shader_parameter("wind", wind)
	for w in walkers:
		_update_walker(w, delta, cam)
	if mill_fixed:
		for s in spinners:
			s.rotation.z += delta * 0.6


# --- questions about a spot --------------------------------------------------------

func _h(ix: int, iz: int) -> float:
	if ix < 0 or iz < 0 or ix >= W or iz >= H:
		return -30.0
	return heights[iz * W + ix]


func height_at(x: float, z: float) -> float:
	var ix := int(floor(x))
	var iz := int(floor(z))
	var fx := x - ix
	var fz := z - iz
	return lerpf(lerpf(_h(ix, iz), _h(ix + 1, iz), fx), lerpf(_h(ix, iz + 1), _h(ix + 1, iz + 1), fx), fz)


func _byte(arr: PackedByteArray, x: float, z: float) -> int:
	var ix := int(x)
	var iz := int(z)
	if ix < 0 or iz < 0 or ix >= W or iz >= H:
		return 0
	return arr[iz * W + ix]


## The height you'd stand at here: a dock's deck if there is one, otherwise the ground.
func stand_height(x: float, z: float) -> float:
	var h := height_at(x, z)
	for d in docks:
		var r: Rect2 = d.rect
		if r.grow(0.05).has_point(Vector2(x, z)):
			h = maxf(h, float(d.y))
	return h


func flags_at(x: float, z: float) -> int:
	return _byte(flag_bytes, x, z)


func tier_at(x: float, z: float) -> int:
	if x < 0 or z < 0 or x >= W or z >= H:
		return 5
	return _byte(tiers, x, z)


func zone_id(x: float, z: float) -> int:
	return _byte(zone_bytes, x, z)


## The fishing ground here: harbour, shallows, estuary, reef, kelp, wreck, blue, deep,
## lake, seagrass or lagoon ("" on land).
func zone_at(x: float, z: float) -> String:
	var i := zone_id(x, z)
	return str(zone_names[i]) if i < zone_names.size() else ""


func water_level_at(x: float, z: float) -> float:
	if zone_at(x, z) == "lake":
		return float(meta.lakes[0].level)
	return sea_level


func is_water(x: float, z: float) -> bool:
	if flags_at(x, z) & int(F.deck):
		return false
	return height_at(x, z) < water_level_at(x, z) - 0.05


func water_depth(x: float, z: float) -> float:
	if not is_water(x, z):
		return 0.0
	return water_level_at(x, z) - height_at(x, z)


## Can you walk here? (Locked places stay closed until you have the permit.)
func walkable(x: float, z: float) -> bool:
	var fl := flags_at(x, z)
	if fl & int(F.highland) and not permits.has("permit_ranger"):
		return false
	if fl & int(F.ember) and not permits.has("permit_ember") and height_at(x, z) > sea_level:
		return false
	return true


## Why you can't walk here (a locked gate or a permit you don't have yet), or "".
func gate_text(x: float, z: float) -> String:
	var fl := flags_at(x, z)
	if fl & int(F.highland) and not permits.has("permit_ranger"):
		for g in meta.gates:
			if g.needs == "permit_ranger":
				return str(g.text)
		return "The hills are closed. Ask the ranger in Willowford."
	if fl & int(F.ember) and not permits.has("permit_ember") and height_at(x, z) > sea_level:
		return "Ember Isle is off limits without a permit. The Harbourmaster in Gullhaven issues them."
	return ""


## What's underfoot, for footstep sounds: wood, sand, stone or grass.
func surface_at(x: float, z: float) -> String:
	if flags_at(x, z) & int(F.deck):
		return "wood"
	for d in docks:
		if d.rect.has_point(Vector2(x, z)):
			return "wood"
	match _byte(mats, x, z):
		0, 5:
			return "grass"
		1, 3, 6:
			return "sand"
	return "stone"


## The ground's material here: grass, sand, rock, dirt, cobble, forest, mud or pebble.
func mat_at(x: float, z: float) -> String:
	var names: Array = meta.materials
	return str(names[clampi(_byte(mats, x, z), 0, names.size() - 1)])


## Which island you're on (or just off), or "" on the mainland.
func island_at(x: float, z: float) -> String:
	for i in meta.islands:
		var rv: Variant = i.get("r")
		var r: float = 60.0 if rv == null else float(rv) * 1.5 + 6.0
		if Vector2(x - float(i.x), z - float(i.z)).length() < r:
			return str(i.id)
	return ""


## A place name for where you are: a town, a landmark or nothing.
func area_name(x: float, z: float) -> String:
	for t in meta.towns:
		if Vector2(x - float(t.x), z - float(t.z)).length() < float(t.r) + 18.0:
			return str(t.name)
	var best := ""
	var best_d := 70.0
	for l in meta.landmarks:
		var d := Vector2(x - float(l.x), z - float(l.z)).length()
		if d < best_d:
			best_d = d
			best = str(l.name)
	return best


## Turn a townsperson to face a point (someone talking to them) for a few seconds.
func folk_face(who: String, toward: Vector3) -> void:
	if not folk.has(who):
		return
	var node: Sprite3D = folk[who].node
	for w in walkers:
		if w.node == node:
			var d := toward - node.global_position
			d.y = 0.0
			if d.length() > 0.01:
				w.dir = d.normalized()
			w.t = 4.0
			w.target = node.position  # stop and listen


# --- terrain -----------------------------------------------------------------------

func _chunk_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.z / CHUNK)))


func _stream(at: Vector3) -> void:
	var c := _chunk_of(at)
	var built := 0
	# nearest missing chunks first
	for r in VIEW_CHUNKS + 1:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var k := c + Vector2i(dx, dz)
				if not _chunks.has(k):
					_build_chunk(k)
					built += 1
					if built >= BUILDS_PER_FRAME:
						break
			if built >= BUILDS_PER_FRAME:
				break
		if built >= BUILDS_PER_FRAME:
			break
	for dz in range(-COLLIDE_CHUNKS, COLLIDE_CHUNKS + 1):
		for dx in range(-COLLIDE_CHUNKS, COLLIDE_CHUNKS + 1):
			_ensure_collision(c + Vector2i(dx, dz))
	# drop what's far away
	for k in _chunks.keys():
		var d: int = maxi(absi(k.x - c.x), absi(k.y - c.y))
		var info: Dictionary = _chunks[k]
		if d > KEEP_CHUNKS:
			if info.mesh:
				info.mesh.queue_free()
			if info.body:
				info.body.queue_free()
			_chunks.erase(k)
		elif d > COLLIDE_CHUNKS + 1 and info.body:
			info.body.queue_free()
			info.body = null


func _indices(n: int) -> PackedInt32Array:
	if _idx.has(n):
		return _idx[n]
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx[k] = a
			idx[k + 1] = b
			idx[k + 2] = c
			idx[k + 3] = b
			idx[k + 4] = d
			idx[k + 5] = c
			k += 6
	_idx[n] = idx
	return idx


func _build_chunk(c: Vector2i) -> void:
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	# full detail where there's land or shallow water, coarse over the deep sea
	var fine := false
	for j in range(0, CHUNK + 1, 4):
		for i in range(0, CHUNK + 1, 4):
			if _h(ox + i, oz + j) > -7.0:
				fine = true
				break
		if fine:
			break
	var step := 1 if fine else 4
	var n := CHUNK / step + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	var k := 0
	for j in n:
		var z := oz + j * step
		for i in n:
			var x := ox + i * step
			verts[k] = Vector3(i * step, _h(x, z), j * step)
			norms[k] = Vector3(_h(x - step, z) - _h(x + step, z), 2.0 * step, _h(x, z - step) - _h(x, z + step)).normalized()
			k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = _indices(n)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(ox, 0.0, oz)
	add_child(mi)
	_chunks[c] = {"mesh": mi, "body": null}


func _ensure_collision(c: Vector2i) -> void:
	if not _chunks.has(c):
		_build_chunk(c)
	var info: Dictionary = _chunks[c]
	if info.body:
		return
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	var n := CHUNK + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	for j in n:
		for i in n:
			data[j * n + i] = _h(ox + i, oz + j)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(ox + CHUNK * 0.5, 0.0, oz + CHUNK * 0.5)
	add_child(body)
	info.body = body


# --- plants ------------------------------------------------------------------------

func _update_vegetation(at: Vector3) -> void:
	var c := Vector2i(int(at.x / VEG_CELL), int(at.z / VEG_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if not _veg.has(k):
				_build_veg(k)
	for k in _veg.keys():
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) > 2:
			_veg[k].queue_free()
			_veg.erase(k)


func _build_veg(c: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Plants_%d_%d" % [c.x, c.y]
	add_child(root)
	_veg[c] = root
	var list: Array = _veg_list.get(c, [])
	if list.is_empty():
		return
	var by_kind := {}
	for p in list:
		var kind := int(p[2])
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(p)
	var body := StaticBody3D.new()
	root.add_child(body)
	for kind in by_kind:
		var name_k: String = plant_names[kind]
		var arr: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _plant_mesh(name_k)
		mm.instance_count = arr.size()
		var trunk := name_k not in SMALL_PLANTS and name_k not in NO_COLLIDE
		var radius := 1.3 if name_k.begins_with("boulder") else 0.35
		for i in arr.size():
			var p: Array = arr[i]
			var x := float(p[0])
			var z := float(p[1])
			var s := 0.88 + fposmod(x * 7.31 + z * 3.17, 0.28)
			var pos := Vector3(x, height_at(x, z), z)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), pos))
			if trunk:
				var col := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = radius * s
				shape.height = 3.0
				col.shape = shape
				col.position = pos + Vector3(0.0, 1.5, 0.0)
				body.add_child(col)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.visibility_range_end = 220.0 if name_k not in SMALL_PLANTS else 90.0
		root.add_child(mmi)


func _plant_mesh(kind: String) -> Mesh:
	if _plant_meshes.has(kind):
		return _plant_meshes[kind]
	var tex: Texture2D = load("res://art/plants/%s.png" % kind)
	var px := 1.0 / 20.0 if kind in SMALL_PLANTS else 1.0 / 16.0
	var size := Vector2(tex.get_width(), tex.get_height()) * px
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0.0, size.y * 0.5 - 2.0 * px, 0.0)
	var m := ShaderMaterial.new()
	m.shader = PLANT_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("texel", px)
	var sway := 0.0
	if kind.begins_with("rock") or kind.begins_with("boulder"):
		sway = 0.0
	elif kind.begins_with("bush"):
		sway = 0.55
	elif kind in SMALL_PLANTS or kind.begins_with("reeds") or kind.begins_with("fern") or kind.begins_with("flowers"):
		sway = 1.0
	else:
		sway = 0.3  # trees: the canopy moves, the trunk doesn't
	m.set_shader_parameter("sway", sway)
	_plant_mats.append(m)
	q.material = m
	_plant_meshes[kind] = q
	return q


# --- water, materials, falls -----------------------------------------------------

func _make_materials() -> void:
	var imgs: Array[Image] = []
	for m in meta.materials:
		var tex: Texture2D = load("res://art/tex/%s.png" % TEX_FILES.get(m, "grass"))
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 64 or img.get_height() != 64:
			img.resize(64, 64, Image.INTERPOLATE_NEAREST)
		img.generate_mipmaps()
		imgs.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	var map_img := Image.create_from_data(W, H, false, Image.FORMAT_R8, mats)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("textures", arr)
	terrain_material.set_shader_parameter("material_map", ImageTexture.create_from_image(map_img))
	terrain_material.set_shader_parameter("world_size", Vector2(W, H))
	terrain_material.set_shader_parameter("rock_layer", meta.materials.find("rock"))
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(480.0, 480.0)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	plane.material = water_material
	_sea = MeshInstance3D.new()
	_sea.name = "Sea"
	_sea.mesh = plane
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	for lake in meta.lakes:
		var lp := PlaneMesh.new()
		lp.size = Vector2(float(lake.rx) * 2.0 + 10.0, float(lake.rz) * 2.0 + 10.0)
		lp.subdivide_width = 40
		lp.subdivide_depth = 30
		lp.material = water_material
		var lm := MeshInstance3D.new()
		lm.name = str(lake.name)
		lm.mesh = lp
		lm.position = Vector3(float(lake.x), float(lake.level), float(lake.z))
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lm)


func _build_waterfall() -> void:
	var wf: Dictionary = meta.waterfall
	var top := float(wf.top)
	var bottom := float(wf.bottom)
	var q := QuadMesh.new()
	q.size = Vector2(float(wf.width), top - bottom + 1.0)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/waterfall.gdshader")
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var at := Vector3(float(wf.x), (top + bottom) * 0.5, float(wf.z))
	mi.position = at
	# face downstream, toward the river
	var lake: Dictionary = meta.lakes[0]
	var away := Vector3(at.x - float(lake.x), 0.0, at.z - float(lake.z)).normalized()
	mi.rotation.y = atan2(away.x, away.z)
	add_child(mi)
	var mist := CPUParticles3D.new()
	mist.amount = 40
	mist.lifetime = 2.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(float(wf.width) * 0.5, 0.3, 1.0)
	mist.direction = Vector3.UP
	mist.spread = 40.0
	mist.initial_velocity_min = 0.6
	mist.initial_velocity_max = 1.6
	mist.gravity = Vector3(0.0, 0.2, 0.0)
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 2.5
	var dq := QuadMesh.new()
	dq.size = Vector2(0.5, 0.5)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.95, 0.98, 1.0, 0.35)
	dq.material = dm
	mist.mesh = dq
	mist.position = Vector3(at.x, bottom + 0.4, at.z) + away * 1.2
	add_child(mist)


# --- townsfolk and cats ------------------------------------------------------------

func _update_walker(w: Dictionary, delta: float, cam: Camera3D) -> void:
	var s: Sprite3D = w.node
	if not is_instance_valid(s) or not s.visible:
		return
	if cam and s.global_position.distance_to(cam.global_position) > 120.0:
		return
	w.t -= delta
	if w.kind == "folk":
		# townsfolk stroll about near home, stop, and glance around
		var goal: Vector3 = w.get("target", s.position)
		var gap := goal - s.position
		gap.y = 0.0
		if gap.length() > 0.15:
			var walk := gap.normalized() * minf(gap.length(), 1.1 * delta)
			s.position += walk
			s.position.y = stand_height(s.position.x, s.position.z)
			w.dir = walk.normalized()
			s.frame = Billboard.row_for(w.dir, cam) * 5 + [0, 1, 0, 2][int(_t * 7.0) % 4]
			return
		if w.t <= 0.0:
			w.t = randf_range(2.5, 6.0)
			var roam := float(w.get("wander", 0.0))
			if roam > 0.0 and randf() < 0.55:
				var home: Vector3 = w.home
				var cand := home + Vector3(randf_range(-roam, roam), 0.0, randf_range(-roam, roam))
				if stand_height(cand.x, cand.z) > sea_level + 0.1 and walkable(cand.x, cand.z):
					cand.y = stand_height(cand.x, cand.z)
					w.target = cand
			else:
				w.dir = [Vector3.BACK, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD][randi() % 5]
		s.frame = Billboard.row_for(w.dir, cam) * 5
		return
	# cats potter between spots near home, and sometimes sit or nap
	var target: Vector3 = w.target
	var to := target - s.position
	to.y = 0.0
	if to.length() < 0.1 or w.t <= 0.0:
		if w.t <= 0.0:
			w.t = randf_range(2.5, 7.0)
			var roll := randf()
			if roll < 0.25:
				w.rest = "sit"
			elif roll < 0.4:
				w.rest = "sleep"
				w.t *= 2.0
			else:
				w.rest = ""
				var home: Vector3 = w.home
				var cand := home + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.0, 2.0))
				if is_water(cand.x, cand.z) or flags_at(cand.x, cand.z) & int(F.deck):
					cand = home
				cand.y = height_at(cand.x, cand.z)
				w.target = cand
		var col := 3 if w.rest == "sit" else (4 if w.rest == "sleep" else 0)
		s.frame = Billboard.row_for(w.dir, cam) * 5 + col
		return
	var step := to.normalized() * minf(to.length(), 0.9 * delta)
	s.position += step
	s.position.y = height_at(s.position.x, s.position.z)
	w.dir = step.normalized()
	s.frame = Billboard.row_for(w.dir, cam) * 5 + 1 + (int(_t * 6.0) % 2)
