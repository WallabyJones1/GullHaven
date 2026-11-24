extends Camera3D
## The diorama camera: high and a little telephoto, following the fisher smoothly. You can
## turn it all the way round (Q / E, a gamepad's bumpers or right stick, or drag with the
## right mouse button) and zoom (mouse wheel, - / =, right stick). It keeps the tilt-shift
## focus on the fisher and leans in toward the line during a fight, and rises over hills
## rather than burying itself in them.

const PITCH := deg_to_rad(36.0)
const LOOK_HEIGHT := 0.8
const DIST_MIN := 7.0
const DIST_MAX := 34.0
const TURN_SPEED := 2.2  # radians per second when held
const DRAG_SPEED := 0.006  # radians per pixel of right-mouse drag

var target: Node3D
var terrain: Node3D  # the world, for keeping the camera above the ground
var yaw := 0.0  # 0 looks north (toward -Z)
var distance := 16.0
var indoor := false  # tighter, lower framing inside buildings
var _attrs: CameraAttributesPractical
var _yaw_goal := 0.0
var _dist_goal := 16.0
var _focus := Vector3.ZERO
var _has_focus := false
var _zoom := 1.0
var _zoom_goal := 1.0
var _pos := Vector3.ZERO
var _shake := 0.0
var _dragging := false
var _lift := 0.0


func setup(follow: Node3D, attr: CameraAttributes) -> void:
	target = follow
	_attrs = attr as CameraAttributesPractical
	fov = 30.0
	near = 0.4
	far = 600.0
	current = true
	_pos = target.global_position
	_place(0.0)


## Frame both the fisher and `point` (the bobber), a little closer than usual.
func set_focus(on: bool, point := Vector3.ZERO, zoom := 0.82) -> void:
	_has_focus = on
	_focus = point
	_zoom_goal = zoom if on else 1.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Jump straight to the target (after a door or a fast trip), no easing.
func snap() -> void:
	if target:
		_pos = target.global_position
	yaw = _yaw_goal
	distance = _dist_goal
	_place(0.0)


## Turn to face a direction (radians, 0 = looking north) straight away on the next snap().
func set_yaw(y: float) -> void:
	_yaw_goal = y
	yaw = y


## Camera-relative directions on the ground: right and forward (away from the camera).
func ground_right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func ground_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_yaw_goal -= event.relative.x * DRAG_SPEED
		if indoor:
			_yaw_goal = clampf(_yaw_goal, -0.55, 0.55)


func _process(delta: float) -> void:
	if not target:
		return
	var turn := Input.get_axis("rotate_left", "rotate_right")
	_yaw_goal += turn * TURN_SPEED * delta
	if indoor:
		_yaw_goal = clampf(_yaw_goal, -0.55, 0.55)  # rooms are open only at the front
	if Input.is_action_just_pressed("zoom_in"):
		_dist_goal = maxf(DIST_MIN, _dist_goal * 0.88)
	if Input.is_action_just_pressed("zoom_out"):
		_dist_goal = minf(DIST_MAX, _dist_goal / 0.88)
	# Held stick zoom.
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(stick) > 0.3:
		_dist_goal = clampf(_dist_goal * (1.0 + stick * delta * 1.2), DIST_MIN, DIST_MAX)
	_place(delta)


func _place(delta: float) -> void:
	var goal := target.global_position
	if _has_focus:
		goal = goal.lerp(Vector3(_focus.x, goal.y, _focus.z), 0.4)
	var follow := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 5.0)
	_pos = _pos.lerp(goal, follow)
	var ease_k := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 8.0)
	yaw = lerp_angle(yaw, _yaw_goal, ease_k)
	distance = lerpf(distance, _dist_goal, 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 6.0))
	var blend := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 2.5)
	_zoom = lerpf(_zoom, _zoom_goal, blend)
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		jitter = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.12
		_shake = maxf(_shake - delta * 2.5, 0.0)
	var d := distance * _zoom * (0.6 if indoor else 1.0)
	var pitch := PITCH + (deg_to_rad(8.0) if indoor else 0.0)
	var back := -ground_forward()
	var offset := back * cos(pitch) * d + Vector3.UP * sin(pitch) * d
	var look := _pos + Vector3(0.0, LOOK_HEIGHT, 0.0)
	# Rise over any hill between the camera and the fisher (outdoors).
	var need := 0.0
	if terrain and not indoor:
		for t in [0.35, 0.65, 1.0]:
			var p: Vector3 = look + offset * t
			var ground: float = terrain.height_at(p.x, p.z) + 1.4
			need = maxf(need, (ground - p.y) / t)
	var rise := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * (10.0 if need > _lift else 2.0))
	_lift = lerpf(_lift, need, rise)
	global_position = look + offset + Vector3.UP * _lift + jitter
	look_at(look + jitter, Vector3.UP)
	if _attrs:
		_attrs.dof_blur_far_distance = d + 9.0 + d * 0.3
		_attrs.dof_blur_near_distance = maxf(d - 8.0, 1.0)
