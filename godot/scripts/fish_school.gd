extends Node3D
## Fish shadows drifting through the harbour, drawn by the water shader. Each shadow is
## a real fish (rolled when it appears), so a big shadow means a big fish. When a bobber
## lands, the nearest free fish comes over, nibbles a few times, then bites.

signal nibble
signal bite(species: Dictionary)

const COUNT := 8  # the water shader draws up to 8
const AREA := Rect2(-24.0, 1.6, 54.0, 18.0)  # where shadows roam (x, z)

var harbour: Node3D
var roller: Callable  # returns a species Dictionary; set by Fishing
var fish: Array[Dictionary] = []
var lure := Vector2.ZERO
var lure_in := false
var _taker := -1  # index of the fish going for the bait
var _wait := 0.0  # time until a fish takes an interest
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func setup(h: Node3D) -> void:
	harbour = h
	_rng.randomize()
	for i in COUNT:
		fish.append(_new_fish(_random_point()))


func reroll_all() -> void:
	for f in fish:
		_assign_species(f)


func lure_landed(p: Vector2) -> void:
	lure = p
	lure_in = true
	_taker = -1
	_wait = _rng.randf_range(0.8, 2.5)


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


## Is a fish circling or nibbling right now? (Striking now would spook it.)
func is_interested() -> bool:
	return _taker >= 0 and fish[_taker].mode == "nibble"


func _process(delta: float) -> void:
	_t += delta
	if lure_in and _taker < 0:
		_wait -= delta
		if _wait <= 0.0:
			_choose_taker()
	for f in fish:
		_step(f, delta)
	_push_to_shader()


func _choose_taker() -> void:
	var best := -1
	var best_d := 16.0
	for i in fish.size():
		var f := fish[i]
		if f.mode != "wander":
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
				if _rng.randf() < 0.15:
					_assign_species(f)  # the harbour's mix shifts as the day goes on
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
					bite.emit(f.species)
		"biting":
			goal = lure + (pos - lure).normalized() * body * 0.45
			speed = 3.0
			face_lure = true
		"hooked":
			# Thrash just under the bobber, wherever the fight drags it.
			var away := (lure - pos)
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
		if harbour.is_water(next.x, next.y):
			pos = next
		elif f.mode == "wander" or f.mode == "flee":
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
	if not harbour.is_water(target.x, target.y):
		target = _random_point()
	f.mode = "flee"
	f.target = target


func _new_fish(at: Vector2) -> Dictionary:
	var f := {
		"pos": at,
		"heading": _rng.randf() * TAU,
		"target": _random_point(),
		"speed": _rng.randf_range(0.45, 0.8),
		"len": 0.6,
		"species": {},
		"mode": "wander",
		"timer": 0.0,
		"nibbles": 0,
	}
	_assign_species(f)
	return f


## Give a shadow its fish. Shadow length follows the species' size.
func _assign_species(f: Dictionary) -> void:
	if not roller.is_valid():
		f.len = _rng.randf_range(0.4, 1.0)
		return
	var s: Dictionary = roller.call()
	f.species = s
	var sz: Array = s.get("sz", [20, 40])
	var avg := (float(sz[0]) + float(sz[1])) * 0.5
	f.len = clampf(avg / 100.0 * 1.5, 0.38, 1.7)


func _random_point() -> Vector2:
	for i in 40:
		var p := Vector2(_rng.randf_range(AREA.position.x, AREA.end.x), _rng.randf_range(AREA.position.y, AREA.end.y))
		if harbour.is_water(p.x, p.y) and harbour.is_water(p.x + 1.0, p.y) and harbour.is_water(p.x - 1.0, p.y):
			return p
	return Vector2(-6.0, 6.0)


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
