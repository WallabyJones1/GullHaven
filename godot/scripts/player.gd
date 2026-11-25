extends CharacterBody3D
## The fisher: a pixel-art billboard that walks relative to the camera over land, docks
## and the shallows, shows the right side of itself whichever way the camera turns, and
## holds each catch up for the camera. Fall in (or wade out too deep) and you swim: slower,
## head above water, and you can't swim out past the bay. Swim at a dock or quay to climb
## out, or paddle back to a beach.

const Billboard := preload("res://scripts/billboard.gd")

const SPEED := 4.4
const GRAVITY := 20.0
const PIXEL := 1.0 / 26.0  # 48 px frames, about 1.6 m tall
const WADE := 0.35  # how deep you can walk into the water
const COLS := 5  # stand, walk A, walk B, cast, cheer
const WALK := [0, 1, 0, 2]
const SWIM_SPEED := 2.4
const SWIM_DEPTH := 0.75  # water this deep (ground below the surface) and you're swimming
const SINK := 0.95  # how far the sprite sinks while swimming
const CLIMB := 1.8  # the highest ledge above the water you can haul yourself onto
const STEP_UP := 0.36  # the tallest ledge you walk straight up: a kerb, a dock edge, a stair

signal gate_blocked(text: String)  # walked into somewhere locked (with why)

var facing := Vector3(0.0, 0.0, -1.0)  # world direction you last walked or turned to
var can_move := true
var riding := false  # aboard a boat: the boat carries you, so no walking physics
var swimming := false
var pose := ""  # "" walks and stands; "cast" or "cheer" hold a pose
var harbour: Node3D  # the world: waterline and what's underfoot
var audio: Node
var cam: Camera3D
var sprite: Sprite3D
var _last_step := 0
var _walk_t := 0.0
var _moving := false
var _held: Sprite3D
var _held_t := 0.0
var _last_safe := Vector3.ZERO
var _gate_t := 0.0
var _stroke_t := 0.0
var _swim_warn_t := 0.0
var _push_t := 0.0
var _ripple: MeshInstance3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(48.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.3
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.65
	add_child(col)

	sprite = Billboard.sprite(load("res://art/chars2/player.png"), PIXEL, COLS, 4, 46.0)
	add_child(sprite)

	_held = Billboard.sprite(null, 1.0 / 52.0)
	_held.position.y = 2.15
	_held.visible = false
	add_child(_held)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.52
	ring.rings = 24
	ring.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.95, 0.98, 1.0, 0.55)
	ring.material = rm
	_ripple = MeshInstance3D.new()
	_ripple.mesh = ring
	_ripple.scale = Vector3(1.0, 0.08, 1.0)
	_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ripple.visible = false
	add_child(_ripple)


func _physics_process(delta: float) -> void:
	_gate_t = maxf(0.0, _gate_t - delta)
	_swim_warn_t = maxf(0.0, _swim_warn_t - delta)
	if riding:
		velocity = Vector3.ZERO
		_moving = false
		_walk_t = 0.0
		_set_swimming(false)
		return
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := Vector3.RIGHT
	var fwd := Vector3.FORWARD
	if cam:
		right = cam.global_transform.basis.x
		fwd = -cam.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		right = right.normalized()
		fwd = fwd.normalized()
	var move := right * input.x + fwd * (-input.y)
	_moving = move.length() > 0.1
	if harbour:
		var wl: float = harbour.water_level_at(global_position.x, global_position.z)
		var ground: float = harbour.height_at(global_position.x, global_position.z)
		if not swimming and ground < wl - SWIM_DEPTH and global_position.y < wl + 0.05:
			_set_swimming(true)
		if swimming:
			_swim(delta, move, input, wl, ground)
			return
	if _moving:
		facing = move.normalized()
		var vel := _keep_on_land(move * SPEED)
		velocity.x = vel.x
		velocity.z = vel.z
		_walk_t += delta * 8.0 * input.length()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_walk_t = 0.0
	if is_on_floor():
		velocity.y = -0.1
		if harbour and global_position.y > float(harbour.water_level_at(global_position.x, global_position.z)) - WADE:
			_last_safe = global_position
	else:
		velocity.y -= GRAVITY * delta
	if _moving and is_on_floor():
		_step_up(delta)
	move_and_slide()
	var floor_y: float = harbour.height_at(global_position.x, global_position.z) - 4.0 if harbour else -1.0
	if global_position.y < floor_y:
		global_position = _last_safe  # never end up out at sea
		velocity = Vector3.ZERO
	var step: int = WALK[int(_walk_t) % 4] if _moving else 0
	if step != 0 and step != _last_step and audio and harbour:
		var surface: String = harbour.surface_at(global_position.x, global_position.z)
		if global_position.y < float(harbour.water_level_at(global_position.x, global_position.z)) + 0.05:
			surface = "sand"
		audio.play("step_" + surface, -10.0, 1.0, 0.12)
	_last_step = step


func _process(delta: float) -> void:
	# sink to the shoulders while swimming, with a ring of ripples
	var sink := -SINK if swimming else 0.0
	sprite.position.y = lerpf(sprite.position.y, sink, minf(1.0, delta * 10.0))
	if _ripple.visible:
		var k := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		_ripple.scale = Vector3(k, 0.08, k)
	# Pick the frame every frame, so turning the camera turns the sprite too.
	var row := Billboard.row_for(facing, cam)
	var col := 0
	if pose == "cast":
		col = 3
	elif pose == "cheer":
		col = 4
		row = Billboard.DOWN
	elif _moving:
		col = WALK[int(_walk_t) % 4]
	if swimming:
		col = 1 if _moving and int(_walk_t) % 2 == 0 else 0
	sprite.frame = row * COLS + col
	if _held.visible:
		_held_t += delta
		_held.position.y = 2.15 + absf(sin(_held_t * 5.0)) * 0.08
		if _held.get_child_count() > 0 and cam:
			(_held.get_child(-1) as Node3D).global_rotation = Vector3(0.0, cam.global_rotation.y, 0.25 * sin(_held_t * 3.0))


## Turn to face a direction without walking (used when casting and fighting).
func face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		facing = dir.normalized()


## Hold a catch up over your head, facing the camera.
func show_off(tex: Texture2D, tint := Color.WHITE) -> void:
	pose = "cheer"
	_held.texture = tex
	_held.modulate = tint
	if tex:
		_held.offset = Vector2.ZERO
	_held.visible = tex != null
	_held_t = 0.0


## Hold a 3D catch up over your head, side on to the camera.
func show_off_model(model: Node3D) -> void:
	pose = "cheer"
	_held.texture = null
	_held.visible = true
	for c in _held.get_children():
		c.queue_free()
	_held.add_child(model)
	model.position = Vector3(0.0, 0.15, 0.0)
	_held_t = 0.0


func hide_held() -> void:
	_held.visible = false
	for c in _held.get_children():
		c.queue_free()
	pose = ""


# --- swimming ------------------------------------------------------------------------

func _set_swimming(on: bool) -> void:
	if on == swimming:
		return
	swimming = on
	_ripple.visible = on
	if on:
		pose = ""
		_held.visible = false
		if audio:
			audio.play("splash", -4.0, 1.0, 0.1)


func _swim(delta: float, move: Vector3, input: Vector2, wl: float, ground: float) -> void:
	var vel := Vector3.ZERO
	if _moving:
		facing = move.normalized()
		var ahead := global_position + move.normalized() * 0.6
		if _swim_ok(ahead):
			vel = move * SWIM_SPEED
		else:
			# slide along whatever's in the way
			var along_a := Vector3(move.x, 0.0, 0.0)
			var along_b := Vector3(0.0, 0.0, move.z)
			if absf(move.x) > 0.05 and _swim_ok(global_position + along_a.normalized() * 0.6):
				vel = along_a * SWIM_SPEED
			elif absf(move.z) > 0.05 and _swim_ok(global_position + along_b.normalized() * 0.6):
				vel = along_b * SWIM_SPEED
		_walk_t += delta * 4.0 * input.length()
		_stroke_t -= delta
		if _stroke_t <= 0.0 and audio:
			_stroke_t = 0.55
			audio.play("plop", -16.0, 0.8, 0.15)
	else:
		_walk_t = 0.0
	velocity.x = vel.x
	velocity.z = vel.z
	velocity.y = clampf((wl - global_position.y) * 6.0, -3.0, 4.0)  # bob up to the surface
	move_and_slide()
	_ripple.global_position = Vector3(global_position.x, wl + 0.02, global_position.z)
	# haul yourself out onto a dock, a quay or a rock you're pushing against
	if _moving:
		_push_t += delta if vel.length() < 0.5 or is_on_wall() else -delta
		_push_t = maxf(_push_t, 0.0)
		if _push_t > 0.25 and _try_climb(move.normalized(), wl):
			return
	else:
		_push_t = 0.0
	# wade out where it's shallow enough to stand
	var here: float = harbour.height_at(global_position.x, global_position.z)
	if here > wl - SWIM_DEPTH + 0.15:
		_set_swimming(false)
		global_position.y = maxf(global_position.y, here)


## Can you swim (or wade out) here? Not into open sea, nor anywhere locked.
func _swim_ok(p: Vector3) -> bool:
	if not harbour.walkable(p.x, p.z):
		return false
	if harbour.is_water(p.x, p.z) and int(harbour.tier_at(p.x, p.z)) > 1:
		if _swim_warn_t <= 0.0:
			_swim_warn_t = 5.0
			gate_blocked.emit("The current's too strong out there. Swim back to shore, or take a boat.")
		return false
	return true


func _try_climb(dir: Vector3, wl: float) -> bool:
	var space := get_world_3d().direct_space_state
	for reach in [0.7, 1.0]:
		var p: Vector3 = global_position + dir * reach
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, wl + CLIMB + 1.0, p.z), Vector3(p.x, wl - 2.0, p.z), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var top: Vector3 = hit.position
		if top.y < wl + 0.15 or top.y > wl + CLIMB:
			continue
		if not harbour.walkable(top.x, top.z):
			continue
		global_position = top + Vector3(0.0, 0.05, 0.0)
		velocity = Vector3.ZERO
		_set_swimming(false)
		_push_t = 0.0
		if audio:
			audio.play("step_wood", -4.0)
			audio.play("splash", -12.0, 1.3)
		return true
	return false


# --- walking -------------------------------------------------------------------------

## Walk freely on land, docks and the shallows; slide along the edge of deeper water.
## Walking into a low ledge (a step, a kerb, the edge of a dock)? Lift onto it, the way
## feet would, rather than stopping dead against it. Walls and anything taller stay put.
func _step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if hit.get_normal().y > 0.7:
		return  # a slope: sliding handles it
	var up := Vector3(0.0, STEP_UP, 0.0)
	if test_move(global_transform, up):
		return  # no headroom
	# far enough on that the feet are over the step, not on its edge
	var ahead := motion.normalized() * maxf(motion.length(), 0.34)
	var raised := global_transform.translated(up)
	if test_move(raised, ahead):
		return  # taller than a step
	var down := KinematicCollision3D.new()
	var over := raised.translated(ahead)
	if not test_move(over, -up, down):
		return  # nothing to stand on up there (a gap, not a step)
	if down.get_normal().y < 0.75:
		return  # the "step" is a steep face: a cliff you'd climb a stride at a time
	var lift: float = STEP_UP - absf(down.get_travel().y)
	if lift > 0.02:
		global_position.y += lift + 0.01


func _keep_on_land(vel: Vector3) -> Vector3:
	var probe := 0.45
	# standing somewhere too deep already (the tide came in)? Any way that's no deeper is fine
	var here := _ground_y(global_position)
	if _ground_at(global_position + vel.normalized() * probe, here):
		return vel
	var along_a := Vector3(vel.x, 0.0, 0.0)
	var along_b := Vector3(0.0, 0.0, vel.z)
	if absf(vel.x) > 0.05 and _ground_at(global_position + along_a.normalized() * probe, here):
		return along_a
	if absf(vel.z) > 0.05 and _ground_at(global_position + along_b.normalized() * probe, here):
		return along_b
	return Vector3.ZERO


## The height of whatever you'd stand on at p (dock, quay or ground), or -INF.
func _ground_y(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -4.0, 0.0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -INF
	var at: Vector3 = hit.position
	return at.y


## Is there ground here that's dry or shallow enough to wade (or no deeper than where
## you're standing now)?
func _ground_at(p: Vector3, here := -INF) -> bool:
	if harbour and not harbour.walkable(p.x, p.z):
		if _gate_t <= 0.0:
			_gate_t = 4.0
			gate_blocked.emit(str(harbour.gate_text(p.x, p.z)))
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -4.0, 0.0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var at: Vector3 = hit.position
	var water: float = harbour.water_level_at(p.x, p.z) if harbour else 0.0
	return at.y > water - WADE or (here > -INF and at.y >= here - 0.02)
