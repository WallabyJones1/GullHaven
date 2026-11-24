extends CanvasLayer
## The on-screen layer: Shells, clock and Logbook count, a context prompt, the cast
## power bar, the fight meters, the catch card and toast messages. Built in code with
## the web game's pixel font so it matches Gullhaven's look.

const DayNight := preload("res://scripts/day_night.gd")

const CREAM := Color(0.98, 0.95, 0.86)
const GOLD := Color(1.0, 0.84, 0.45)
const SKY := Color(0.72, 0.87, 1.0)
const PANEL := Color(0.07, 0.09, 0.17, 0.86)
const EDGE := Color(0.96, 0.86, 0.62)
const RARITY_COLORS := [Color(0.86, 0.86, 0.8), Color(0.5, 0.88, 0.52), Color(0.48, 0.72, 1.0), Color(1.0, 0.72, 0.3), Color(1.0, 0.45, 0.62)]


## A flat pixel-style meter.
class Bar extends Control:
	var value := 0.0
	var fill := Color.WHITE
	var marks: Array[float] = []

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.04, 0.05, 0.1, 0.95))
		var inner := r.grow(-3.0)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(value, 0.0, 1.0), inner.size.y)), fill)
		for m in marks:
			var x := inner.position.x + inner.size.x * m
			draw_rect(Rect2(x - 1.0, inner.position.y, 2.0, inner.size.y), Color(1.0, 1.0, 1.0, 0.55))
		draw_rect(r, Color(0.96, 0.86, 0.62), false, 2.0)

	func set_value(v: float, c: Color) -> void:
		value = v
		fill = c
		queue_redraw()


var font: Font
var font_bold: Font
var log_total := 0
var shells_label: Label
var clock_label: Label
var log_label: Label
var prompt_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var power_box: Control
var power_bar: Bar
var fight_box: Control
var fight_label: Label
var tension_bar: Bar
var reel_bar: Bar
var card_box: Control
var card_icon: TextureRect
var card_title: Label
var card_name: Label
var card_rarity: Label
var card_size: Label
var card_tier: Label
var card_reward: Label
var card_note: Label
var _toasts: Array[String] = []
var _toast_t := 0.0
var _minute := -1


func _ready() -> void:
	layer = 10
	font = load("res://art/fonts/pixelify_sans.woff2")
	font_bold = load("res://art/fonts/pixelify_sans_bold.woff2")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	# Top left: Shells, clock, Logbook.
	var stats := _panel()
	stats.position = Vector2(20.0, 18.0)
	root.add_child(stats)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	stats.add_child(col)
	shells_label = _label("Shells  0", 28, GOLD, true)
	clock_label = _label("9:00 am", 22, CREAM)
	log_label = _label("Logbook  0", 20, SKY)
	col.add_child(shells_label)
	col.add_child(clock_label)
	col.add_child(log_label)

	# Top centre: toasts.
	var toast_row := _centered(root, Control.PRESET_TOP_WIDE, 20.0, 70.0)
	toast_panel = _panel()
	toast_label = _label("", 22, CREAM)
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	toast_row.add_child(toast_panel)

	# Bottom centre: the context prompt.
	var prompt_row := _centered(root, Control.PRESET_BOTTOM_WIDE, -70.0, -30.0)
	prompt_label = _label("", 24, CREAM)
	prompt_row.add_child(prompt_label)

	# Cast power.
	power_box = _centered(root, Control.PRESET_BOTTOM_WIDE, -130.0, -96.0)
	power_bar = Bar.new()
	power_bar.custom_minimum_size = Vector2(380.0, 28.0)
	power_bar.marks = [0.85]
	power_box.add_child(power_bar)
	power_box.visible = false

	# Fight meters.
	fight_box = _centered(root, Control.PRESET_BOTTOM_WIDE, -250.0, -96.0)
	var fight_panel := _panel()
	fight_box.add_child(fight_panel)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 6)
	fight_panel.add_child(fcol)
	fight_label = _label("Hold E to reel in", 24, CREAM, true)
	fight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fcol.add_child(fight_label)
	tension_bar = Bar.new()
	tension_bar.marks = [0.75, 0.9]
	reel_bar = Bar.new()
	fcol.add_child(_meter_row("Tension", tension_bar))
	fcol.add_child(_meter_row("Reel", reel_bar))
	fight_box.visible = false

	# The catch card.
	card_box = CenterContainer.new()
	card_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_box)
	var card := _panel(18.0)
	card.custom_minimum_size = Vector2(440.0, 0.0)
	card_box.add_child(card)
	var ccol := VBoxContainer.new()
	ccol.alignment = BoxContainer.ALIGNMENT_CENTER
	ccol.add_theme_constant_override("separation", 4)
	card.add_child(ccol)
	card_title = _label("You caught", 20, SKY)
	card_name = _label("", 36, CREAM, true)
	card_rarity = _label("", 20, CREAM)
	card_icon = TextureRect.new()
	card_icon.custom_minimum_size = Vector2(160.0, 160.0)
	card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_size = _label("", 22, CREAM)
	card_tier = _label("", 26, GOLD, true)
	card_reward = _label("", 24, GOLD)
	card_note = _label("", 20, Color(0.6, 1.0, 0.7))
	var hint := _label("Press E to continue", 18, Color(0.75, 0.75, 0.8))
	for c in [card_title, card_name, card_rarity, card_icon, card_size, card_tier, card_reward, card_note, hint]:
		ccol.add_child(c)
		if c is Label:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.visible = false


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.4:
			toast_panel.modulate.a = maxf(_toast_t / 0.4, 0.0)
		if _toast_t <= 0.0:
			_next_toast()


func set_shells(n: Variant) -> void:
	shells_label.text = "Shells  %d" % int(n)


func set_catches(n: Variant, total := -1) -> void:
	if total >= 0:
		log_total = total
	if log_total > 0:
		log_label.text = "Logbook  %d / %d" % [int(n), log_total]
	else:
		log_label.text = "Logbook  %d" % int(n)


func set_clock(hour: float) -> void:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	if h * 60 + m == _minute:
		return
	_minute = h * 60 + m
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	var when := DayNight.period(hour).capitalize()
	clock_label.text = "%d:%02d %s   %s" % [h12, m, "am" if h < 12 else "pm", when]


func set_prompt(text: String) -> void:
	if prompt_label.text != text:
		prompt_label.text = text


func toast(text: String) -> void:
	_toasts.append(text)
	if _toast_t <= 0.0:
		_next_toast()


func show_power(v: float) -> void:
	power_box.visible = true
	var c := Color(0.45, 0.85, 1.0).lerp(GOLD, v)
	if v > 0.85:
		c = Color(1.0, 0.95, 0.6)
	power_bar.set_value(v, c)


func hide_power() -> void:
	power_box.visible = false


## tension 0..1 (snaps at 1), progress 0..1 (landed at 1), text describes the fish.
func show_fight(tension: float, progress: float, text: String, urgent: bool) -> void:
	fight_box.visible = true
	var tc := Color(0.4, 0.9, 0.5)
	if tension > 0.85:
		tc = Color(1.0, 0.35, 0.3)
	elif tension > 0.6:
		tc = Color(1.0, 0.8, 0.3)
	tension_bar.set_value(tension, tc)
	reel_bar.set_value(progress, Color(1.0, 0.45, 0.4) if progress < 0.15 else SKY)
	fight_label.text = text
	var flash := urgent and int(Time.get_ticks_msec() / 150) % 2 == 0
	fight_label.add_theme_color_override("font_color", GOLD if flash else CREAM)


func hide_fight() -> void:
	fight_box.visible = false


func show_catch(info: Dictionary) -> void:
	card_name.text = info.get("name", "")
	var r := int(info.get("rarity", 0))
	card_rarity.text = info.get("rarity_name", "")
	card_rarity.add_theme_color_override("font_color", RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)])
	card_icon.texture = info.get("icon")
	card_size.text = "%d cm" % int(info.get("size", 0.0))
	card_tier.text = "%s catch!" % info.get("tier", "Clean")
	card_reward.text = "+%d Shells" % int(info.get("shells", 0))
	var note := ""
	if info.get("is_new", false):
		note = "New in your Logbook!"
	elif info.get("record", false):
		note = "Biggest one yet!"
	card_note.text = note
	card_note.visible = note != ""
	card_box.visible = true


func hide_catch() -> void:
	card_box.visible = false


func _next_toast() -> void:
	if _toasts.is_empty():
		toast_panel.visible = false
		return
	toast_label.text = _toasts.pop_front()
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	_toast_t = 3.0 + toast_label.text.length() * 0.03


# --- building blocks -------------------------------------------------------------

func _panel(pad := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = EDGE
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.corner_detail = 2
	box.content_margin_left = pad + 4.0
	box.content_margin_right = pad + 4.0
	box.content_margin_top = pad * 0.6
	box.content_margin_bottom = pad * 0.6
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A full-width strip (top or bottom) that centres whatever is put in it.
func _centered(root: Control, preset: Control.LayoutPreset, top: float, bottom: float) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(preset)
	c.offset_top = top
	c.offset_bottom = bottom
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _meter_row(title: String, bar: Bar) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(title, 20, SKY)
	l.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(l)
	bar.custom_minimum_size = Vector2(320.0, 22.0)
	row.add_child(bar)
	return row
