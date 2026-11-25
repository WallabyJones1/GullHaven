extends CanvasLayer
## The land menus: Gran's workbench and the cook pot (craft from what you've gathered), and
## the stalls of Farmer Bramble, Delve the smith and Ash the hunter (buy tools and seeds,
## sell what you've grown, mined and hunted). Up/down picks, Space makes or buys or sells
## one, the kit key sells the lot, left/right changes tab, Esc leaves.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Furniture := preload("res://scripts/furniture.gd")
const D := preload("res://scripts/land_data.gd")

const GREETINGS := {
	"bramble": ["Your gran grew the best turnips on the coast. No pressure.", "Seeds, tools, and a fair price for whatever you grow.",
		"Rain's the best watering can there is. Second best is the one I sell."],
	"delve": ["Bring me ore and I'll pay you in Shells. Or smelt it yourself, I won't be offended.",
		"The hills are full of iron if you know where to swing.", "Mind your fingers. And your eyebrows."],
	"ash": ["Quiet feet, steady hands. That's all hunting is.", "I'll take hides, meat and feathers off your hands.",
		"Aim where it's going, not where it is."],
}

var land: Node3D
var save: Dictionary
var audio: Node
var hud: CanvasLayer
var is_open := false
var mode := ""  # "bench", "pot", or a merchant key
var _who := ""
var _tabs_list: Array = []
var _tab := 0
var _title: Label
var _money: Label
var _greeting: Label
var _message: Label
var _hint: Label
var _tab_row: HBoxContainer
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _rows: Array = []  # what each focusable row does: {"kind", ...}


func setup(l: Node3D, sv: Dictionary, a: Node, h: CanvasLayer) -> void:
	land = l
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
	panel.custom_minimum_size = Vector2(820.0, 580.0)
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
	_money = UI.label("", 22, UI.GOLD, true)
	top.add_child(_money)
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
	_hint = Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} choose   {action} make   {leftright} change tab   {cancel} leave")
	col.add_child(_hint)


## Gran's workbench ("bench") or the cook pot ("pot").
func open_craft(station: String) -> void:
	mode = station
	_who = ""
	_tabs_list = []
	for r: Dictionary in D.RECIPES:
		if str(r.at) == station and not _tabs_list.has(str(r.tab)):
			_tabs_list.append(str(r.tab))
	_title.text = "Gran's workbench" if station == "bench" else "The cook pot"
	_greeting.text = "Crafting level %d. Higher levels open more recipes." % int(land.skill_level("crafting"))
	_hint.text = Glyphs.plain("{updown} choose   {action} make one   {leftright} change tab   {cancel} leave")
	_open()


## A merchant's stall: Bramble, Delve or Ash.
func open_shop(key: String, who: String) -> void:
	mode = key
	_who = who
	var m: Dictionary = D.MERCHANTS[key]
	_title.text = str(m.n)
	var lines: Array = GREETINGS.get(key, ["Hello!"])
	_greeting.text = "%s: \"%s\"" % [who, lines[randi() % lines.size()]]
	_tabs_list = ["Buy", "Sell"]
	if bool(m.get("beds", false)):
		_tabs_list.append("Garden")
	_hint.text = Glyphs.plain("{updown} choose   {action} buy / sell one   {tool} sell all   {leftright} change tab   {cancel} leave")
	_open()


func _open() -> void:
	for t in _tabs:
		t.queue_free()
	_tabs.clear()
	for i in _tabs_list.size():
		var t := UI.button(str(_tabs_list[i]), 22)
		t.alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.custom_minimum_size = Vector2(130.0, 0.0)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(i))
		_tab_row.add_child(t)
		_tabs.append(t)
	_tab_row.visible = _tabs_list.size() > 1
	_message.text = ""
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
	var n := _tabs_list.size()
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif (event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")) and n > 1:
		get_viewport().set_input_as_handled()
		_show_tab((_tab + n - 1) % n)
	elif (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")) and n > 1:
		get_viewport().set_input_as_handled()
		_show_tab((_tab + 1) % n)
	elif event.is_action_pressed("tool") and str(_tabs_list[_tab]) == "Sell":
		get_viewport().set_input_as_handled()
		var f := get_viewport().gui_get_focus_owner()
		if f and f.has_meta("sell_id"):
			_sell(str(f.get_meta("sell_id")), true)


func _show_tab(i: int, focus_row := 0) -> void:
	_tab = i
	var m: Dictionary = save.materials
	_money.text = "%d Shells   Wood %d" % [int(save.shells), int(m.get("wood", 0))]
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	for c in _list.get_children():
		c.queue_free()
	var rows: Array[Button] = []
	var tab := str(_tabs_list[i])
	if mode == "bench" or mode == "pot":
		rows = _recipe_rows(tab)
	elif tab == "Buy":
		rows = _buy_rows()
	elif tab == "Sell":
		rows = _sell_rows()
	else:
		rows = _garden_rows()
	if rows.is_empty():
		var empty := UI.button("Nothing here yet.", 20)
		empty.disabled = true
		empty.focus_mode = Control.FOCUS_NONE
		rows.append(empty)
	var focusable: Array[Button] = []
	for b in rows:
		_list.add_child(b)
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		UI.focus_soon(focusable[clampi(focus_row, 0, focusable.size() - 1)])
	audio.play("click", -8.0)


# --- crafting -------------------------------------------------------------------------------

func _needs_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	for k in r.needs:
		parts.append("%d %s (%d)" % [int(r.needs[k]), D.item_name(str(k)).to_lower(), int(land.count(str(k)))])
	return ", ".join(parts)


func _can_make(r: Dictionary) -> String:
	if int(land.skill_level("crafting")) < int(r.lv):
		return "Needs Crafting level %d." % int(r.lv)
	for k in r.gives:
		var key := str(k)
		if key.begins_with("tool:") and int(land.tool_tier(key.substr(5))) >= int(r.gives[k]):
			return "You've already got one as good."
	var short: Array[String] = []
	for k in r.needs:
		var gap := int(r.needs[k]) - int(land.count(str(k)))
		if gap > 0:
			short.append("%d %s" % [gap, D.item_name(str(k)).to_lower()])
	return "" if short.is_empty() else "You need %s more." % " and ".join(short)


func _recipe_rows(tab: String) -> Array[Button]:
	var out: Array[Button] = []
	var i := 0
	for r: Dictionary in D.RECIPES:
		if str(r.at) != mode or str(r.tab) != tab:
			continue
		var row := UI.button("", 20)
		var why := _can_make(r)
		var gives_text := ""
		for k in r.gives:
			var key := str(k)
			if not key.begins_with("tool:") and not key.begins_with("furniture:") and int(r.gives[k]) > 1:
				gives_text = " x%d" % int(r.gives[k])
		var lv_text := "" if int(r.lv) <= 1 else "   (Crafting %d)" % int(r.lv)
		row.text = "%s%s%s\n    %s" % [D.recipe_name(r), gives_text, lv_text, _needs_text(r)]
		var tex := D.icon(str(r.id))
		if tex:
			row.icon = tex
			row.expand_icon = false
			row.add_theme_constant_override("icon_max_width", 32)
		if why != "":
			row.add_theme_color_override("font_color", UI.DIM)
		row.pressed.connect(_make.bind(r, i))
		out.append(row)
		i += 1
	return out


func _make(r: Dictionary, row: int) -> void:
	var why := _can_make(r)
	if why != "":
		_fail(why)
		return
	for k in r.needs:
		land.take(str(k), int(r.needs[k]))
	var got: Array[String] = []
	for k in r.gives:
		var key := str(k)
		var n := int(r.gives[k])
		if key.begins_with("tool:"):
			land.set_tool(key.substr(5), n)
			got.append("a " + str(land.tool_name(key.substr(5))).to_lower())
		elif key.begins_with("furniture:"):
			var fid := key.substr(10)
			Furniture.give(save, fid, n)
			got.append("a %s (press B in your hut to place it)" % str(Furniture.ITEMS[fid].n).to_lower())
		else:
			got.append(str(land.add_item(key, n)).trim_prefix("+"))
	land.add_xp("crafting", 4 + int(r.lv) * 3)
	land.land_event.emit("cook" if mode == "pot" else "craft", str(r.id), 1)
	_done("Made %s." % ", ".join(got))
	_show_tab(_tab, row)


# --- buying and selling ------------------------------------------------------------------------

func _buy_price(id: String) -> int:
	var it: Dictionary = D.ITEMS.get(id, {})
	return int(it.get("buy", int(it.get("price", 10)) * 3))


func _buy_rows() -> Array[Button]:
	var out: Array[Button] = []
	var m: Dictionary = D.MERCHANTS[mode]
	var tools: Dictionary = m.get("tools", {})
	for kind in tools:
		var have := int(land.tool_tier(str(kind)))
		var first: Dictionary = D.TOOLS[kind][0]
		var row := UI.button("", 20)
		if have > 0:
			row.text = "%s   You've got a %s" % [first.n, str(land.tool_name(str(kind))).to_lower()]
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			row.text = "%s   %d Shells" % [first.n, int(tools[kind])]
			row.pressed.connect(_buy_tool.bind(str(kind), int(tools[kind])))
			if int(save.shells) < int(tools[kind]):
				row.add_theme_color_override("font_color", UI.DIM)
		var tex := D.icon(str(first.id))
		if tex:
			row.icon = tex
		out.append(row)
	for id in m.sells:
		var price := _buy_price(str(id))
		var row := UI.button("", 20)
		var batch := 5 if str(id) == "arrows" else 1
		row.text = "%s%s   %d Shells   (you have %d)" % [D.item_name(str(id)), " x5" if batch > 1 else "", price * batch, int(land.count(str(id)))]
		var tex := D.icon(str(id))
		if tex:
			row.icon = tex
		row.pressed.connect(_buy_item.bind(str(id), price * batch, batch))
		if int(save.shells) < price * batch:
			row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _buy_tool(kind: String, price: int) -> void:
	if int(save.shells) < price:
		_fail("You need %d more Shells." % (price - int(save.shells)))
		return
	save.shells = int(save.shells) - price
	land.set_tool(kind, 1)
	land.land_event.emit("tool", kind, 1)
	_done("A %s. Look after it." % str(land.tool_name(kind)).to_lower())
	_show_tab(_tab)


func _buy_item(id: String, price: int, n: int) -> void:
	if int(save.shells) < price:
		_fail("You need %d more Shells." % (price - int(save.shells)))
		return
	save.shells = int(save.shells) - price
	var items: Dictionary = save.land.items
	items[id] = int(items.get(id, 0)) + n
	_done("Bought %d %s." % [n, D.item_name(id).to_lower()])
	var focus := 0
	var m: Dictionary = D.MERCHANTS[mode]
	for t in m.get("tools", {}):
		if int(land.tool_tier(str(t))) <= 0:
			focus += 1
	_show_tab(_tab, focus + (m.sells as Array).find(id))


func _sell_price(id: String) -> int:
	var it: Dictionary = D.ITEMS.get(id, {})
	return int(it.get("price", 1))


func _sell_rows() -> Array[Button]:
	var out: Array[Button] = []
	var m: Dictionary = D.MERCHANTS[mode]
	var items: Dictionary = save.land.items
	var ids := items.keys()
	ids.sort()
	for id in ids:
		var it: Dictionary = D.ITEMS.get(id, {})
		if it.is_empty() or not (m.buys as Array).has(str(it.cat)) or int(it.price) <= 0:
			continue
		var row := UI.button("", 20)
		row.text = "%s x%d   %d Shells each" % [it.n, int(items[id]), int(it.price)]
		var tex := D.icon(str(id))
		if tex:
			row.icon = tex
		row.set_meta("sell_id", str(id))
		row.pressed.connect(_sell.bind(str(id), false))
		out.append(row)
	return out


func _sell(id: String, all: bool) -> void:
	var have := int(land.count(id))
	if have <= 0:
		return
	var n := have if all else 1
	land.take(id, n)
	var paid := _sell_price(id) * n
	save.shells = int(save.shells) + paid
	land.land_event.emit("sell", id, n)
	_done("Sold %d %s for %d Shells." % [n, D.item_name(id).to_lower(), paid])
	var row := 0
	var m: Dictionary = D.MERCHANTS[mode]
	var items: Dictionary = save.land.items
	var ids := items.keys()
	ids.sort()
	for k in ids:
		var it: Dictionary = D.ITEMS.get(k, {})
		if not it.is_empty() and (m.buys as Array).has(str(it.cat)) and str(k) < id:
			row += 1
	_show_tab(_tab, row)


func _garden_rows() -> Array[Button]:
	var out: Array[Button] = []
	var n := int(land.bed_count())
	var row := UI.button("", 20)
	if n >= D.MAX_BEDS:
		row.text = "Another garden bed   Your garden's as big as it gets (%d beds)" % n
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
	else:
		var price := int(D.BED_PRICE[n])
		row.text = "Another garden bed   %d Shells\n    I'll clear another bed beside your others. (You have %d.)" % [price, n]
		row.pressed.connect(_buy_bed)
		if int(save.shells) < price:
			row.add_theme_color_override("font_color", UI.DIM)
	out.append(row)
	var tips := UI.button("Ask about growing\n    How long things take, and what grows best.", 20)
	tips.pressed.connect(_grow_tips)
	out.append(tips)
	return out


func _buy_bed() -> void:
	var msg: String = land.buy_bed()
	if msg != "":
		_fail(msg)
		return
	_done("Done: there's a new bed by the others, ready to dig over.")
	_show_tab(_tab)


func _grow_tips() -> void:
	var parts: Array[String] = []
	for crop in D.CROP_ORDER:
		var info: Dictionary = D.CROPS[crop]
		parts.append("%s %d min" % [D.item_name(crop), int(info.grow)])
	_message.add_theme_color_override("font_color", UI.SKY)
	_message.text = "Watered growing time: %s. A watering lasts half a day, and rain does it for you. Compost makes things grow half again as fast." % ", ".join(parts)


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
