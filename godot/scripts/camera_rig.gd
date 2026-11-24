extends Camera3D
## The diorama camera: high and a little telephoto, following the fisher smoothly,
## keeping the tilt-shift focus on them, and leaning in toward the line in a fight.

const OFFSET := Vector3(0.0, 9.5, 13.0)
const LOOK_HEIGHT := 0.8

var target: Node3D
var _attrs: CameraAttributesPractical
var _focus := Vector3.ZERO
var _has_focus := false
var _zoom := 1.0
var _zoom_goal := 1.0
var _pos := Vector3.ZERO
var _shake := 0.0


func setup(follow: Node3D, attr: CameraAttributes) -> void:
	target = follow
	_attrs = attr as CameraAttributesPractical
	fov = 30.0
	near = 0.5
	far = 400.0
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


func _process(delta: float) -> void:
	if target:
		_place(delta)


func _place(delta: float) -> void:
	var goal := target.global_position
	if _has_focus:
		goal = goal.lerp(Vector3(_focus.x, goal.y, _focus.z), 0.4)
	var follow := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 4.0)
	_pos = _pos.lerp(goal, follow)
	var blend := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 2.5)
	_zoom = lerpf(_zoom, _zoom_goal, blend)
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		jitter = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.12
		_shake = maxf(_shake - delta * 2.5, 0.0)
	var look := _pos + Vector3(0.0, LOOK_HEIGHT, 0.0)
	global_position = look + OFFSET * _zoom + jitter
	look_at(look + jitter, Vector3.UP)
	if _attrs:
		var d := OFFSET.length() * _zoom
		_attrs.dof_blur_far_distance = d + 9.0
		_attrs.dof_blur_near_distance = maxf(d - 8.0, 1.0)
