extends RefCounted
## The 3D models made in Blender (tools/blender/gull_models.py and gull_fish.py, exported
## to res://models/<group>/<name>.glb): trees, bushes, flowers, reeds and rocks; gulls,
## crabs, butterflies, dolphins and the whale; the sea monsters and the treasure chest; the
## plot garden things; and every fish. They're low-poly with little pixel-art textures, so
## the textures are switched to nearest filtering here to keep them crisp.
## Models face +X (a fish's nose, a gull's beak) with their origin at the base.

const ROOT := "res://models/%s/%s.glb"

static var _scenes := {}
static var _meshes := {}


static func has(group: String, name: String) -> bool:
	return ResourceLoader.exists(ROOT % [group, name])


## A new copy of a model, or null if there isn't one.
static func make(group: String, name: String) -> Node3D:
	var key := group + "/" + name
	if not _scenes.has(key):
		_scenes[key] = load(ROOT % [group, name]) if has(group, name) else null
	var ps: PackedScene = _scenes[key]
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	crisp(n)
	return n


## The model's mesh on its own (for MultiMeshes), or null.
static func mesh(group: String, name: String) -> Mesh:
	var key := group + "/" + name
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = null
	var n := make(group, name)
	if n:
		var found := n.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			m = (found[0] as MeshInstance3D).mesh
		n.free()
	_meshes[key] = m
	return m


static func crisp(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var me: Mesh = (mi as MeshInstance3D).mesh
		if me == null:
			continue
		for i in me.get_surface_count():
			var mat := me.surface_get_material(i) as BaseMaterial3D
			if mat:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


## A part of a model by name ("Wing_L"), or null.
static func part(n: Node, name: String) -> Node3D:
	var found := n.find_children(name, "Node3D", true, false)
	return found[0] if not found.is_empty() else null


## Turn a model (facing +X) to face a direction on the ground.
static func face(n: Node3D, dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.001:
		n.rotation.y = atan2(-dir.z, dir.x)


## Tint every surface of a model (a golden fish, a blue butterfly).
static func tint(n: Node, c: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var me: Mesh = (mi as MeshInstance3D).mesh
		if me == null:
			continue
		for i in me.get_surface_count():
			var base := me.surface_get_material(i) as BaseMaterial3D
			if base:
				var m := base.duplicate() as BaseMaterial3D
				m.albedo_color = base.albedo_color * c
				(mi as MeshInstance3D).set_surface_override_material(i, m)
