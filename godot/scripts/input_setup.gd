extends RefCounted
## Sets up the controls in code, so the project needs no hand-edited input map.
## Keyboard and mouse:
##   WASD / arrows walk (relative to the camera), Q / E turn the camera (or drag with the
##   right mouse button), mouse wheel or - / = zooms.
##   Space, F or left click: cast, reel, talk, open doors, board boats, dig.
##   Esc: reel in early, close menus (or open the game menu). R bait, Tab or L Logbook,
##   J Journal, M map, B build, I bag, G kit (pots, net, trolling, speargun).
## Gamepad:
##   Left stick walks, right stick turns and zooms the camera, bumpers turn in steps.
##   A acts, B cancels, Y bait, X kit (or build, in your hut), Start the game menu, Back the map,
##   D-pad up Journal (or click the left stick), left Logbook, right bag.
## Keys can be changed in the game menu (Controls); the changes live in settings.cfg.

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
	"journal": [KEY_J],
	"build": [KEY_B],
	"bag": [KEY_I],
	"tool": [KEY_G],
	"menu": [KEY_ESCAPE],
}
# the ones you can change in Controls, in the order they're listed
# (Esc always stays back / menu, so there's always a way out)
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "action", "rotate_left", "rotate_right",
	"bait", "tool", "bag", "journal", "logbook", "map", "build", "time_skip", "photo"]
const NAMES := {"move_up": "Walk up", "move_down": "Walk down", "move_left": "Walk left", "move_right": "Walk right",
	"action": "Cast, reel, talk, use", "rotate_left": "Turn camera left",
	"rotate_right": "Turn camera right", "bait": "Change bait", "tool": "Use your kit (pots, net...)", "bag": "Bag", "journal": "Journal", "logbook": "Logbook",
	"map": "Map", "build": "Arrange your hut", "time_skip": "Skip an hour", "photo": "Hide the HUD"}


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
	_pad_button("tool", JOY_BUTTON_X)
	_pad_button("menu", JOY_BUTTON_START)
	_pad_button("map", JOY_BUTTON_BACK)
	_pad_button("journal", JOY_BUTTON_DPAD_UP)
	_pad_button("journal", JOY_BUTTON_LEFT_STICK)
	_pad_button("logbook", JOY_BUTTON_DPAD_LEFT)
	_pad_button("bag", JOY_BUTTON_DPAD_RIGHT)
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


## The first keyboard key on an action (the one prompts show).
static func primary(action: String) -> int:
	if not InputMap.has_action(action):
		return KEY_NONE
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return int((ev as InputEventKey).physical_keycode)
	return KEY_NONE


## Which other action has this key first, if any.
static func action_with(code: int, besides: String) -> String:
	for a in REBINDABLE:
		if a != besides and primary(a) == code:
			return a
	return ""


## Put a key first on an action. It comes off every other action; the action keeps its
## other usual keys (arrows, Tab...) unless something else now uses them.
static func rebind(action: String, code: int) -> void:
	for a in KEYS:
		if a != action and a != "menu":
			_drop_key(a, code)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	_add_key(action, code)
	var defaults: Array = KEYS.get(action, [])
	for i in range(1, defaults.size()):
		var k := int(defaults[i])
		if k != code and _owner_of(k) == "":
			_add_key(action, k)


## Every key back to how it started.
static func reset_keys() -> void:
	for a in KEYS:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				InputMap.action_erase_event(a, ev)
		for k in KEYS[a]:
			_add_key(a, int(k))


static func _add_key(action: String, code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	InputMap.action_add_event(action, ev)


static func _drop_key(action: String, code: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
			InputMap.action_erase_event(action, ev)


static func _owner_of(code: int) -> String:
	for a in KEYS:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
				return a
	return ""
