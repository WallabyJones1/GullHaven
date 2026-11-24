extends Node3D
## Fish shadows drifting through the water, drawn by the water shader. Each shadow's size
## comes from what could really be biting there right now (the sea's rules), so a big
## shadow means a big fish. When a bobber lands, the nearest free shadow comes over,
## nibbles a few times, then bites.
## Every few minutes a feeding frenzy boils up somewhere: shadows crowd in, bites come
## fast, and rarer fish are three times as likely.

signal nibble
signal bite(size_class: int)
signal frenzy_started(at: Vector3)
signal frenzy_ended

const COUNT := 8  # the water shader draws up to 8
const RANGE := 34.0  # shadows roam within this distance of you
const LOST := 70.0  # shadows further than this drift back in near you
const FRENZY_TIME := 60.0
const FRENZY_RADIUS := 3.5

var harbour: Node3D
var focus: Node3D  # the player: shadows stay around them
var roller: Callable  # (pos: Vector2) -> size class; set by Fishing
var fish: Array[Dictionary] = []
var lure := Vector2.ZERO
var lure_in := false
var frenzy_on := false
var frenzy_at := Vector2.ZERO
var _frenzy_t := 0.0
var _frenzy_wait := 0.0
var _bubbles: CPUParticles3D
var _taker := -1  # index of the fish going for the bait
var _wait := 0.0  # time until a fish takes an interest
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _lost_t := 0.0


func setup(h: Node3D) -> void:
	harbour = h
	_rng.randomize()
	_frenzy_wait = _rng.randf_range(90.0, 150.0)
	for i in COUNT:
		fish.append(_new_fish(_random_point()))
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 60
	_bubbles.lifetime = 1.2
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = FRENZY_RADIUS * 0.6
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 20.0
	_bubbles.initial_velocity_min = 0.4
	_bubbles.initial_velocity_max = 1.2
	_bubbles.gravity = Vector3(0.0, -1.5, 0.0)
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.92, 1.0, 1.0)
	q.material = m
	_bubbles.mesh = q
	_bubbles.emitting = false
	add_child(_bubbles)


func reroll_all() -> void:
	for f in fish:
		_assign_class(f)


## The bait's in the water. Returns how close it landed to the nearest shadow (metres):
## right on a fish's nose and it goes for it at once.
func lure_landed(p: Vector2) -> float:
	lure = p
	lure_in = true
	_taker = -1
	_wait = _rng.randf_range(0.8, 2.5)
	if near_frenzy(p):
		_wait = _rng.randf_range(0.2, 0.8)
	var best := 99.0
	var best_i := -1
	for i in fish.size():
		var f := fish[i]
		if f.mode != "wander" and f.mode != "frenzy":
			continue
		var fp: Vector2 = f.pos
		var d := fp.distance_to(p)
		if d < best:
			best = d
			best_i = i
	if best < 1.6 and best_i >= 0:
		_taker = best_i
		fish[best_i].mode = "approach"
		_wait = 0.0
	return best


func move_lure(p: Vector2) -> void:
	lure = p


## The bobber came out of the water. A fish that was interested swims off.
func lure_cleared() -> void:
	if _taker >= 0:
		_flee(_taker)
	lure_in = false
	_taker = -1


## The bite wasn't struck in time: that fish lets go, and another may come along.
func bite_missed() -> void:
	if _taker >= 0:
		_flee(_taker)
	_taker = -1
	_wait = _rng.randf_range(2.0, 4.0)


func hooked() -> void:
	if _taker >= 0:
		fish[_taker].mode = "hooked"


## Landed: that shadow is gone, and a new fish drifts in from further out.
func fish_landed() -> void:
	if _taker >= 0:
		fish[_taker] = _new_fish(_far_point())
	lure_in = false
	_taker = -1


func fish_escaped() -> void:
	lure_cleared()


## Is a fish nibbling right now? (Striking now would spook it.)
func is_interested() -> bool:
	return _taker >= 0 and fish[_taker].mode == "nibble"


func near_frenzy(p: Vector2) -> bool:
	return frenzy_on and p.distance_to(frenzy_at) < FRENZY_RADIUS + 1.5


## How much rarer fish are boosted for a bait at p (feeding frenzies triple the odds).
func frenzy_boost(p: Vector2) -> float:
	return 3.0 if near_frenzy(p) else 1.0


func _process(delta: float) -> void:
	_t += delta
	_update_frenzy(delta)
	if lure_in and _taker < 0:
		_wait -= delta
		if _wait <= 0.0:
			_choose_taker()
	_lost_t -= delta
	if _lost_t <= 0.0:
		_lost_t = 0.5
		var here := _here()
		for i in fish.size():
			var fp: Vector2 = fish[i].pos
			if fish[i].mode == "wander" and fp.distance_to(here) > LOST:
				var p := _random_point()
				if p.distance_to(here) < LOST:
					fish[i] = _new_fish(p)
	for f in fish:
		_step(f, delta)
	_push_to_shader()


func _update_frenzy(delta: float) -> void:
	if frenzy_on:
		_frenzy_t -= delta
		if _frenzy_t <= 0.0:
			frenzy_on = false
			_bubbles.emitting = false
			_frenzy_wait = _rng.randf_range(150.0, 240.0)
			for f in fish:
				if f.mode == "frenzy":
					f.mode = "wander"
			frenzy_ended.emit()
		return
	_frenzy_wait -= delta
	if _frenzy_wait > 0.0:
		return
	frenzy_on = true
	_frenzy_t = FRENZY_TIME
	frenzy_at = _random_point()
	if not _swimmable(frenzy_at):
		frenzy_on = false
		_frenzy_wait = 30.0
		return
	_bubbles.global_position = Vector3(frenzy_at.x, harbour.water_level_at(frenzy_at.x, frenzy_at.y) + 0.05, frenzy_at.y)
	_bubbles.emitting = true
	# Pull the four nearest free shadows in, and make them bigger fish.
	var order: Array = []
	for i in fish.size():
		if fish[i].mode == "wander":
			var fp: Vector2 = fish[i].pos
			order.append([fp.distance_to(frenzy_at), i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(4, order.size()):
		var f := fish[order[k][1]]
		f.mode = "frenzy"
		f.cls = mini(int(f.cls) + 1, 3)
		f.len = float(_class_len(int(f.cls)))
	frenzy_started.emit(Vector3(frenzy_at.x, 0.0, frenzy_at.y))


func _choose_taker() -> void:
	var best := -1
	var best_d := 16.0
	for i in fish.size():
		var f := fish[i]
		if f.mode != "wander" and f.mode != "frenzy":
			continue
		var fp: Vector2 = f.pos
		var d := fp.distance_to(lure)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		_wait = 1.5
		return
	_taker = best
	fish[best].mode = "approach"


func _step(f: Dictionary, delta: float) -> void:
	var pos: Vector2 = f.pos
	var goal := pos
	var speed: float = f.speed
	var face_lure := false
	var body: float = f.len
	match f.mode:
		"wander":
			goal = f.target
			if pos.distance_to(goal) < 0.6:
				f.target = _random_point()
				if _rng.randf() < 0.2:
					_assign_class(f)  # the mix shifts with the time, tide and weather
		"frenzy":
			goal = f.target
			speed = 1.4
			if pos.distance_to(goal) < 0.4 or goal.distance_to(frenzy_at) > FRENZY_RADIUS:
				f.target = frenzy_at + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.5, FRENZY_RADIUS)
		"approach":
			goal = lure + (pos - lure).normalized() * body * 0.55
			speed = 1.6
			face_lure = true
			if pos.distance_to(goal) < 0.2:
				f.mode = "nibble"
				f.nibbles = _rng.randi_range(1, 3)
				f.timer = _rng.randf_range(0.8, 1.6)
		"nibble":
			goal = lure + (pos - lure).normalized() * body * 0.55
			speed = 0.5
			face_lure = true
			f.timer -= delta
			if f.timer <= 0.0:
				if f.nibbles > 0:
					f.nibbles -= 1
					f.timer = _rng.randf_range(0.7, 1.5)
					pos += (lure - pos).normalized() * 0.15  # a little dart at the bait
					nibble.emit()
				else:
					f.mode = "biting"
					bite.emit(int(f.cls))
		"biting":
			goal = lure + (pos - lure).normalized() * body * 0.45
			speed = 3.0
			face_lure = true
		"hooked":
			# Thrash just under the bobber, wherever the fight drags it.
			var away := lure - pos
			pos = pos.lerp(lure - away.normalized() * body * 0.2, minf(delta * 10.0, 1.0))
			if away.length() > 0.01:
				f.heading = lerp_angle(float(f.heading), atan2(away.y, away.x), minf(delta * 6.0, 1.0))
			f.heading = float(f.heading) + sin(_t * 14.0) * 0.08
			f.pos = pos
			return
		"flee":
			goal = f.target
			speed = 3.2
			if pos.distance_to(goal) < 0.8:
				f.mode = "wander"
				f.target = _random_point()

	var to := goal - pos
	var dist := to.length()
	var heading: float = f.heading
	if face_lure:
		var look := lure - pos
		if look.length() > 0.01:
			heading = lerp_angle(heading, atan2(look.y, look.x), minf(delta * 6.0, 1.0))
	elif dist > 0.05:
		heading = lerp_angle(heading, atan2(to.y, to.x), minf(delta * 3.0, 1.0))
	if dist > 0.01:
		var next := pos + to / dist * minf(speed * delta, dist)
		if _swimmable(next):
			pos = next
		elif f.mode == "wander" or f.mode == "flee" or f.mode == "frenzy":
			f.target = _random_point()
	f.heading = heading
	f.pos = pos


func _flee(i: int) -> void:
	var f := fish[i]
	var pos: Vector2 = f.pos
	var away := (pos - lure).normalized()
	if away.length() < 0.1:
		away = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	var target := pos + away * 8.0
	if not _swimmable(target):
		target = _random_point()
	f.mode = "flee"
	f.target = target


func _new_fish(at: Vector2) -> Dictionary:
	var f := {
		"pos": at,
		"heading": _rng.randf() * TAU,
		"target": _random_point(),
		"speed": _rng.randf_range(0.45, 0.8),
		"cls": 0,
		"len": 0.6,
		"mode": "wander",
		"timer": 0.0,
		"nibbles": 0,
	}
	_assign_class(f)
	return f


## Give a shadow its size class, from what could be biting where it swims.
func _assign_class(f: Dictionary) -> void:
	var c := _rng.randi_range(0, 2)
	if roller.is_valid():
		c = int(roller.call(f.pos))
	f.cls = c
	f.len = _class_len(c)


func _class_len(c: int) -> float:
	var lens := [0.45, 0.8, 1.3, 1.8]
	return float(lens[clampi(c, 0, 3)]) * _rng.randf_range(0.9, 1.1)


## Deep enough for a shadow to swim (not right up on the sand).
func _swimmable(p: Vector2) -> bool:
	return harbour.water_depth(p.x, p.y) > 0.45


func _here() -> Vector2:
	if focus:
		return Vector2(focus.global_position.x, focus.global_position.z)
	return Vector2(476.0, 576.0)


func _random_point() -> Vector2:
	var here := _here()
	for i in 50:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * RANGE + 3.0
		var p := here + Vector2(cos(a), sin(a)) * r
		if _swimmable(p) and _swimmable(p + Vector2(1.0, 0.0)) and _swimmable(p - Vector2(1.0, 0.0)):
			return p
	# nowhere wet nearby: park it out of sight; it'll come back when you reach the water
	return here + Vector2(0.0, 500.0)


func _far_point() -> Vector2:
	var p := _random_point()
	for i in 10:
		if p.distance_to(lure) > 10.0:
			break
		p = _random_point()
	return p


func _push_to_shader() -> void:
	var mat: ShaderMaterial = harbour.water_material
	if mat == null:
		return
	var data := PackedVector4Array()
	data.resize(COUNT)
	for i in fish.size():
		var f := fish[i]
		var p: Vector2 = f.pos
		data[i] = Vector4(p.x, p.y, float(f.len), float(f.heading))
	mat.set_shader_parameter("fish", data)
	mat.set_shader_parameter("fish_count", fish.size())
