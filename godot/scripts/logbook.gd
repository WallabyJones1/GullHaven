extends CanvasLayer
## The Logbook: a page for every fishing ground (the harbour, the shallows, the estuary,
## seagrass, reef, kelp, wrecks, lagoon, open blue, the Deep and Mirrorlake) and one for
## everything else you can hook or dig up. Uncaught entries show as silhouettes, but their
## hint still tells you when and how to find them, and "Biting now" marks what you could
## catch right now. L or Tab opens and closes it, arrows move, Q / E or R turn the page.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Sea := preload("res://scripts/sea.gd")

const ZONES := ["harbour", "shallows", "estuary", "seagrass", "reef", "kelp", "wreck", "lagoon", "blue", "deep", "lake"]

var sea: Node
var save: Dictionary
var audio: Node
var hud: CanvasLayer
var is_open := false
var _page := 0
var _page_label: Label
var _grid: GridContainer
var _count: Label
var _d_icon: TextureRect
var _d_name: Label
var _d_kind: Label
var _d_stats: Label
var _d_hint: Label
var _d_now: Label


func setup(s: Node, sv: Dictionary, a: Node, h: CanvasLayer) -> void:
	sea = s
	save = sv
	audio = a
	hud = h
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(1060.0, 640.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.label("Logbook", 34, UI.GOLD, true))
	_page_label = UI.label("", 26, UI.CREAM, true)
	top.add_child(_page_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_count = UI.label("", 22, UI.SKY)
	top.add_child(_count)
	col.add_child(top)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660.0, 500.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	var detail := UI.panel(14.0)
	detail.custom_minimum_size = Vector2(340.0, 500.0)
	body.add_child(detail)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 6)
	detail.add_child(dcol)
	_d_icon = TextureRect.new()
	_d_icon.custom_minimum_size = Vector2(160.0, 160.0)
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dcol.add_child(_d_icon)
	_d_name = UI.label("", 28, UI.CREAM, true)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_kind = UI.label("", 20, UI.CREAM)
	_d_now = UI.label("", 20, UI.GOOD, true)
	_d_stats = UI.label("", 20, UI.CREAM)
	_d_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_hint = UI.label("", 19, UI.SKY)
	_d_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in [_d_name, _d_kind, _d_now, _d_stats, _d_hint]:
		c.custom_minimum_size = Vector2(300.0, 0.0)
		dcol.add_child(c)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{arrows} choose   {rotate_left}/{rotate_right} turn the page   {logbook} or {cancel} close"))


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	audio.play("cardflip", -6.0)
	_show_page(_page)


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("logbook"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("bait") or event.is_action_pressed("rotate_right"):
		get_viewport().set_input_as_handled()
		_show_page((_page + 1) % _pages())
	elif event.is_action_pressed("rotate_left"):
		get_viewport().set_input_as_handled()
		_show_page((_page + _pages() - 1) % _pages())


func _pages() -> int:
	return ZONES.size() + 1


func _page_name(page: int) -> String:
	if page >= ZONES.size():
		return "Finds"
	var z: Dictionary = sea.zones.get(ZONES[page], {})
	return str(z.get("n", ZONES[page]))


func _entries(page: int) -> Array:
	var out: Array = []
	for e in sea.items:
		var cat: String = e.cat
		var z: String = e.z
		if page < ZONES.size():
			if (cat == "fish" or cat == "legend") and z == ZONES[page] and e.how != "pot":
				out.append(e)
		else:
			var how: String = e.how
			if cat != "fish" and cat != "legend" and (how == "hook" or how == "snag" or how == "comb"):
				out.append(e)
	out.sort_custom(func(a, b): return int(a.r) < int(b.r) if int(a.r) != int(b.r) else str(a.n) < str(b.n))
	return out


func _show_page(i: int) -> void:
	_page = i
	_page_label.text = "   <  %s  >" % _page_name(i)
	for c in _grid.get_children():
		c.queue_free()
	var list := _entries(i)
	var got := 0
	var first: Button = null
	for e in list:
		var caught: bool = save.log.has(e.id)
		if caught:
			got += 1
		var b := UI.button("", 15)
		b.custom_minimum_size = Vector2(122.0, 118.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.icon = _icon(str(e.id))
		b.text = _short(str(e.n)) if caught else "???"
		if not caught:
			for k in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color"]:
				b.add_theme_color_override(k, Color(0.0, 0.0, 0.0, 0.8))
		if _now(e):
			b.add_theme_color_override("font_color", UI.GOOD)
		b.focus_entered.connect(_show_detail.bind(e))
		b.mouse_entered.connect(_show_detail.bind(e))
		_grid.add_child(b)
		if first == null:
			first = b
	_count.text = "%d / %d" % [got, list.size()]
	if first:
		first.call_deferred("grab_focus")
		_show_detail(list[0])
	audio.play("click", -8.0)


func _show_detail(e: Dictionary) -> void:
	var entry: Dictionary = save.log.get(e.id, {})
	var caught := not entry.is_empty()
	_d_icon.texture = _icon(str(e.id))
	_d_icon.modulate = Color.WHITE if caught else Color(0.0, 0.0, 0.0, 0.85)
	_d_name.text = str(e.n) if caught else "???"
	var r := int(e.r)
	var kind := str(sea.rarity[r]) if r < sea.rarity.size() else ""
	match str(e.cat):
		"legend":
			kind = "Legend"
		"junk":
			kind = "Junk"
		"fish":
			pass
		_:
			kind = "%s find" % kind
	if str(e.cat) in ["fish", "legend"]:
		var d := Sea.difficulty(e)
		kind += "   %s fight (%d/5)" % [Sea.DIFFICULTY_NAMES[d], d]
	_d_kind.text = kind
	_d_kind.add_theme_color_override("font_color", UI.RARITY_COLORS[clampi(r, 0, UI.RARITY_COLORS.size() - 1)])
	_d_now.text = "Biting now!" if _now(e) else ""
	var lines: Array[String] = []
	if caught:
		lines.append("Caught %d" % int(entry.get("count", 0)))
		if float(entry.get("best", 0.0)) > 0.0:
			lines.append("Best %.1f cm" % float(entry.best))
		if int(entry.get("g", 0)) > 0:
			lines.append("Golden x%d" % int(entry.g))
		if int(entry.get("a", 0)) > 0:
			lines.append("Albino x%d" % int(entry.a))
		lines.append("Worth about %d Shells" % int(e.price))
	else:
		lines.append("Not caught yet.")
	_d_stats.text = "\n".join(PackedStringArray(lines))
	var hint := str(e.get("hint", ""))
	if e.cat == "fish" or e.cat == "legend":
		var sz: Variant = e.get("sz")
		hint = sea.hint_for(e)
		if sz != null:
			hint += " Grows %d to %d cm." % [int(sz[0]), int(sz[1])]
	elif e.how == "comb":
		hint = "Dig for it on the beach, best at low tide. " + hint
	_d_hint.text = hint


func _now(e: Dictionary) -> bool:
	if e.cat != "fish" and e.cat != "legend":
		return false
	return sea.cond_ok(e, sea.env)


func _short(n: String) -> String:
	return n if n.length() <= 16 else n.substr(0, 15) + "."


func _icon(id: String) -> Texture2D:
	var path := "res://art/fish2/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://art/fish/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null
