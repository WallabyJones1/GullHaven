extends CanvasLayer
## The carpenter, Home Goods and the salvager. Tess the carpenter in Gullhaven upgrades
## your hut, makes wooden furniture and sells timber and rope; Fern's Home Goods on
## Mossbank sells the finer things; the salvager at Wrecker's Cove deals in nautical odds
## and ends and scrap. Up/down picks, Space buys, left/right changes tab, Esc leaves.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Furniture := preload("res://scripts/furniture.gd")

const TABS := {
	"carpenter": ["Your hut", "Projects", "Furniture", "Materials"],
	"home": ["Furniture"],
	"salvager": ["Furniture", "Materials"],
}
const SELLS := {"carpenter": ["wood", "rope"], "salvager": ["scrap", "rope"], "home": []}
const GREETINGS := {
	"carpenter": ["Bring me timber and I'll build you anything.", "That hut of yours could do with some work, you know."],
	"home": ["Make the place your own. Everything here is island-made.", "A rug and a plant and it's a home."],
	"salvager": ["The sea gives up all sorts. Have a look round.", "Scrap's cheap here. Wrecks are generous."],
}

var save: Dictionary
var audio: Node
var hud: CanvasLayer
var world: Node3D
var quests: Node  # the bridge is a carpenter's project
var is_open := false
var kind := "carpenter"
var _tab := 0
var _title: Label
var _shells: Label
var _greeting: Label
var _message: Label
var _tab_row: HBoxContainer
var _tabs: Array[Button] = []
var _list: VBoxContainer


func setup(sv: Dictionary, a: Node, h: CanvasLayer, w: Node3D) -> void:
	save = sv
	audio = a
	hud = h
	world = w
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(780.0, 560.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	_title = UI.label("", 34, UI.GOLD, true)
	top.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_shells = UI.label("", 22, UI.GOLD, true)
	top.add_child(_shells)
	col.add_child(top)
	_greeting = UI.label("", 20, UI.SKY)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_greeting)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	col.add_child(_tab_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 340.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_message = UI.label("", 20, UI.GOOD)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_message)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} choose   {action} buy   {leftright} change tab   {cancel} leave"))


func open(keeper: String, title: String, shop_kind: String) -> void:
	kind = shop_kind if TABS.has(shop_kind) else "carpenter"
	_title.text = title
	var lines: Array = GREETINGS[kind]
	_greeting.text = "%s: \"%s\"" % [keeper, lines[randi() % lines.size()]]
	_message.text = ""
	for t in _tabs:
		t.queue_free()
	_tabs.clear()
	var names: Array = TABS[kind]
	for i in names.size():
		var t := UI.button(str(names[i]), 22)
		t.alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.custom_minimum_size = Vector2(130.0, 0.0)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(i))
		_tab_row.add_child(t)
		_tabs.append(t)
	_tab_row.visible = names.size() > 1
	_tab = 0
	is_open = true
	visible = true
	get_tree().paused = true
	_show_tab(0)


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var n: int = TABS[kind].size()
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif (event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")) and n > 1:
		get_viewport().set_input_as_handled()
		_show_tab((_tab + n - 1) % n)
	elif (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")) and n > 1:
		get_viewport().set_input_as_handled()
		_show_tab((_tab + 1) % n)


func _show_tab(i: int, focus_row := 0) -> void:
	_tab = i
	var m: Dictionary = save.materials
	_shells.text = "%d Shells   Wood %d  Rope %d  Scrap %d" % [int(save.shells), int(m.get("wood", 0)), int(m.get("rope", 0)), int(m.get("scrap", 0))]
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	for c in _list.get_children():
		c.queue_free()
	var rows: Array[Button] = []
	match str(TABS[kind][i]):
		"Your hut":
			rows = _hut_rows()
		"Projects":
			rows = _project_rows()
		"Furniture":
			rows = _furniture_rows()
		_:
			rows = _material_rows()
	var focusable: Array[Button] = []
	for b in rows:
		_list.add_child(b)
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		focusable[clampi(focus_row, 0, focusable.size() - 1)].call_deferred("grab_focus")
	audio.play("click", -8.0)


func _hut_rows() -> Array[Button]:
	var out: Array[Button] = []
	var tier := int(save.hut_tier)
	for t in Furniture.HUT.size():
		var h: Dictionary = Furniture.HUT[t]
		var row := UI.button("", 20)
		var status := ""
		if t == tier:
			status = "Your hut now"
		elif t < tier:
			status = "Done"
		else:
			status = Furniture.cost_text(int(h.price), h.mats)
		row.text = "%s   %s\n    %s" % [h.n, status, h.d]
		if t != tier + 1:
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			row.pressed.connect(_upgrade_hut.bind(t))
			if Furniture.short_of(save, int(h.price), h.mats) != "":
				row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _project_rows() -> Array[Button]:
	var out: Array[Button] = []
	var row := UI.button("", 20)
	var status: String = quests.bridge_status()
	row.text = "Mend the estuary bridge   %s\n    The bridge north of Gullhaven washed out in a storm. Mended, it's a walk to Willowford." % status
	if status == "Done":
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
	else:
		row.pressed.connect(_mend_bridge)
	out.append(row)
	return out


func _mend_bridge() -> void:
	var msg: String = quests.mend_bridge()
	if msg != "":
		_fail(msg)
		return
	_done("Done! The estuary bridge is mended. Willowford's a walk up the north road now.")
	_show_tab(_tab)


func _furniture_rows() -> Array[Button]:
	var out: Array[Button] = []
	var inv: Dictionary = save.furniture_inv
	var placed: Array = save.furniture
	for id in Furniture.ITEMS:
		var it: Dictionary = Furniture.ITEMS[id]
		if str(it.shop) != kind:
			continue
		var have := int(inv.get(id, 0))
		for p in placed:
			if str(p.id) == str(id):
				have += 1
		var where := "hangs on a wall" if str(it.kind) == "wall" else ("lies on the floor" if str(it.kind) == "rug" else "stands on the floor")
		var row := UI.button("", 20)
		row.text = "%s   %s\n    %s%s" % [it.n, Furniture.cost_text(int(it.price), it.mats), where.substr(0, 1).to_upper() + where.substr(1),
			"   (you have %d)" % have if have > 0 else ""]
		row.pressed.connect(_buy_item.bind(str(id)))
		if Furniture.short_of(save, int(it.price), it.mats) != "":
			row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _material_rows() -> Array[Button]:
	var out: Array[Button] = []
	var m: Dictionary = save.materials
	for k in SELLS[kind]:
		var info: Dictionary = Furniture.MATERIALS[k]
		var each := int(info.price)
		if kind == "salvager":
			each = int(each * 0.8)  # cheaper at the source
		var price := each * 5
		var row := UI.button("", 20)
		row.text = "%s x5   %d Shells   (you have %d)\n    %s" % [info.n, price, int(m.get(k, 0)), info.d]
		row.pressed.connect(_buy_material.bind(str(k), price))
		if int(save.shells) < price:
			row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _upgrade_hut(t: int) -> void:
	var h: Dictionary = Furniture.HUT[t]
	var short := Furniture.short_of(save, int(h.price), h.mats)
	if short != "":
		_fail(short)
		return
	Furniture.pay(save, int(h.price), h.mats)
	save.hut_tier = t
	for id in h.gift:
		Furniture.give(save, str(id))
	world.rebuild_hut(t)
	_done("Your hut is now a %s! I've left %s inside as a housewarming gift." % [str(h.n).to_lower(), _gift_text(h.gift)])
	_show_tab(_tab)


func _gift_text(gift: Array) -> String:
	var names: Array[String] = []
	for id in gift:
		names.append("a " + str(Furniture.ITEMS[id].n).to_lower())
	return " and ".join(names)


func _buy_item(id: String) -> void:
	var it: Dictionary = Furniture.ITEMS[id]
	var short := Furniture.short_of(save, int(it.price), it.mats)
	if short != "":
		_fail(short)
		return
	Furniture.pay(save, int(it.price), it.mats)
	Furniture.give(save, id)
	_done("Bought the %s. It's waiting at your hut: go inside and press B to place it." % str(it.n).to_lower())
	var row := 0
	var i := 0
	for k in Furniture.ITEMS:
		if str(Furniture.ITEMS[k].shop) == kind:
			if k == id:
				row = i
			i += 1
	_show_tab(_tab, row)


func _buy_material(k: String, price: int) -> void:
	if int(save.shells) < price:
		_fail("You need %d more Shells." % (price - int(save.shells)))
		return
	save.shells = int(save.shells) - price
	var m: Dictionary = save.materials
	m[k] = int(m.get(k, 0)) + 5
	_done("Five more %s." % str(Furniture.MATERIALS[k].n).to_lower())
	_show_tab(_tab, SELLS[kind].find(k))


func _done(text: String) -> void:
	SaveGame.write(save)
	hud.set_shells(save.shells)
	hud.set_materials(save.materials)
	audio.play("buy")
	audio.play("coin", -4.0)
	_message.add_theme_color_override("font_color", UI.GOOD)
	_message.text = text


func _fail(text: String) -> void:
	audio.play("error")
	_message.add_theme_color_override("font_color", UI.BAD)
	_message.text = text
