extends CharacterBody3D
## The fisher: a pixel-art billboard that walks in four directions over land and
## docks (never into the sea), and holds each catch up for the camera.

const SPEED := 4.2
const GRAVITY := 20.0
const PIXEL := 1.0 / 16.0
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3
const WALK := [0, 1, 0, 2]  # stand, step, stand, other step

var facing := Vector3(0.0, 0.0, 1.0)  # last walking direction (8-way), used for casting
var can_move := true
var harbour: Node3D  # for the waterline and what's underfoot
var audio: Node
var _last_step := 0
var sprite: Sprite3D
var _row := ROW_DOWN
var _saved_row := ROW_DOWN
var _walk_t := 0.0
var _held: Sprite3D
var _held_t := 0.0
var _last_safe := Vector3.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.3
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.65
	add_child(col)

	sprite = _make_sprite(load("res://art/chars/player.png"))
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.offset = Vector2(0.0, 13.0)  # feet on the ground (frames are 26 px tall)
	add_child(sprite)

	_held = _make_sprite(null)
	_held.pixel_size = 1.0 / 24.0
	_held.position.y = 2.25
	_held.visible = false
	add_child(_held)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := Vector3(input.x, 0.0, input.y)
	var moving := move.length() > 0.1
	if moving:
		facing = move.normalized()
		_row = _row_for(move)
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
	if global_position.y < -1.0:
		global_position = _last_safe  # never end up in the sea
		velocity = Vector3.ZERO
	var step: int = WALK[int(_walk_t) % 4] if moving else 0
	sprite.frame = _row * 3 + step
	if step != 0 and step != _last_step and audio and harbour:
		var surface: String = harbour.surface_at(global_position.x, global_position.z)
		audio.play("step_" + surface, -10.0, 1.0, 0.12)
	_last_step = step


func _process(delta: float) -> void:
	if _held.visible:
		_held_t += delta
		_held.position.y = 2.25 + absf(sin(_held_t * 5.0)) * 0.08


## Turn to face a direction without walking (used when casting and fighting).
func face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	facing = dir.normalized()
	_row = _row_for(dir)
	sprite.frame = _row * 3


## Hold a catch up over your head, facing the camera.
func show_off(tex: Texture2D, tint := Color.WHITE) -> void:
	_saved_row = _row
	_row = ROW_DOWN
	sprite.frame = ROW_DOWN * 3
	_held.texture = tex
	_held.modulate = tint
	_held.visible = tex != null
	_held_t = 0.0


func hide_held() -> void:
	_held.visible = false
	_row = _saved_row
	sprite.frame = _row * 3


func _row_for(dir: Vector3) -> int:
	if absf(dir.x) > absf(dir.z):
		return ROW_LEFT if dir.x < 0.0 else ROW_RIGHT
	return ROW_UP if dir.z < 0.0 else ROW_DOWN


## Walk freely on land and docks; slide along the water's edge instead of stepping off.
func _keep_on_land(vel: Vector3) -> Vector3:
	var probe := 0.4
	if _ground_at(global_position + vel.normalized() * probe):
		return vel
	var along_x := Vector3(vel.x, 0.0, 0.0)
	var along_z := Vector3(0.0, 0.0, vel.z)
	if absf(vel.x) > 0.05 and _ground_at(global_position + along_x.normalized() * probe):
		return along_x
	if absf(vel.z) > 0.05 and _ground_at(global_position + along_z.normalized() * probe):
		return along_z
	return Vector3.ZERO


## Is there solid ground above the waterline at this spot?
func _ground_at(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 1.0, 0.0), p + Vector3(0.0, -1.0, 0.0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var at: Vector3 = hit.position
	var water: float = harbour.sea_level if harbour else 0.0
	return at.y > water + 0.05


func _make_sprite(tex: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return s
