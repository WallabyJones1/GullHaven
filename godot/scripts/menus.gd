extends CanvasLayer
## The title screen and the pause menu, plus settings that belong to this computer (not the
## save): music and effects volume, fullscreen and graphics quality.
## The title shows over the live world when the game starts: Continue, New game, Quit.
## Esc (or B) when nothing else wants it opens the pause menu: Resume, Settings, Controls,
## Save and quit.

const UI := preload("res://scripts/ui_kit.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Audio := preload("res://scripts/audio.gd")

const SETTINGS := "user://settings.cfg"
const CONTROLS := """[b]Walk[/b]  WASD or arrows (left stick)
[b]Turn the camera[/b]  Q / E, or drag with the right mouse button (right stick, bumpers)
[b]Zoom[/b]  mouse wheel or - / = (right stick)
[b]Cast, reel, talk, open doors, board, dig[/b]  Space, F or left click (A)
[b]Reel in, step ashore, back[/b]  Esc (B)
[b]Change bait[/b]  R (Y)
[b]Logbook[/b]  L or Tab (Back)
[b]Journal[/b]  J (click the left stick)
[b]Map[/b]  M (Start)
[b]Arrange your hut[/b]  B inside it (X)
[b]Skip an hour[/b]  T
[b]Hide the HUD for photos[/b]  P
[b]Graphics quality[/b]  F2"""

var main: Node
var hud: CanvasLayer
var audio: Node
var player: CharacterBody3D
var cam: Camera3D
var mode := ""  # "title", "pause" or ""
var settings := {"music": 0.8, "effects": 1.0, "fullscreen": false, "quality": true}
var _root: Control
var _box: VBoxContainer
var _title: Label
var _sub: Label
var _orbit := false


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


# --- the pause menu -----------------------------------------------------------------------

func open_pause() -> void:
	mode = "pause"
	visible = true
	_title.visible = false
	get_tree().paused = true
	_pause_page()


func _pause_page() -> void:
	_clear()
	_sub.text = "Paused"
	_button("Resume", close_pause)
	_button("Settings", _settings_page.bind("pause"))
	_button("Controls", _controls_page)
	_button("Save and quit", _quit)
	_focus_first()
	audio.play("click")


func close_pause() -> void:
	mode = ""
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.3)


func _controls_page() -> void:
	_clear()
	_sub.text = "Controls"
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.custom_minimum_size = Vector2(620.0, 0.0)
	t.add_theme_font_override("normal_font", UI.font(false))
	t.add_theme_font_override("bold_font", UI.font(true))
	t.add_theme_font_size_override("normal_font_size", 19)
	t.add_theme_font_size_override("bold_font_size", 19)
	t.add_theme_color_override("default_color", UI.CREAM)
	t.text = CONTROLS
	_box.add_child(t)
	_button("Back", _pause_page)
	_focus_first()


# --- settings -------------------------------------------------------------------------------

func _settings_page(from: String) -> void:
	_clear()
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


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
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


func _input(event: InputEvent) -> void:
	if mode == "pause" and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_pause()
	elif mode == "title" and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		show_title()
