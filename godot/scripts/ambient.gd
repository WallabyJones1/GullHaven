extends Node3D
## Life around you: gulls wheeling over the coast and landing on the docks, crabs on the
## sand that scuttle off when you come close, butterflies over the grass on fine days,
## fireflies at night, fish jumping, dolphins and whales out at sea, smoke from the
## chimneys, and a few boats going about their business on the bay.
## Everything here is decoration: it lives near you and is recycled as you move.

const Boats := preload("res://scripts/boats.gd")

const GULLS := 8
const CRABS := 5
const BUTTERFLIES := 6
const FIREFLIES := 28
const SMOKES := 6
# boats sailing loops round the bay: kind, colour, waypoints, speed
const SAILORS := [
	["dinghy", "#e8e2d0", [Vector2(500, 620), Vector2(560, 650), Vector2(600, 720), Vector2(560, 760), Vector2(500, 720)], 3.2],
	["trawler", "#3f86bd", [Vector2(520, 585), Vector2(640, 560), Vector2(760, 520), Vector2(640, 600)], 2.6],
	["skiff", "#c84a3a", [Vector2(540, 800), Vector2(600, 850), Vector2(620, 800), Vector2(580, 770)], 4.0],
]
const BUTTERFLY_COLOURS := [Color(1.0, 1.0, 0.95), Color(1.0, 0.85, 0.3), Color(0.55, 0.75, 1.0), Color(1.0, 0.6, 0.3)]

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var audio: Node
var sea: Node
var boats: Node3D
var school: Node3D  # feeding frenzies draw the gulls
var _t := 0.0
var _gulls: Array = []  # {node, state, center, angle, radius, height, speed, perch, timer}
var _crabs: Array = []  # {node, dir, timer, fleeing}
var _flies: Array = []  # butterflies: {node, home, phase}
var _bugs: Array = []  # fireflies: {node, home, phase}
var _smokes: Array[CPUParticles3D] = []
var _sailors: Array = []  # {node, path, i, speed}
var _jump_t := 3.0
var _dolphin_t := 10.0
var _whale_t := 25.0
var _gull_cry_t := 8.0
var _recycle_t := 0.0
var _fish_icons: Array[Texture2D] = []
var _rng := RandomNumberGenerator.new()


func setup(w: Node3D, p: CharacterBody3D, c: Camera3D, a: Node, s: Node, b: Node3D) -> void:
	world = w
	player = p
	cam = c
	audio = a
	sea = s
	boats = b
	_rng.randomize()
	var gull_tex: Texture2D = load("res://art/critters/gull.png")
	for i in GULLS:
		var g := _sprite(gull_tex, 4, 1.0 / 20.0)
		_gulls.append({"node": g, "state": "fly", "center": Vector3.ZERO, "angle": _rng.randf() * TAU, "radius": _rng.randf_range(8.0, 20.0),
			"height": _rng.randf_range(7.0, 14.0), "speed": _rng.randf_range(0.25, 0.45), "perch": Vector3.ZERO, "timer": _rng.randf_range(8.0, 30.0)})
	var crab_tex: Texture2D = load("res://art/critters/crab.png")
	for i in CRABS:
		var c2 := _sprite(crab_tex, 2, 1.0 / 26.0)
		c2.visible = false
		_crabs.append({"node": c2, "dir": Vector3.RIGHT, "timer": 0.0, "fleeing": false})
	var fly_tex: Texture2D = load("res://art/critters/butterfly.png")
	for i in BUTTERFLIES:
		var f := _sprite(fly_tex, 2, 1.0 / 30.0)
		f.modulate = BUTTERFLY_COLOURS[i % BUTTERFLY_COLOURS.size()]
		f.visible = false
		_flies.append({"node": f, "home": Vector3.ZERO, "phase": _rng.randf() * TAU})
	var bug_tex := _glow_tex()
	for i in FIREFLIES:
		var b2 := Sprite3D.new()
		b2.texture = bug_tex
		b2.pixel_size = 1.0 / 30.0
		b2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b2.shaded = false
		b2.modulate = Color(0.85, 1.0, 0.45)
		b2.visible = false
		add_child(b2)
		_bugs.append({"node": b2, "home": Vector3.ZERO, "phase": _rng.randf() * TAU})
	for i in SMOKES:
		_smokes.append(_smoke_emitter())
	for s2 in SAILORS:
		var info: Dictionary = Boats.boat_info(str(s2[0]))
		var node: Node3D = boats.build_model(info, Color.html(str(s2[1])), true)
		add_child(node)
		var path: Array = s2[2]
		var start: Vector2 = path[0]
		node.global_position = Vector3(start.x, 0.0, start.y)
		_sailors.append({"node": node, "path": path, "i": 1, "speed": float(s2[3])})
	for id in ["mado", "silver_biddy", "port_herring", "yellowfin_bream", "tailor", "sand_whiting", "luderick", "garfish"]:
		var path2 := "res://art/fish2/%s.png" % id
		if ResourceLoader.exists(path2):
			_fish_icons.append(load(path2))


func _sprite(tex: Texture2D, frames: int, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = frames
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(s)
	return s


func _glow_tex() -> ImageTexture:
	var img := Image.create_empty(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 5:
		for x in 5:
			var d := Vector2(x - 2, y - 2).length()
			if d <= 2.2:
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.2 - d * 0.45, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _smoke_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/critters/smoke.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = 10
	p.lifetime = 4.0
	p.direction = Vector3(0.3, 1.0, 0.0)
	p.spread = 12.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.25, 0.15, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.85, 0.55))
	grad.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
	p.color_ramp = grad
	p.emitting = false
	add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	visible = not world.indoor
	if world.indoor:
		return
	var E: Dictionary = sea.env
	var h := float(E.hour)
	var night := h >= 19.5 or h < 5.0
	var wet := str(E.sky) == "rain" or str(E.sky) == "storm"
	var p := player.global_position
	_recycle_t -= delta
	var recycle := _recycle_t <= 0.0
	if recycle:
		_recycle_t = 0.7
	_update_gulls(delta, p, night, wet)
	_update_crabs(delta, p, recycle, night)
	_update_flies(delta, p, recycle, night or wet)
	_update_bugs(delta, p, recycle, night and not wet)
	_update_sailors(delta)
	if recycle:
		_update_smoke(p, h)
	_jumps(delta, p, night)


# --- gulls -------------------------------------------------------------------------------

func _update_gulls(delta: float, p: Vector3, night: bool, wet: bool) -> void:
	var coast: float = clampf(_coastness(p), 0.0, 1.0)
	for g in _gulls:
		var node: Sprite3D = g.node
		node.visible = (coast > 0.1 or (school != null and bool(school.frenzy_on))) and not night
		if not node.visible:
			g.center = p
			continue
		match str(g.state):
			"fly":
				var c: Vector3 = g.center
				var diving: bool = school != null and bool(school.frenzy_on) and _gulls.find(g) < 5
				if diving:
					var fa: Vector2 = school.frenzy_at
					c = c.lerp(Vector3(fa.x, 0.0, fa.y), minf(1.0, delta * 0.6))
				else:
					c = c.lerp(p + Vector3(6.0, 0.0, -4.0), minf(1.0, delta * 0.08))  # drift along with you
				g.center = c
				g.angle = float(g.angle) + delta * float(g.speed)
				var r := float(g.radius) * (0.35 if diving else 1.0)
				var high := float(g.height) + sin(_t * 0.7 + r) * 1.2
				if diving:
					high = 3.0 + 2.5 * maxf(0.0, sin(_t * 1.3 + float(g.angle) * 3.0)) - 2.8 * maxf(0.0, -sin(_t * 1.3 + float(g.angle) * 3.0))
				var at := c + Vector3(cos(float(g.angle)) * r, high, sin(float(g.angle)) * r)
				at.y += float(world.sea_level)
				_face_sprite(node, at - node.global_position)
				node.global_position = node.global_position.lerp(at, minf(1.0, delta * 2.0))
				var flap := int(_t * 9.0 + r) % 6
				node.frame = [0, 1, 2, 1, 1, 1][flap]  # flap, flap, glide
				g.timer = float(g.timer) - delta
				if float(g.timer) <= 0.0 and not wet:
					var perch := _perch_near(p)
					if perch != Vector3.INF:
						g.perch = perch
						g.state = "land"
					g.timer = _rng.randf_range(10.0, 30.0)
			"land":
				var target: Vector3 = g.perch
				var to := target - node.global_position
				_face_sprite(node, to)
				node.global_position += to.limit_length(6.0 * delta)
				node.frame = 1
				if to.length() < 0.15:
					g.state = "sit"
					g.timer = _rng.randf_range(5.0, 18.0)
			"sit":
				node.frame = 3
				g.timer = float(g.timer) - delta
				var scared := Vector2(p.x - node.global_position.x, p.z - node.global_position.z).length() < 3.5
				if float(g.timer) <= 0.0 or scared or wet:
					g.state = "fly"
					g.timer = _rng.randf_range(10.0, 30.0)
					if scared and _gull_cry_t < 5.0:
						audio.play("gull", -10.0, _rng.randf_range(0.9, 1.15))
	_gull_cry_t -= delta
	if _gull_cry_t <= 0.0:
		_gull_cry_t = _rng.randf_range(7.0, 16.0)
		if coast > 0.3 and not night and not wet:
			audio.play("gull", -14.0 + coast * 4.0, _rng.randf_range(0.85, 1.2))


func _face_sprite(node: Sprite3D, dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var right: Vector3 = cam.global_transform.basis.x
	node.flip_h = dir.dot(right) < 0.0


## How coastal it is around you (0 inland, 1 on the shore).
func _coastness(p: Vector3) -> float:
	var n := 0
	for i in 8:
		var a := TAU * i / 8.0
		var x := p.x + cos(a) * 18.0
		var z := p.z + sin(a) * 18.0
		if world.is_water(x, z) and world.zone_at(x, z) != "lake":
			n += 1
	return n / 4.0


func _perch_near(p: Vector3) -> Vector3:
	# a dock, a quay or a bit of beach not too close to you
	for attempt in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, 18.0)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		var y: float = world.stand_height(x, z)
		if y > float(world.sea_level) + 0.1 and y < float(world.sea_level) + 3.0:
			return Vector3(x, y + 0.2, z)
	return Vector3.INF


# --- crabs ---------------------------------------------------------------------------------

func _update_crabs(delta: float, p: Vector3, recycle: bool, night: bool) -> void:
	for c in _crabs:
		var node: Sprite3D = c.node
		if node.visible:
			var to := node.global_position - p
			to.y = 0.0
			if to.length() > 30.0:
				node.visible = false
				continue
			if to.length() < 2.6 and not bool(c.fleeing):
				c.fleeing = true
				c.dir = to.normalized()
			c.timer = float(c.timer) - delta
			var speed := 2.6 if bool(c.fleeing) else (0.6 if int(_t * 1.5 + node.global_position.x) % 3 != 0 else 0.0)
			var step: Vector3 = Vector3(c.dir) * speed * delta
			var next := node.global_position + step
			if bool(c.fleeing) and world.is_water(next.x, next.z):
				node.visible = false  # into the sea
				continue
			if float(c.timer) <= 0.0 and not bool(c.fleeing):
				c.timer = _rng.randf_range(1.5, 4.0)
				c.dir = Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
			next.y = float(world.height_at(next.x, next.z)) + 0.12
			node.global_position = next
			node.frame = int(_t * 10.0) % 2 if speed > 0.0 else 0
		elif recycle and not night and _rng.randf() < 0.3:
			var spot := _sand_near(p, 8.0, 22.0)
			if spot != Vector3.INF:
				node.global_position = spot + Vector3(0.0, 0.12, 0.0)
				node.visible = true
				c.fleeing = false
				c.timer = 0.0


func _sand_near(p: Vector3, r0: float, r1: float) -> Vector3:
	for attempt in 8:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(r0, r1)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		var h: float = world.height_at(x, z)
		if world.mat_at(x, z) in ["sand", "pebble"] and h > float(world.sea_level) + 0.05 and h < float(world.sea_level) + 1.2:
			return Vector3(x, h, z)
	return Vector3.INF


# --- butterflies and fireflies -------------------------------------------------------------------

func _update_flies(_delta: float, p: Vector3, recycle: bool, off: bool) -> void:
	for f in _flies:
		var node: Sprite3D = f.node
		if off:
			node.visible = false
			continue
		if node.visible:
			var home: Vector3 = f.home
			if home.distance_to(p) > 35.0:
				node.visible = false
				continue
			var ph := float(f.phase)
			var at := home + Vector3(sin(_t * 0.7 + ph) * 2.5, 0.8 + sin(_t * 1.9 + ph) * 0.4, cos(_t * 0.5 + ph * 1.3) * 2.5)
			_face_sprite(node, at - node.global_position)
			node.global_position = at
			node.frame = int(_t * 12.0 + ph) % 2
		elif recycle and _rng.randf() < 0.3:
			var spot := _green_near(p, 5.0, 20.0)
			if spot != Vector3.INF:
				f.home = spot
				node.global_position = spot + Vector3(0.0, 0.8, 0.0)
				node.visible = true


func _update_bugs(_delta: float, p: Vector3, recycle: bool, active: bool) -> void:
	for b in _bugs:
		var node: Sprite3D = b.node
		if not active:
			node.visible = false
			continue
		if node.visible:
			var home: Vector3 = b.home
			if home.distance_to(p) > 30.0:
				node.visible = false
				continue
			var ph := float(b.phase)
			node.global_position = home + Vector3(sin(_t * 0.31 + ph) * 1.6, 0.5 + sin(_t * 0.53 + ph * 2.0) * 0.5, cos(_t * 0.27 + ph) * 1.6)
			node.modulate.a = clampf(0.5 + 0.8 * sin(_t * 2.1 + ph * 3.0), 0.0, 1.0)
		elif recycle:
			var spot := _green_near(p, 3.0, 18.0)
			if spot != Vector3.INF:
				b.home = spot
				node.visible = true


func _green_near(p: Vector3, r0: float, r1: float) -> Vector3:
	for attempt in 6:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(r0, r1)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		if world.mat_at(x, z) in ["grass", "forest"] and not world.is_water(x, z):
			return Vector3(x, world.height_at(x, z), z)
	return Vector3.INF


# --- boats about their business ----------------------------------------------------------------------

func _update_sailors(delta: float) -> void:
	for s in _sailors:
		var node: Node3D = s.node
		var path: Array = s.path
		var target: Vector2 = path[int(s.i)]
		var pos := Vector2(node.global_position.x, node.global_position.z)
		var to := target - pos
		if to.length() < 4.0:
			s.i = (int(s.i) + 1) % path.size()
		var dir := to.normalized()
		var want := atan2(-dir.x, -dir.y)
		node.rotation.y = lerp_angle(node.rotation.y, want, minf(1.0, delta * 0.6))
		var fwd := Vector3(-sin(node.rotation.y), 0.0, -cos(node.rotation.y))
		node.global_position += fwd * float(s.speed) * delta
		node.global_position.y = float(world.sea_level) + sin(_t * 1.4 + pos.x) * 0.05
		node.rotation.z = sin(_t * 1.1 + pos.y) * 0.03


# --- chimney smoke ---------------------------------------------------------------------------------------

func _update_smoke(p: Vector3, hour: float) -> void:
	var chimneys: Array = []
	for b in world.buildings:
		if not str(b.kind) in ["cottage", "house", "shop", "inn", "tavern", "bakery", "hut"]:
			continue
		var node: Node3D = b.node
		if not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(p)
		if d < 70.0:
			chimneys.append([d, b])
	chimneys.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	var cosy := hour < 9.0 or hour > 16.5  # fires are lit mornings and evenings
	for i in _smokes.size():
		var em: CPUParticles3D = _smokes[i]
		if i < chimneys.size() and (cosy or i % 2 == 0):
			var b: Dictionary = chimneys[i][1]
			var node: Node3D = b.node
			var size: Vector3 = b.size
			em.global_position = node.global_position + Vector3(size.x * 0.25, size.y + 1.8, 0.0)
			em.emitting = true
		else:
			em.emitting = false


# --- fish jumping, dolphins, whales ---------------------------------------------------------------------------

func _jumps(delta: float, p: Vector3, night: bool) -> void:
	_jump_t -= delta
	if _jump_t <= 0.0:
		_jump_t = _rng.randf_range(3.5, 9.0)
		var spot := _water_near(p, 8.0, 28.0, 0.8)
		if spot != Vector3.INF and not _fish_icons.is_empty():
			_leap(_fish_icons[_rng.randi() % _fish_icons.size()], spot, 1.0 / 60.0, _rng.randf_range(0.6, 1.2), 1.4, 0.7)
	_dolphin_t -= delta
	if _dolphin_t <= 0.0:
		_dolphin_t = _rng.randf_range(14.0, 28.0)
		var spot2 := _water_near(p, 25.0, 60.0, 4.0)
		if spot2 != Vector3.INF and not night:
			var heading := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
			var tex: Texture2D = load("res://art/critters/dolphin.png")
			for k in _rng.randi_range(2, 4):
				var at := spot2 + heading * k * 3.0 + heading.cross(Vector3.UP) * _rng.randf_range(-1.5, 1.5)
				get_tree().create_timer(k * 0.45).timeout.connect(_leap.bind(tex, at, 1.0 / 14.0, 1.6, 4.0, 1.0, heading))
	_whale_t -= delta
	if _whale_t <= 0.0:
		_whale_t = _rng.randf_range(30.0, 60.0)
		var spot3 := _water_near(p, 60.0, 140.0, 8.0)
		if spot3 != Vector3.INF:
			_whale(spot3)


func _water_near(p: Vector3, r0: float, r1: float, depth: float) -> Vector3:
	for attempt in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(r0, r1)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		if world.is_water(x, z) and float(world.water_depth(x, z)) > depth and world.zone_at(x, z) != "lake":
			return Vector3(x, float(world.water_level_at(x, z)), z)
	return Vector3.INF


## Something leaps out of the water and back in: a fish, a dolphin.
func _leap(tex: Texture2D, at: Vector3, px: float, height: float, length: float, time: float, dir := Vector3.ZERO) -> void:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(s)
	if dir == Vector3.ZERO:
		dir = Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
	var right: Vector3 = cam.global_transform.basis.x
	s.flip_h = dir.dot(right) < 0.0
	var from := at
	var to := at + dir * length
	_ring(from)
	var tw := s.create_tween()
	tw.tween_method(_leap_step.bind(s, from, to, height), 0.0, 1.0, time)
	tw.tween_callback(_ring.bind(to))
	tw.tween_callback(s.queue_free)
	var d := at.distance_to(player.global_position)
	if d < 30.0:
		audio.play("plop", -10.0 - d * 0.5, _rng.randf_range(0.8, 1.2))


func _leap_step(k: float, s: Sprite3D, from: Vector3, to: Vector3, height: float) -> void:
	s.global_position = from.lerp(to, k) + Vector3(0.0, sin(k * PI) * height, 0.0)
	s.rotation.z = (0.6 - k * 1.2) * (-1.0 if s.flip_h else 1.0)


func _ring(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.25
	t.outer_radius = 0.32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.6)
	t.material = m
	ring.mesh = t
	add_child(ring)
	ring.global_position = Vector3(at.x, float(world.sea_level) + 0.04, at.z)
	ring.scale = Vector3(1.0, 0.1, 1.0)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(4.0, 0.1, 4.0), 1.2)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.2)
	tw.chain().tween_callback(ring.queue_free)


func _whale(at: Vector3) -> void:
	var tail := Sprite3D.new()
	tail.texture = load("res://art/critters/whale_tail.png")
	tail.pixel_size = 1.0 / 8.0
	tail.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tail.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tail.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(tail)
	var base := Vector3(at.x, float(world.sea_level) - 2.6, at.z)
	tail.global_position = base
	var spout := _smoke_emitter()
	spout.global_position = base + Vector3(-4.0, 2.6, 0.0)
	spout.direction = Vector3.UP
	spout.initial_velocity_min = 4.0
	spout.initial_velocity_max = 6.0
	spout.gravity = Vector3(0.0, -4.0, 0.0)
	spout.lifetime = 1.6
	spout.one_shot = true
	spout.amount = 16
	spout.emitting = true
	var tw := tail.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(tail, "global_position:y", float(world.sea_level) + 1.2, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.6)
	tw.tween_property(tail, "global_position:y", float(world.sea_level) - 3.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_ring.bind(base))
	tw.tween_callback(tail.queue_free)
	tw.tween_callback(spout.queue_free)
