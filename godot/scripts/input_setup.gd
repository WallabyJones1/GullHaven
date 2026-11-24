extends RefCounted
## Sets up the controls in code, so the project needs no hand-edited input map.
## Keyboard: WASD/arrows to walk, E/Space/left click to cast, reel, talk and shop, Esc/Q to
## cancel, R to change bait, L or Tab for the Logbook.
## Gamepad: left stick to walk, A to cast and reel, B to cancel, Y for bait, Back for the Logbook.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"action": [KEY_E, KEY_SPACE],
	"cancel": [KEY_ESCAPE, KEY_Q],
	"time_skip": [KEY_T],
	"quality": [KEY_F2],
	"photo": [KEY_P],
	"bait": [KEY_R],
	"logbook": [KEY_L, KEY_TAB],
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
	_pad_button("action", JOY_BUTTON_A)
	_pad_button("cancel", JOY_BUTTON_B)
	_pad_button("bait", JOY_BUTTON_Y)
	_pad_button("logbook", JOY_BUTTON_BACK)
	# E also presses the focused button in menus (Enter, Space and pad A already do).
	var accept := InputEventKey.new()
	accept.physical_keycode = KEY_E
	InputMap.action_add_event("ui_accept", accept)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


static func _pad_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


static func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
