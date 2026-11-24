extends CharacterBody3D
## The fisher: a pixel-art billboard that walks relative to the camera over land, docks
## and the shallows (knee-deep wading is fine, deeper water isn't), shows the right side
## of itself whichever way the camera turns, and holds each catch up for the camera.

const Billboard := preload("res://scripts/billboard.gd")

const SPEED := 4.4
const GRAVITY := 20.0
const PIXEL := 1.0 / 26.0  # 48 px frames, about 1.6 m tall
const WADE := 0.35  # how deep you can walk into the water
const COLS := 5  # stand, walk A, walk B, cast, cheer
const WALK := [0, 1, 0, 2]

signal gate_blocked(text: String)  # walked into somewhere locked (with why)

var facing := Vector3(0.0, 0.0, -1.0)  # world direction you last walked or turned to
var can_move := true
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


func _physics_process(delta: float) -> void:
	_gate_t = maxf(0.0, _gate_t - delta)
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
		_last_safe = global_position
	else:
		velocity.y -= GRAVITY * delta
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
	sprite.frame = row * COLS + col
	if _held.visible:
		_held_t += delta
		_held.position.y = 2.15 + absf(sin(_held_t * 5.0)) * 0.08


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


func hide_held() -> void:
	_held.visible = false
	pose = ""


## Walk freely on land, docks and the shallows; slide along the edge of deeper water.
func _keep_on_land(vel: Vector3) -> Vector3:
	var probe := 0.45
	if _ground_at(global_position + vel.normalized() * probe):
		return vel
	var along_a := Vector3(vel.x, 0.0, 0.0)
	var along_b := Vector3(0.0, 0.0, vel.z)
	if absf(vel.x) > 0.05 and _ground_at(global_position + along_a.normalized() * probe):
		return along_a
	if absf(vel.z) > 0.05 and _ground_at(global_position + along_b.normalized() * probe):
		return along_b
	return Vector3.ZERO


## Is there ground here that's dry or shallow enough to wade?
func _ground_at(p: Vector3) -> bool:
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
	return at.y > water - WADE
