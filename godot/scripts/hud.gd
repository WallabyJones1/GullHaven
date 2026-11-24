extends CanvasLayer
## The on-screen layer: Shells, clock and conditions, the Logbook count, where you are,
## townsfolk requests, your bait and catch streak, a context prompt, the cast power bar,
## the fight meters, the catch card, toasts and the banner when you reach a new place.

const UI := preload("res://scripts/ui_kit.gd")
const DayNight := preload("res://scripts/day_night.gd")

const SKY_NAMES := {"calm": "Calm", "windy": "Windy", "rain": "Rain", "fog": "Fog", "storm": "Storm"}
const TIDE_NAMES := {"high": "High tide", "low": "Low tide", "rising": "Rising tide", "falling": "Falling tide"}


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


var sea: Node
var save: Dictionary
var log_total := 0
var shells_label: Label
var streak_label: Label
var clock_label: Label
var env_label: Label
var log_label: Label
var requests_panel: PanelContainer
var requests_list: VBoxContainer
var bait_label: Label
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
var card: PanelContainer
var card_icon: TextureRect
var card_title: Label
var card_name: Label
var card_rarity: Label
var card_size: Label
var card_tier: Label
var card_reward: Label
var card_note: Label
var area_label: Label
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var _banner_t := 0.0
var _toasts: Array[String] = []
var _toast_t := 0.0
var _minute := -1
var _shown_shells := 0.0
var _target_shells := 0.0
var _block_until := 0
var modal := false  # a mode (arranging furniture) has the controls
var mats_label: Label


func setup(s: Node, sv: Dictionary) -> void:
	sea = s
	save = sv
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top left: Shells and streak, clock, conditions, Logbook.
	var stats := UI.panel()
	stats.position = Vector2(20.0, 18.0)
	root.add_child(stats)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	stats.add_child(col)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 14)
	shells_label = UI.label("Shells  0", 28, UI.GOLD, true)
	streak_label = UI.label("", 20, Color(1.0, 0.6, 0.4), true)
	money.add_child(shells_label)
	money.add_child(streak_label)
	col.add_child(money)
	clock_label = UI.label("9:00 am", 22, UI.CREAM)
	env_label = UI.label("", 18, UI.SKY)
	log_label = UI.label("Logbook  0", 18, UI.SKY)
	col.add_child(clock_label)
	col.add_child(env_label)
	col.add_child(log_label)
	mats_label = UI.label("", 18, Color(0.85, 0.78, 0.62))
	mats_label.visible = false
	col.add_child(mats_label)
	area_label = UI.label("", 18, UI.CREAM)
	col.add_child(area_label)

	# Top right: what the townsfolk want.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -20.0
	right.offset_right = -20.0
	right.offset_top = 18.0
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	requests_panel = UI.panel()
	right.add_child(requests_panel)
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 2)
	requests_panel.add_child(rcol)
	rcol.add_child(UI.label("Requests", 20, UI.GOLD, true))
	requests_list = VBoxContainer.new()
	requests_list.add_theme_constant_override("separation", 1)
	rcol.add_child(requests_list)

	# Bottom left: bait and key hints.
	var bottom_left := VBoxContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_left.offset_left = 20.0
	bottom_left.offset_bottom = -16.0
	bottom_left.offset_top = -16.0
	bottom_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_left)
	var bait_panel := UI.panel(8.0)
	bait_label = UI.label("Bait: Bread dough", 20, UI.CREAM)
	bait_panel.add_child(bait_label)
	bottom_left.add_child(bait_panel)
	bottom_left.add_child(UI.label("Space cast, talk   Q/E turn camera   Wheel zoom   R bait   L Logbook   J Journal   M map   Esc menu", 16, UI.DIM))

	# Top centre: toasts.
	var toast_row := _centered(root, Control.PRESET_TOP_WIDE, 20.0, 70.0)
	toast_panel = UI.panel()
	toast_label = UI.label("", 22, UI.CREAM)
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	toast_row.add_child(toast_panel)

	# Upper centre: the name of a place as you arrive.
	var banner_row := _centered(root, Control.PRESET_TOP_WIDE, 110.0, 200.0)
	banner = VBoxContainer.new()
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_title = UI.label("", 52, UI.GOLD, true)
	banner_sub = UI.label("", 22, UI.CREAM)
	for c in [banner_title, banner_sub]:
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_child(c)
	banner.visible = false
	banner_row.add_child(banner)

	# Bottom centre: the context prompt.
	var prompt_row := _centered(root, Control.PRESET_BOTTOM_WIDE, -70.0, -30.0)
	prompt_label = UI.label("", 24, UI.CREAM)
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
	var fight_panel := UI.panel()
	fight_box.add_child(fight_panel)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 6)
	fight_panel.add_child(fcol)
	fight_label = UI.label("Hold Space to reel in", 24, UI.CREAM, true)
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
	card = UI.panel(18.0)
	card.custom_minimum_size = Vector2(460.0, 0.0)
	card_box.add_child(card)
	var ccol := VBoxContainer.new()
	ccol.alignment = BoxContainer.ALIGNMENT_CENTER
	ccol.add_theme_constant_override("separation", 4)
	card.add_child(ccol)
	card_title = UI.label("You caught", 20, UI.SKY)
	card_name = UI.label("", 36, UI.CREAM, true)
	card_rarity = UI.label("", 20, UI.CREAM)
	card_icon = TextureRect.new()
	card_icon.custom_minimum_size = Vector2(160.0, 160.0)
	card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_size = UI.label("", 22, UI.CREAM)
	card_tier = UI.label("", 26, UI.GOLD, true)
	card_reward = UI.label("", 24, UI.GOLD)
	card_note = UI.label("", 20, UI.GOOD)
	card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_note.custom_minimum_size = Vector2(420.0, 0.0)
	var hint := UI.label("Press Space to continue", 18, UI.DIM)
	for c in [card_title, card_name, card_rarity, card_icon, card_size, card_tier, card_reward, card_note, hint]:
		ccol.add_child(c)
		if c is Label:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.visible = false

	_shown_shells = float(save.shells)
	_target_shells = _shown_shells
	set_shells(save.shells)
	set_requests(save.requests)
	set_materials(save.materials)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.4:
			toast_panel.modulate.a = maxf(_toast_t / 0.4, 0.0)
		if _toast_t <= 0.0:
			_next_toast()
	if _banner_t > 0.0:
		_banner_t -= delta
		banner.modulate.a = clampf(minf((4.0 - _banner_t) / 0.6, _banner_t / 0.8), 0.0, 1.0)
		banner.visible = _banner_t > 0.0
	if absf(_shown_shells - _target_shells) > 0.5:
		_shown_shells = move_toward(_shown_shells, _target_shells, maxf(absf(_target_shells - _shown_shells) * 4.0, 20.0) * delta)
		shells_label.text = "Shells  %d" % int(round(_shown_shells))


## Announce a place you've just reached ("Willowford", "on the river"), and keep its
## name in the corner.
func show_area(title: String, subtitle := "", announce := true) -> void:
	area_label.text = title
	if not announce or title == "":
		return
	banner_title.text = title
	banner_sub.text = subtitle
	banner_sub.visible = subtitle != ""
	_banner_t = 4.0
	banner.modulate.a = 0.0
	banner.visible = true


## Ignore gameplay presses for a moment (after closing a menu with the same key).
func block_input(seconds: float) -> void:
	_block_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func input_blocked() -> bool:
	return modal or Time.get_ticks_msec() < _block_until or get_tree().paused


## Driftwood, rope and scrap metal on hand (hidden until you have some).
func set_materials(m: Dictionary) -> void:
	var w := int(m.get("wood", 0))
	var r := int(m.get("rope", 0))
	var s := int(m.get("scrap", 0))
	mats_label.visible = w + r + s > 0
	mats_label.text = "Wood %d   Rope %d   Scrap %d" % [w, r, s]


func set_shells(n: Variant) -> void:
	_target_shells = float(n)
	if absf(_target_shells - _shown_shells) <= 0.5:
		shells_label.text = "Shells  %d" % int(n)


func set_streak(n: int) -> void:
	streak_label.text = "" if n < 2 else "Streak x%d" % n
	if n >= 2:
		var t := create_tween()
		streak_label.scale = Vector2(1.3, 1.3)
		t.tween_property(streak_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_catches(n: Variant, total := -1) -> void:
	if total >= 0:
		log_total = total
	if log_total > 0:
		log_label.text = "Logbook  %d / %d fish" % [int(n), log_total]
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
	if sea and not sea.env.is_empty():
		var e: Dictionary = sea.env
		var moon := ""
		if e.moon == "fullmoon":
			moon = "   Full moon"
		elif e.moon == "newmoon":
			moon = "   New moon"
		env_label.text = "%s   %s   %s%s" % [str(e.season).capitalize(), SKY_NAMES.get(e.sky, ""), TIDE_NAMES.get(e.tide_state, ""), moon]


func set_requests(reqs: Array) -> void:
	if requests_list == null:
		return
	for c in requests_list.get_children():
		c.queue_free()
	requests_panel.visible = not reqs.is_empty()
	for req in reqs:
		var e: Dictionary = sea.by_id.get(req.id, {})
		var what := str(e.get("n", req.id))
		if float(req.get("min", 0.0)) > 0.0:
			what += " %d cm+" % int(req.min)
		var text := "%s: %s" % [req.who, what]
		var color := UI.CREAM
		if req.held:
			text = "%s: %s  Ready!" % [req.who, str(e.get("n", req.id))]
			color = UI.GOOD
		requests_list.add_child(UI.label(text, 17, color))


func refresh_bait() -> void:
	if bait_label == null or sea == null:
		return
	var k := str(save.bait_sel)
	var b: Dictionary = sea.bait.get(k, {})
	var name_text := str(b.get("n", "Bread dough"))
	if k == "dough":
		bait_label.text = "Bait: %s" % name_text
	elif b.has("lure"):
		bait_label.text = "Bait: %s (lure)" % name_text
	else:
		bait_label.text = "Bait: %s  x%d" % [name_text, int(save.bait.get(k, 0))]


func set_prompt(text: String) -> void:
	if prompt_label.text != text:
		prompt_label.text = text


func toast(text: String) -> void:
	_toasts.append(text)
	if _toast_t <= 0.0:
		_next_toast()


func show_power(v: float) -> void:
	power_box.visible = true
	var c := Color(0.45, 0.85, 1.0).lerp(UI.GOLD, v)
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
	reel_bar.set_value(progress, Color(1.0, 0.45, 0.4) if progress < 0.15 else UI.SKY)
	fight_label.text = text
	var flash := urgent and (Time.get_ticks_msec() / 150) % 2 == 0
	fight_label.add_theme_color_override("font_color", UI.GOLD if flash else UI.CREAM)


func hide_fight() -> void:
	fight_box.visible = false


func show_catch(info: Dictionary) -> void:
	card_name.text = info.get("name", "")
	var r := int(info.get("rarity", 0))
	card_rarity.text = info.get("rarity_name", "")
	var style := str(info.get("style", ""))
	if style != "":
		card_rarity.text += "   Fights like %s" % style
	card_rarity.add_theme_color_override("font_color", UI.RARITY_COLORS[clampi(r, 0, UI.RARITY_COLORS.size() - 1)])
	card_icon.texture = info.get("icon")
	card_icon.modulate = info.get("tint", Color.WHITE)
	var cm := float(info.get("size", 0.0))
	card_size.text = "%.1f cm" % cm
	card_size.visible = cm > 0.0
	var tier := str(info.get("tier", ""))
	card_tier.text = "%s catch!" % tier
	card_tier.visible = tier != ""
	var shells := int(info.get("shells", 0))
	card_reward.text = "+%d Shells" % shells
	card_reward.visible = shells > 0
	var note := str(info.get("note", ""))
	card_note.text = note
	card_note.visible = note != ""
	card_box.visible = true
	# Pop in.
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.7, 0.7)
	card.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.15)


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
	var l := UI.label(title, 20, UI.SKY)
	l.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(l)
	bar.custom_minimum_size = Vector2(320.0, 22.0)
	row.add_child(bar)
	return row
