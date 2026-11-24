extends CanvasLayer
## The title screen and the game menu, plus settings that belong to this computer (not the
## save): music and effects volume, fullscreen, graphics quality and your keys.
## The title shows over the live world when the game starts: Continue, New game, Quit.
## Esc (or Start) opens the game menu: Resume, then Fisher, Bag, Logbook, Journal, Map,
## Controls, Settings, Save and quit. Screens opened from it come back to it when closed.

const UI := preload("res://scripts/ui_kit.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Audio := preload("res://scripts/audio.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const SETTINGS := "user://settings.cfg"
const PAD_CONTROLS := """[b]Walk / steer[/b]  left stick      [b]Camera[/b]  right stick, LB / RB
[b]Cast, reel, talk, use[/b]  A      [b]Back, reel in, step ashore[/b]  B
[b]Change bait[/b]  Y      [b]Use your kit / arrange your hut[/b]  X
[b]Game menu[/b]  Start      [b]Map[/b]  Back / View
[b]Journal[/b]  D-pad up (or click the left stick)      [b]Logbook[/b]  D-pad left      [b]Bag[/b]  D-pad right"""

var main: Node
var hud: CanvasLayer
var audio: Node
var player: CharacterBody3D
var cam: Camera3D
var mode := ""  # "title", "pause", "screen" (something opened from the menu) or ""
var settings := {"music": 0.8, "effects": 1.0, "fullscreen": false, "quality": true}
var _root: Control
var _box: VBoxContainer
var _title: Label
var _sub: Label
var _orbit := false
var _screen: Node = null  # opened from the menu: come back when it closes
var _page := ""  # which page of the game menu is showing
var _waiting := ""  # the action waiting for a new key
var _waiting_btn: Button
var keys := {}  # action -> physical keycode, only the ones you've changed


func setup(m: Node, h: CanvasLayer, a: Node, p: CharacterBody3D, c: Camera3D) -> void:
	main = m
	hud = h
	audio = a
	player = p
	cam = c
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_settings()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	_title = UI.label("GULLHAVEN", 96, UI.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 18)
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.12))
	col.add_child(_title)
	_sub = UI.label("", 22, UI.CREAM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	col.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)
	var version := UI.label("%s   Feedback and bugs: tell whoever sent you the game, or open an issue on GitHub" % version_text(), 16, UI.DIM)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(16.0, -34.0)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(version)
	visible = false


static func version_text() -> String:
	return "Gullhaven %s" % str(ProjectSettings.get_setting("application/config/version", "beta"))


# --- the title screen -------------------------------------------------------------------

func show_title() -> void:
	mode = "title"
	visible = true
	hud.modal = true
	hud.visible = false
	player.can_move = false
	_orbit = true
	_title.visible = true
	_sub.text = "A fishing game of tides, islands and one old mystery"
	_clear()
	if FileAccess.file_exists(SaveGame.PATH):
		_button("Continue", _start)
		_button("New game", _confirm_new)
	else:
		_button("Start", _start)
	_button("Settings", _settings_page.bind("title"))
	_button("Quit", _quit)
	_focus_first()


func _start() -> void:
	mode = ""
	visible = false
	_orbit = false
	hud.modal = false
	hud.visible = true
	hud.block_input(0.4)
	player.can_move = true
	audio.play("fanfare1", -6.0)
	main.welcome()


func _confirm_new() -> void:
	_clear()
	_sub.text = "Start again from the beginning? This erases your save."
	_button("Yes, start a new game", _new_game)
	_button("No, go back", show_title)
	_focus_first()


func _new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))
	main.skip_save = true
	get_tree().reload_current_scene()


# --- the game menu -----------------------------------------------------------------------

func open_pause() -> void:
	mode = "pause"
	visible = true
	_title.visible = false
	get_tree().paused = true
	_pause_page()


func _pause_page() -> void:
	mode = "pause"
	_page = "hub"
	_waiting = ""
	_clear()
	_sub.text = str(main.status_line()) if main.has_method("status_line") else "Paused"
	_button("Resume", close_pause)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for pair in [["Fisher", _fisher_page], ["Bag", _open_screen.bind("bag")], ["Logbook", _open_screen.bind("logbook")],
			["Journal", _open_screen.bind("journal")], ["Map", _open_screen.bind("map_screen")], ["Controls", _controls_page],
			["Settings", _settings_page.bind("pause")], ["Save and quit", _quit]]:
		var b := UI.button(str(pair[0]), 24)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(250.0, 0.0)
		b.pressed.connect(_press.bind(pair[1]))
		grid.add_child(b)
	_focus_first()
	audio.play("click")


func close_pause() -> void:
	mode = ""
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.3)


## Open the bag, logbook, journal or map on top of the game, then come back here.
func _open_screen(which: String) -> void:
	var screen: Node = main.get(which)
	if screen == null:
		return
	mode = "screen"
	visible = false
	_screen = screen
	screen.call("open")


func _fisher_page() -> void:
	_clear()
	_page = "fisher"
	_sub.text = "Fisher"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660.0, minf(560.0, get_viewport().get_visible_rect().size.y * 0.6))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var prog: Node = main.get("progress")
	if prog:
		prog.call("fill_page", col, _fisher_page)
	col.add_child(_rich(str(main.fisher_text()) if main.has_method("fisher_text") else "", 620.0))
	_button("Back", _pause_page)
	_focus_first()


func _controls_page() -> void:
	_clear()
	_page = "controls"
	_waiting = ""
	_sub.text = "Controls"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640.0, minf(520.0, get_viewport().get_visible_rect().size.y * 0.55))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	col.add_child(UI.label("Keyboard (choose one to change it)", 20, UI.GOLD, true))
	for action in InputSetup.REBINDABLE:
		var row := HBoxContainer.new()
		var l := UI.label(str(InputSetup.NAMES.get(action, action)), 20, UI.CREAM, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UI.button(_key_name(action), 20)
		b.custom_minimum_size = Vector2(190.0, 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_start_rebind.bind(action, b))
		row.add_child(b)
		col.add_child(row)
	col.add_child(_rich("[b]Always[/b]  Esc: back, reel in, step ashore, game menu.   Left click: cast and use.   " +
		"Mouse wheel: zoom.   Right mouse drag: turn the camera.   F2: graphics quality.", 600.0))
	col.add_child(UI.label("Gamepad", 20, UI.GOLD, true))
	col.add_child(_rich(PAD_CONTROLS, 600.0))
	_button("Put the keys back how they were", _reset_keys)
	_button("Back", _pause_page)
	_focus_first()


func _key_name(action: String) -> String:
	var was := Glyphs.device
	Glyphs.device = "keyboard"
	var k := Glyphs.key(action)
	Glyphs.device = was
	return k


func _start_rebind(action: String, b: Button) -> void:
	_waiting = action
	_waiting_btn = b
	b.text = "Press a key..."
	_sub.text = "Press the new key for %s (Esc to keep it)" % str(InputSetup.NAMES.get(action, action)).to_lower()


func _finish_rebind(code: int) -> void:
	var action := _waiting
	_waiting = ""
	if code != KEY_NONE and code != KEY_ESCAPE:
		var old := InputSetup.primary(action)
		var other := InputSetup.action_with(code, action)
		InputSetup.rebind(action, code)
		keys[action] = int(code)
		if other != "" and old != KEY_NONE:
			InputSetup.rebind(other, old)
			keys[other] = int(old)
			hud.toast("%s moved to %s" % [str(InputSetup.NAMES.get(other, other)), _key_name(other)])
		_save_settings()
		Glyphs.refresh()
		audio.play("pin", -4.0)
	var focus_action := action
	_controls_page()
	await get_tree().process_frame
	await get_tree().process_frame
	_focus_rebind(focus_action)


func _focus_rebind(action: String) -> void:
	var kn := _key_name(action)
	var label_text := str(InputSetup.NAMES.get(action, action))
	for b in _find_buttons(_box):
		var row := b.get_parent()
		if row is HBoxContainer and row.get_child_count() == 2 and row.get_child(0) is Label:
			if (row.get_child(0) as Label).text == label_text and b.text == kn:
				b.grab_focus()
				return


func _find_buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_find_buttons(c))
	return out


func _reset_keys() -> void:
	InputSetup.reset_keys()
	keys.clear()
	_save_settings()
	Glyphs.refresh()
	hud.toast("Keys are back to how they started.")
	_controls_page()


func _rich(text: String, width: float) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size = Vector2(width, 0.0)
	t.add_theme_font_override("normal_font", UI.font(false))
	t.add_theme_font_override("bold_font", UI.font(true))
	t.add_theme_font_size_override("normal_font_size", 19)
	t.add_theme_font_size_override("bold_font_size", 19)
	t.add_theme_color_override("default_color", UI.CREAM)
	t.text = text
	return t


# --- settings -------------------------------------------------------------------------------

func _settings_page(from: String) -> void:
	_clear()
	_page = "settings"
	_sub.text = "Settings"
	_slider("Music", "music")
	_slider("Sound effects", "effects")
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = bool(settings.fullscreen)
	fs.add_theme_font_override("font", UI.font(true))
	fs.add_theme_font_size_override("font_size", 22)
	fs.toggled.connect(_on_fullscreen)
	_box.add_child(fs)
	var q := CheckButton.new()
	q.text = "High quality (shading, haze, focus blur)"
	q.button_pressed = bool(settings.quality)
	q.add_theme_font_override("font", UI.font(true))
	q.add_theme_font_size_override("font_size", 22)
	q.toggled.connect(_on_quality)
	_box.add_child(q)
	_button("Back", show_title if from == "title" else _pause_page)
	_focus_first()


func _slider(label: String, key: String) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(label, 22, UI.CREAM, true)
	l.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(settings[key])
	s.custom_minimum_size = Vector2(260.0, 28.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)
	_box.add_child(row)


func _on_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	_apply_settings()
	_save_settings()


func _on_quality(on: bool) -> void:
	settings.quality = on
	main.set_quality(on, false)
	_save_settings()


func _on_slider(v: float, key: String) -> void:
	settings[key] = v
	_apply_settings()
	_save_settings()
	audio.play("click", -8.0)


func _press(action: Callable) -> void:
	audio.play("click")
	action.call()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	if cfg.has_section("keys"):
		for action in cfg.get_section_keys("keys"):
			if action in InputSetup.REBINDABLE:
				var code := int(cfg.get_value("keys", action, 0))
				if code != KEY_NONE and code != KEY_ESCAPE:
					keys[action] = code
		for action in keys:
			InputSetup.rebind(action, int(keys[action]))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for action in keys:
		cfg.set_value("keys", action, int(keys[action]))
	cfg.save(SETTINGS)


func _apply_settings() -> void:
	Audio.set_volume("Music", float(settings.music))
	Audio.set_volume("Effects", float(settings.effects))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


# --- shared ----------------------------------------------------------------------------------

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _button(text: String, action: Callable) -> void:
	var b := UI.button(text, 24)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(_press.bind(action))
	_box.add_child(b)


func _focus_first() -> void:
	await get_tree().process_frame
	for c in _box.get_children():
		if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			return
		for cc in c.get_children():
			if cc is Control and (cc as Control).focus_mode != Control.FOCUS_NONE:
				(cc as Control).grab_focus()
				return


func _quit() -> void:
	main.save_now()
	get_tree().quit()


func _process(delta: float) -> void:
	if _orbit and cam:
		cam.set_yaw(cam.yaw + delta * 0.06)
	if _screen != null and mode == "screen" and not bool(_screen.get("is_open")):
		_screen = null
		call_deferred("_back_from_screen")


func _back_from_screen() -> void:
	visible = true
	get_tree().paused = true
	_pause_page()


func _input(event: InputEvent) -> void:
	if _waiting != "":
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			_finish_rebind((event as InputEventKey).physical_keycode)
		elif event is InputEventJoypadButton and event.is_pressed():
			get_viewport().set_input_as_handled()
			_finish_rebind(KEY_NONE)
		return
	if mode == "pause" and (event.is_action_pressed("cancel") or event.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		if _page == "hub":
			close_pause()
		else:
			_pause_page()
	elif mode == "title" and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		show_title()
