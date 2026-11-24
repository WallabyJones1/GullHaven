extends CanvasLayer
## The opening: a short flight round Gullhaven at dawn, in letterbox with captions, that
## ends on the logo and hands over to the main menu. Behind the menu the camera keeps
## drifting slowly round the harbour. It plays by itself the first time the game starts
## (the main menu can play it again); any key, click or button skips it.
## Everything here is just the look: the camera, a calm dawn sky and the letterbox.
## The fisher, the clock and the save are untouched.

const UI := preload("res://scripts/ui_kit.gd")

const DAWN := 6.7
const BAR := 0.11  # letterbox bars, as a share of the screen height
# Each shot: where the camera goes ([x, height above the ground or sea, z]) and what it
# looks at, how long it lasts, the caption, and whether it dips to black before it.
const SHOTS := [
	{"from": [592.0, 6.0, 566.0], "to": [552.0, 4.5, 553.0], "look_from": [510.0, 8.0, 543.5], "look_to": [510.0, 9.0, 543.5],
		"t": 7.0, "say": "Fifty years ago, the lighthouse at Gullhaven went dark."},
	{"orbit": [510.0, 543.5], "r": 23.0, "h": 13.0, "a0": 0.2, "a1": 1.45, "look_y": 9.0, "t": 7.0, "cut": true,
		"say": "Its great lens, the Gull's Eye, vanished one stormy night, and so did the keeper."},
	{"from": [508.0, 20.0, 604.0], "to": [462.0, 14.0, 610.0], "look_from": [472.0, 1.0, 574.0], "look_to": [440.0, 1.0, 570.0],
		"t": 7.5, "cut": true, "say": "The town carried on. The boats went out. The fish kept biting."},
	{"from": [454.0, 9.0, 640.0], "to": [436.0, 6.0, 660.0], "look_from": [440.0, 1.0, 662.0], "look_to": [420.0, 2.0, 676.0],
		"t": 6.5, "cut": true, "say": "And out on the point, Gran's old hut waited for someone new."},
	{"from": [436.0, 6.0, 660.0], "to": [478.0, 52.0, 728.0], "look_from": [420.0, 2.0, 676.0], "look_to": [470.0, 0.0, 590.0],
		"t": 6.5, "say": "", "logo": true},
]
const TAGLINE := "Tides, islands and one old mystery"

var main: Node
var cam: Camera3D
var world: Node3D
var player: CharacterBody3D
var day_night: Node
var hud: CanvasLayer
var playing := false
var drifting := false
var _done: Variant = null
var _shot := 0
var _t := 0.0
var _drift_center := Vector3(470.0, 0.0, 590.0)
var _drift_a := 0.0
var _drift_r := 140.0
var _drift_h := 52.0
var _proxy: Node3D
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _fade: ColorRect
var _logo: TextureRect
var _tag: Label
var _skip: Label
var _said := ""


func setup(m: Node) -> void:
	main = m
	cam = m.cam
	world = m.harbour
	player = m.player
	day_night = m.day_night
	hud = m.hud
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_proxy = Node3D.new()
	_proxy.name = "CameraFocus"
	world.add_child(_proxy)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top = _bar(root, Control.PRESET_TOP_WIDE)
	_bottom = _bar(root, Control.PRESET_BOTTOM_WIDE)
	var logo_box := CenterContainer.new()
	logo_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo_box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_box.add_child(col)
	_logo = TextureRect.new()
	_logo.texture = load("res://art/ui/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _logo.texture:
		_logo.custom_minimum_size = _logo.texture.get_size() * 6.0
	_logo.modulate.a = 0.0
	col.add_child(_logo)
	_tag = UI.label(TAGLINE, 30, UI.CREAM, true)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_constant_override("outline_size", 10)
	_tag.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.12))
	_tag.modulate.a = 0.0
	col.add_child(_tag)
	_caption = UI.label("", 30, UI.CREAM)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -90.0
	_caption.offset_bottom = -30.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	root.add_child(_caption)
	_skip = UI.label("Press any key to skip", 18, UI.DIM)
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -320.0
	_skip.offset_right = -24.0
	_skip.offset_top = 22.0
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.modulate.a = 0.0
	root.add_child(_skip)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	visible = false


func _bar(root: Control, preset: Control.LayoutPreset) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0.0, 0.0, 0.0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	b.set_anchors_preset(preset)
	b.offset_top = 0.0
	b.offset_bottom = 0.0
	return b


## Play the opening, then call done() (which shows the main menu).
func play(done: Variant = null) -> void:
	_done = done
	_take_camera()
	playing = true
	drifting = false
	_shot = 0
	_t = 0.0
	_said = ""
	visible = true
	_logo.modulate.a = 0.0
	_tag.modulate.a = 0.0
	_caption.modulate.a = 0.0
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 1.6)
	var tw2 := create_tween()
	tw2.tween_property(_skip, "modulate:a", 1.0, 1.0).set_delay(1.0)
	_set_bars(1.0, 1.2)
	_apply_shot(0.0)


## Show the menu's slowly drifting view straight away (no opening).
func drift() -> void:
	if drifting:
		return
	_take_camera()
	playing = false
	drifting = true
	visible = true
	_set_bars(0.0, 0.0)
	_caption.modulate.a = 0.0
	_skip.modulate.a = 0.0
	_logo.modulate.a = 0.0
	_tag.modulate.a = 0.0
	var last: Dictionary = SHOTS[SHOTS.size() - 1]
	_start_drift(_point(last.to), _point(last.look_to))
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)


## Back to the game: the camera follows the fisher again, under the real sky.
func release() -> void:
	if not playing and not drifting:
		return
	playing = false
	drifting = false
	cam.release()
	world.focus = player
	player.visible = true
	day_night.look_hour = -1.0
	_set_bars(0.0, 0.0)
	_caption.modulate.a = 0.0
	_skip.modulate.a = 0.0
	_logo.modulate.a = 0.0
	_tag.modulate.a = 0.0
	# a moment of black hides the sky jumping to the real time of day
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(_hide_if_idle)


func _hide_if_idle() -> void:
	if not playing and not drifting:
		visible = false


func _take_camera() -> void:
	cam.cinematic = true
	world.focus = _proxy
	player.visible = false
	day_night.look_hour = DAWN
	hud.visible = false


func _set_bars(k: float, secs: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * BAR * k
	if secs <= 0.0:
		_top.offset_bottom = h
		_bottom.offset_top = -h
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_top, "offset_bottom", h, secs)
	tw.tween_property(_bottom, "offset_top", -h, secs)


func _process(delta: float) -> void:
	if playing:
		_t += delta
		var s: Dictionary = SHOTS[_shot]
		if _t >= float(s.t):
			if _shot >= SHOTS.size() - 1:
				_finish()
				return
			_shot += 1
			_t = 0.0
			if bool(SHOTS[_shot].get("cut", false)):
				_fade.color.a = 1.0
				create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
		_apply_shot(delta)
	elif drifting:
		_drift_a += delta * 0.01
		var p := _drift_center + Vector3(cos(_drift_a) * _drift_r, 0.0, sin(_drift_a) * _drift_r)
		p.y = maxf(_ground(p.x, p.z) + 8.0, _drift_h)
		_aim(p, _drift_center + Vector3(0.0, 2.0, 0.0))


func _apply_shot(_delta: float) -> void:
	var s: Dictionary = SHOTS[_shot]
	var k := clampf(_t / float(s.t), 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * k)
	var pos: Vector3
	var look: Vector3
	if s.has("orbit"):
		var c: Array = s.orbit
		var a := lerpf(float(s.a0), float(s.a1), e)
		var cx := float(c[0])
		var cz := float(c[1])
		pos = Vector3(cx + cos(a) * float(s.r), _ground(cx, cz) + float(s.h), cz + sin(a) * float(s.r))
		look = Vector3(cx, _ground(cx, cz) + float(s.look_y), cz)
	else:
		pos = _point(s.from).lerp(_point(s.to), e)
		look = _point(s.look_from).lerp(_point(s.look_to), e)
	_aim(pos, look)
	# captions fade in after a moment and out before the cut
	var say := str(s.get("say", ""))
	if say != _said:
		_said = say
		_caption.text = say
	var cap := 0.0
	if say != "":
		cap = clampf(minf((_t - 0.6) / 0.8, (float(s.t) - 0.5 - _t) / 0.6), 0.0, 1.0)
	_caption.modulate.a = cap
	if bool(s.get("logo", false)):
		_logo.modulate.a = clampf((_t - 2.2) / 1.4, 0.0, 1.0)
		_tag.modulate.a = clampf((_t - 3.6) / 1.2, 0.0, 1.0)
		var grow := 0.94 + 0.06 * clampf((_t - 2.2) / 3.0, 0.0, 1.0)
		_logo.scale = Vector2(grow, grow)
		_logo.pivot_offset = _logo.size * 0.5


## A shot's [x, height, z] as a point: the height is above the land or the sea there.
func _point(v: Variant) -> Vector3:
	var a: Array = v
	var x := float(a[0])
	var z := float(a[2])
	return Vector3(x, _ground(x, z) + float(a[1]), z)


func _ground(x: float, z: float) -> float:
	return maxf(float(world.height_at(x, z)), float(world.sea_level))


func _aim(pos: Vector3, look: Vector3) -> void:
	pos.y = maxf(pos.y, _ground(pos.x, pos.z) + 2.0)
	# the land streams in around a point between the camera and what it's looking at
	_proxy.global_position = Vector3((pos.x + look.x) * 0.5, look.y, (pos.z + look.z) * 0.5)
	cam.aim(pos, look)


func _start_drift(pos: Vector3, look: Vector3) -> void:
	_drift_center = Vector3(look.x, look.y, look.z)
	var off := Vector2(pos.x - look.x, pos.z - look.z)
	_drift_r = maxf(off.length(), 60.0)
	_drift_a = atan2(off.y, off.x)
	_drift_h = pos.y


func _finish() -> void:
	playing = false
	drifting = true
	var last: Dictionary = SHOTS[SHOTS.size() - 1]
	_start_drift(_point(last.to), _point(last.look_to))
	_set_bars(0.0, 1.0)
	_caption.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 0.0, 0.8)
	tw.tween_property(_tag, "modulate:a", 0.0, 0.8)
	tw.tween_property(_skip, "modulate:a", 0.0, 0.4)
	if _done is Callable:
		(_done as Callable).call()


## Skip to the end: a quick dip to black, then the menu.
func skip() -> void:
	if not playing:
		return
	_shot = SHOTS.size() - 1
	_t = float(SHOTS[_shot].t)
	_apply_shot(0.0)
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)
	_finish()


func _input(event: InputEvent) -> void:
	if not playing or _t < 0.3 and _shot == 0:
		return
	var pressed := false
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		pressed = event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		skip()
