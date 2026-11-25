extends CanvasLayer
## Touch controls for phones and tablets (and touchscreen laptops): a thumbstick bottom left
## to walk, big buttons bottom right (A: cast, reel, talk, use; B: back), smaller ones for
## the kit, bait, bag, map, journal, chat, emotes and the game menu. Drag anywhere else to
## turn the camera; pinch to zoom. Shown on touch devices (Settings can force it on or off),
## and hidden while a full-screen menu is open (menus take taps directly).

const UI := preload("res://scripts/ui_kit.gd")

const STICK_R := 92.0
const KNOB_R := 40.0
const BIG := 66.0
const SMALL := 40.0

var main: Node
var enabled := false
var _stick_center := Vector2.ZERO
var _stick_touch := -1
var _stick_vec := Vector2.ZERO
var _cam_touches := {}  # index -> last position
var _pinch_d := 0.0
var _buttons: Array = []  # {node, action, label}
var _root: Node2D
var _stick_bg: Sprite2D
var _knob: Sprite2D


static func is_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		return true
	return false


func setup(m: Node) -> void:
	main = m
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Node2D.new()
	add_child(_root)
	_stick_bg = _circle_sprite(STICK_R, Color(0.07, 0.09, 0.17, 0.45), Color(0.96, 0.86, 0.62, 0.7))
	_root.add_child(_stick_bg)
	_knob = _circle_sprite(KNOB_R, Color(1.0, 0.84, 0.45, 0.75), Color(0.04, 0.05, 0.1, 0.8))
	_root.add_child(_knob)
	_add_button("action", "A", BIG, Color(0.45, 0.85, 0.5))
	_add_button("cancel", "B", BIG * 0.78, Color(0.95, 0.5, 0.45))
	_add_button("tool", "Kit", SMALL, Color(0.5, 0.7, 1.0))
	_add_button("bait", "Bait", SMALL, Color(0.95, 0.8, 0.4))
	_add_button("menu", "Menu", SMALL, Color(0.85, 0.85, 0.9))
	_add_button("map", "Map", SMALL, Color(0.85, 0.85, 0.9))
	_add_button("bag", "Bag", SMALL, Color(0.85, 0.85, 0.9))
	_add_button("journal", "Jrnl", SMALL, Color(0.85, 0.85, 0.9))
	_add_button("build", "Build", SMALL, Color(0.85, 0.75, 0.6))
	_add_button("chat", "Chat", SMALL, Color(0.6, 0.9, 1.0))
	_add_button("emote", "Wave", SMALL, Color(1.0, 0.7, 0.85))
	get_viewport().size_changed.connect(_layout)
	var mode := str(main.menus.settings.get("touch", "auto"))
	set_enabled(mode == "on" or (mode == "auto" and is_touch_device()))
	_layout()


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	# on a touch screen a tap is a tap on the UI or the camera, never a cast: the A button casts
	for ev in InputMap.action_get_events("action"):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			InputMap.action_erase_event("action", ev)
	if not on:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("action", click)
		_release_stick()


func _circle_texture(r: float, fill: Color, edge: Color) -> ImageTexture:
	var s := int(ceil(r * 2.0)) + 4
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r - 3.0:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


func _circle_sprite(r: float, fill: Color, edge: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _circle_texture(r, fill, edge)
	return sp


func _add_button(action: String, text: String, r: float, tint: Color) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_texture(r, Color(tint.r, tint.g, tint.b, 0.5), Color(0.04, 0.05, 0.1, 0.85))
	b.texture_pressed = _circle_texture(r, Color(tint.r, tint.g, tint.b, 0.85), Color(1.0, 0.95, 0.7, 1.0))
	var shape := CircleShape2D.new()
	shape.radius = r
	b.shape = shape
	b.shape_centered = true
	b.passby_press = action == "action"
	if action in ["chat", "emote"]:
		b.pressed.connect(_special.bind(action))
	else:
		b.action = action
	_root.add_child(b)
	var l := UI.label(text, 18 if r < BIG else 26, UI.CREAM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(r * 2.0, r * 2.0)
	b.add_child(l)
	_buttons.append({"node": b, "action": action, "r": r})


func _special(what: String) -> void:
	var online: Node = main.online
	match what:
		"chat":
			if online.is_online():
				online._open_line()
			else:
				main.hud.toast("Join the shared town to chat (game menu, Online).")
		"emote":
			online.emote("wave")


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_stick_center = Vector2(STICK_R + 40.0, vp.y - STICK_R - 90.0)
	_stick_bg.position = _stick_center
	_knob.position = _stick_center + _stick_vec * STICK_R
	# the big two bottom right, the rest in an arc above them
	var spots := {
		"action": Vector2(vp.x - BIG - 40.0, vp.y - BIG - 110.0),
		"cancel": Vector2(vp.x - BIG * 2.6 - 40.0, vp.y - BIG * 0.8 - 70.0),
		"tool": Vector2(vp.x - BIG * 2.7 - 40.0, vp.y - BIG * 2.3 - 100.0),
		"bait": Vector2(vp.x - BIG - 40.0, vp.y - BIG * 3.0 - 110.0),
		"build": Vector2(vp.x - BIG * 3.9 - 40.0, vp.y - BIG * 1.4 - 80.0),
		"menu": Vector2(vp.x - SMALL - 24.0, 260.0),
		"map": Vector2(vp.x - SMALL * 3.4 - 24.0, 260.0),
		"bag": Vector2(vp.x - SMALL * 5.8 - 24.0, 260.0),
		"journal": Vector2(vp.x - SMALL * 8.2 - 24.0, 260.0),
		"chat": Vector2(STICK_R * 2.0 + 90.0, vp.y - SMALL - 40.0),
		"emote": Vector2(STICK_R * 2.0 + 90.0 + SMALL * 2.6, vp.y - SMALL - 40.0),
	}
	for b in _buttons:
		var node: TouchScreenButton = b.node
		var at: Vector2 = spots.get(str(b.action), Vector2.ZERO)
		node.position = at - Vector2(float(b.r), float(b.r))
		var l: Label = node.get_child(0)
		l.position = Vector2.ZERO


func _process(_delta: float) -> void:
	if not enabled:
		return
	var paused := get_tree().paused
	var in_menu := str(main.menus.mode) != ""
	_root.visible = not paused and not in_menu and main.hud.visible
	if not _root.visible:
		_release_stick()
		_cam_touches.clear()
	for b in _buttons:
		if str(b.action) == "chat" or str(b.action) == "emote":
			(b.node as TouchScreenButton).visible = main.online.is_online()


func _input(event: InputEvent) -> void:
	if not enabled or not _root.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.distance_to(_stick_center) < STICK_R * 1.4 and _stick_touch < 0:
				_stick_touch = t.index
				_move_stick(t.position)
			elif not _on_button(t.position) and t.position.x > get_viewport().get_visible_rect().size.x * 0.3:
				_cam_touches[t.index] = t.position
				_pinch_d = _pinch_distance()
		else:
			if t.index == _stick_touch:
				_release_stick()
			_cam_touches.erase(t.index)
			_pinch_d = _pinch_distance()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			_move_stick(d.position)
		elif _cam_touches.has(d.index):
			var cam: Node = main.cam
			if _cam_touches.size() >= 2:
				_cam_touches[d.index] = d.position
				var nd := _pinch_distance()
				if _pinch_d > 10.0 and nd > 10.0:
					cam.call("zoom_by", _pinch_d / nd)
				_pinch_d = nd
			else:
				var last: Vector2 = _cam_touches[d.index]
				cam.set("_yaw_goal", float(cam.get("_yaw_goal")) - (d.position.x - last.x) * 0.006)
				_cam_touches[d.index] = d.position


func _pinch_distance() -> float:
	var pts: Array = _cam_touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _on_button(p: Vector2) -> bool:
	for b in _buttons:
		var node: TouchScreenButton = b.node
		if node.visible and p.distance_to(node.position + Vector2(float(b.r), float(b.r))) < float(b.r) + 8.0:
			return true
	return false


func _move_stick(p: Vector2) -> void:
	var v := (p - _stick_center) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vec = v
	_knob.position = _stick_center + v * STICK_R
	_apply("move_left", maxf(0.0, -v.x))
	_apply("move_right", maxf(0.0, v.x))
	_apply("move_up", maxf(0.0, -v.y))
	_apply("move_down", maxf(0.0, v.y))


func _apply(action: String, k: float) -> void:
	if k > 0.15:
		Input.action_press(action, clampf(k, 0.0, 1.0))
	else:
		Input.action_release(action)


func _release_stick() -> void:
	_stick_touch = -1
	_stick_vec = Vector2.ZERO
	if _knob:
		_knob.position = _stick_center
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
