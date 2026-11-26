extends CanvasLayer
## Conversations: a box along the bottom of the screen with the speaker's name and
## portrait, text that types itself out, and (sometimes) choices. The action button finishes
## the line or moves on; cancel skips to the end. Calls back when the conversation's over
## (with the choice made, if there was one).

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const SPEED := 55.0  # characters a second

var hud: CanvasLayer
var audio: Node
var player: CharacterBody3D
var is_open := false
var _queue: Array = []  # [{who, lines, portrait, choices, done}]
var _cur := {}
var _line := 0
var _shown := 0.0
var _choice := 0
var _choice_btns: Array[Label] = []
var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _face: TextureRect
var _choices: VBoxContainer
var _blip_t := 0.0
var _opened_frame := -1  # ignore the press that opened it


var _tapped := false  # the box was tapped (touch screens)


func setup(h: CanvasLayer, a: Node, p: CharacterBody3D) -> void:
	hud = h
	audio = a
	player = p
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = UI.panel(16.0)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 60.0
	_panel.offset_right = -60.0
	_panel.offset_top = -230.0
	_panel.offset_bottom = -30.0
	root.add_child(_panel)
	_panel.gui_input.connect(_tap_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(128.0, 168.0)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	_name = UI.label("", 26, UI.GOLD, true)
	col.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UI.font(false))
	_text.add_theme_font_override("bold_font", UI.font(true))
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("bold_font_size", 24)
	_text.add_theme_color_override("default_color", UI.CREAM)
	col.add_child(_text)
	_choices = VBoxContainer.new()
	col.add_child(_choices)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_hint = UI.label("", 18, UI.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)
	# everything inside lets taps through to the box (which moves the talk on)
	for c in [row, _face, col, _text, _choices, spacer]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS


## Queue a conversation. lines: Array of Strings. portrait: a character sheet (the first
## frame is used) or null. choices: shown after the last line. done(choice_index) is
## called at the end (-1 if there were no choices).
func say(who: String, lines: Array, portrait: Texture2D = null, choices: Array = [], done: Variant = null) -> void:
	_queue.append({"who": who, "lines": lines, "portrait": portrait, "choices": choices, "done": done})
	if not is_open:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_close()
		return
	_cur = _queue.pop_front()
	_line = 0
	if not is_open:
		_opened_frame = Engine.get_process_frames()
	is_open = true
	visible = true
	hud.modal = true
	player.can_move = false
	_name.text = str(_cur.who)
	var tex: Texture2D = _cur.portrait
	if tex:
		var at := AtlasTexture.new()
		at.atlas = tex
		var fw := tex.get_width() / 5.0
		var fh := tex.get_height() / 4.0
		at.region = Rect2(0.0, 0.0, fw, fh * 0.62)  # head and shoulders
		_face.texture = at
		_face.visible = true
	else:
		_face.visible = false
	_show_line()


func _show_line() -> void:
	var lines: Array = _cur.lines
	_text.text = Glyphs.fmt(str(lines[_line]))
	_text.visible_characters = 0
	_shown = 0.0
	for c in _choices.get_children():
		c.queue_free()
	_choice_btns.clear()
	_hint.text = ""


func _process(delta: float) -> void:
	if not is_open:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total and _text.visible_characters >= 0:
		_shown += delta * SPEED
		_text.visible_characters = mini(int(_shown), total)
		_blip_t -= delta
		if _blip_t <= 0.0:
			_blip_t = 0.07
			audio.play("pin", -22.0, 1.6, 0.15)
		if _text.visible_characters >= total:
			_line_done()
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("cancel") and _choice_btns.is_empty():
		_finish(-1)
		return
	if not _choice_btns.is_empty():
		if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
			_choice = (_choice + _choice_btns.size() - 1) % _choice_btns.size()
			_mark_choice()
		if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
			_choice = (_choice + 1) % _choice_btns.size()
			_mark_choice()
	var tapped := _tapped
	_tapped = false
	if Input.is_action_just_pressed("action") or (tapped and _choice_btns.is_empty()):
		if _text.visible_characters < total and _text.visible_characters >= 0:
			_text.visible_characters = total
			_line_done()
			return
		var lines: Array = _cur.lines
		if _line < lines.size() - 1:
			_line += 1
			_show_line()
			audio.play("click", -10.0)
		else:
			_finish(_choice if not _choice_btns.is_empty() else -1)


func _line_done() -> void:
	var lines: Array = _cur.lines
	var choices: Array = _cur.choices
	if _line == lines.size() - 1 and not choices.is_empty() and _choice_btns.is_empty():
		_choice = 0
		for c in choices:
			var l := UI.label("", 22, UI.CREAM, true)
			l.text = "   " + str(c)
			l.mouse_filter = Control.MOUSE_FILTER_STOP  # tap an answer to pick it
			l.gui_input.connect(_tap_choice.bind(_choice_btns.size()))
			_choices.add_child(l)
			_choice_btns.append(l)
		_mark_choice()
		_hint.text = Glyphs.plain("{updown} choose   {action} answer")
	else:
		_hint.text = Glyphs.plain("{action} next" if _line < lines.size() - 1 else "{action} close")


func _tap_choice(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_choice = i
		_mark_choice()
		get_viewport().set_input_as_handled()
		_finish(i)


## A tap or click on the box moves the talk on, like the action key.
func _tap_box(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_tapped = true


func _input(event: InputEvent) -> void:
	# touch screens: a tap anywhere on the box (or the darkened world) moves the talk on
	if is_open and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and _choice_btns.is_empty():
		_tapped = true


func _mark_choice() -> void:
	var choices: Array = _cur.choices
	for i in _choice_btns.size():
		_choice_btns[i].text = ("> " if i == _choice else "   ") + str(choices[i])
		_choice_btns[i].add_theme_color_override("font_color", UI.GOLD if i == _choice else UI.CREAM)
	audio.play("click", -12.0)


func _finish(choice: int) -> void:
	var done: Variant = _cur.get("done")
	_cur = {}
	if _queue.is_empty():
		_close()
	if done is Callable and (done as Callable).is_valid():
		(done as Callable).call(choice)
	if not _queue.is_empty() and _cur.is_empty():
		_next()


func _close() -> void:
	is_open = false
	visible = false
	hud.modal = false
	hud.block_input(0.3)
	player.can_move = true
