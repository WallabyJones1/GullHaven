extends Node
## Button prompts that match what you're playing with. Keeps track of whether you last used
## the keyboard and mouse or a gamepad (and which kind of pad), and turns prompt text into
## the right key names: "{action} Talk to Hale" reads "[Space] Talk to Hale" on a keyboard
## and "(A) Talk to Hale" on an Xbox pad, "(Cross)" on a PlayStation pad.
## Older prompt text ("Space: ...", "Esc to ...") is translated too.
## Labels registered with bind() update themselves when you switch devices.

static var device := "keyboard"  # or "pad"
static var pad_style := "xbox"  # xbox, playstation or nintendo
static var _bound: Array = []  # [label, raw text]
static var version := 0  # goes up when the device or a key changes, so cached prompts redraw

const PAD := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3",
		JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"},
	"playstation": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
		JOY_BUTTON_DPAD_RIGHT: "D-pad right"},
	"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L",
		JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_BACK: "-", JOY_BUTTON_START: "+", JOY_BUTTON_LEFT_STICK: "L-stick",
		JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"},
}
const PAD_COLOURS := {"A": "#3aa84a", "B": "#d0453a", "X": "#3a7ad8", "Y": "#e0b030", "Cross": "#5a8ad8", "Circle": "#d0453a",
	"Square": "#c86ab8", "Triangle": "#3aa88a"}
# words that aren't single actions
const PSEUDO_KEYS := {"move": "WASD", "camera": "Q/E", "zoom": "Wheel or - / =", "updown": "Up/Down", "leftright": "Left/Right", "arrows": "Arrows"}
const PSEUDO_PAD := {"move": "Left stick", "camera": "Right stick", "zoom": "Right stick", "updown": "D-pad", "leftright": "D-pad", "arrows": "D-pad"}
# old prompt wording -> tokens (order matters)
const LEGACY := [
	["Hold Space", "Hold {action}"], ["Press Space", "{action}"], ["Space: ", "{action} "], ["Space when", "{action} when"],
	["Space", "{action}"], ["Esc: ", "{cancel} "], ["Esc to", "{cancel} to"], ["Esc", "{cancel}"],
	["(or press B)", "(or {build})"], ["press B", "press {build}"], ["Q/E: ", "{camera} "], ["Q / E", "{camera}"],
	["Q/E", "{camera}"], ["(J)", "({journal})"], ["(M)", "({map})"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_style()


func _input(event: InputEvent) -> void:
	var was := device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		device = "pad"
		_pick_style()
	elif event is InputEventKey or event is InputEventMouseButton:
		device = "keyboard"
	if device != was:
		refresh()


static func _pick_style() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var n := Input.get_joy_name(pads[0]).to_lower()
	if n.contains("ps") or n.contains("dualsense") or n.contains("dualshock") or n.contains("playstation") or n.contains("sony"):
		pad_style = "playstation"
	elif n.contains("nintendo") or n.contains("switch") or n.contains("joy-con"):
		pad_style = "nintendo"
	else:
		pad_style = "xbox"


## The name of the key or button for an action on the current device.
static func key(action: String) -> String:
	if device == "pad":
		if PSEUDO_PAD.has(action):
			return PSEUDO_PAD[action]
		var names: Dictionary = PAD[pad_style]
		var evs: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		for ev in evs:
			if ev is InputEventJoypadButton and names.has((ev as InputEventJoypadButton).button_index):
				return str(names[(ev as InputEventJoypadButton).button_index])
		if action.begins_with("move_"):
			return "Left stick"
		if action.begins_with("rotate_") or action.begins_with("zoom_"):
			return "Right stick"
		return action
	if PSEUDO_KEYS.has(action):
		return PSEUDO_KEYS[action]
	if not InputMap.has_action(action):
		return action
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var s := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
			return {"Escape": "Esc", "BackSpace": "Backspace", "Equal": "=", "Minus": "-"}.get(s, s)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			return "Click"
	return action


## A key name dressed up as a keycap (for RichTextLabel bbcode).
static func cap(action: String) -> String:
	var k := key(action)
	if device == "pad" and PAD_COLOURS.has(k):
		return "[bgcolor=%s][color=#ffffff][b] %s [/b][/color][/bgcolor]" % [PAD_COLOURS[k], k]
	return "[bgcolor=#e8dcc0][color=#1a1c2a][b] %s [/b][/color][/bgcolor]" % k


static func _tokens(text: String) -> String:
	var out := text
	if not out.contains("{"):
		for pair in LEGACY:
			out = out.replace(str(pair[0]), str(pair[1]))
	return out


## Prompt text with keycaps (bbcode).
static func fmt(text: String) -> String:
	var out := _tokens(text)
	var i := out.find("{")
	while i >= 0:
		var j := out.find("}", i)
		if j < 0:
			break
		var action := out.substr(i + 1, j - i - 1)
		var c := cap(action)
		out = out.substr(0, i) + c + out.substr(j + 1)
		i = out.find("{", i + c.length())
	return out


## Prompt text with plain key names, for ordinary labels and toasts.
static func plain(text: String) -> String:
	var out := _tokens(text)
	var i := out.find("{")
	while i >= 0:
		var j := out.find("}", i)
		if j < 0:
			break
		var k := key(out.substr(i + 1, j - i - 1))
		out = out.substr(0, i) + k + out.substr(j + 1)
		i = out.find("{", i + k.length())
	return out


## Keep a label's hint text in step with the device you're using.
static func bind(label: Label, raw: String) -> Label:
	label.text = plain(raw)
	_bound.append([label, raw])
	return label


static func refresh() -> void:
	version += 1
	var keep: Array = []
	for pair in _bound:
		var l: Variant = pair[0]
		if is_instance_valid(l):
			(l as Label).text = plain(str(pair[1]))
			keep.append(pair)
	_bound = keep
