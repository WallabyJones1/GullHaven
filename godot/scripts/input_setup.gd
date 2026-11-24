extends RefCounted
## Sets up the controls in code, so the project needs no hand-edited input map.
## Keyboard and mouse:
##   WASD / arrows walk (relative to the camera), Q / E turn the camera (or drag with the
##   right mouse button), mouse wheel or - / = zooms.
##   Space, F or left click: cast, reel, talk, open doors, board boats, dig.
##   Esc: reel in early, close menus. R bait, Tab or L Logbook, M map, B build, I bag.
## Gamepad:
##   Left stick walks, right stick turns and zooms the camera, bumpers turn in steps.
##   A acts, B cancels, Y bait, X build, Back Logbook, Start map.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"action": [KEY_SPACE, KEY_F],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"rotate_left": [KEY_Q],
	"rotate_right": [KEY_E],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"time_skip": [KEY_T],
	"quality": [KEY_F2],
	"photo": [KEY_P],
	"bait": [KEY_R],
	"logbook": [KEY_L, KEY_TAB],
	"map": [KEY_M],
	"build": [KEY_B],
	"bag": [KEY_I],
}


static func setup() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for keycode in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("action", click)
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("zoom_in", wheel_up)
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("zoom_out", wheel_down)
	_pad_button("action", JOY_BUTTON_A)
	_pad_button("cancel", JOY_BUTTON_B)
	_pad_button("bait", JOY_BUTTON_Y)
	_pad_button("build", JOY_BUTTON_X)
	_pad_button("logbook", JOY_BUTTON_BACK)
	_pad_button("map", JOY_BUTTON_START)
	_pad_button("rotate_left", JOY_BUTTON_LEFT_SHOULDER)
	_pad_button("rotate_right", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("rotate_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("rotate_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("zoom_in", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("zoom_out", JOY_AXIS_RIGHT_Y, 1.0)
	# Space, F and E press the focused button in menus (Enter and pad A already do).
	for k in [KEY_F, KEY_E]:
		var accept := InputEventKey.new()
		accept.physical_keycode = k
		InputMap.action_add_event("ui_accept", accept)


static func _pad_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


static func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
