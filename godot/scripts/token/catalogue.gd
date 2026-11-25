extends CanvasLayer
## The Home Catalogue (Harbour economy build), in the spirit of Club Penguin's furniture
## catalogue: a tab for each room (Living room, Bedroom, Kitchen...), plus Walls and Floors.
## Every piece shows in the colour you pick from its swatches. Furniture costs Shells and
## goes into your things to arrange (press B at home); wallpaper and floors go straight up,
## and ones you've bought before are free to swap back to.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Homes := preload("res://scripts/token/homes.gd")
const Harbour := preload("res://scripts/token/harbour.gd")

const COLUMNS := 4

var save: Dictionary
var audio: Node
var hud: CanvasLayer
var on_style_changed: Callable  # the room redraws when the wallpaper or floor changes
var is_open := false
var _tab := 0
var _tab_names: Array[String] = []
var _tabs: Array[Button] = []
var _pick := {}  # base / pattern -> chosen colour
var _tab_row: HFlowContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _money: Label
var _message: Label
var _tex_cache := {}


func setup(sv: Dictionary, a: Node, h: CanvasLayer) -> void:
	save = sv
	audio = a
	hud = h
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(980.0, 660.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_child(UI.label("Home Catalogue", 34, UI.GOLD, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_money = UI.label("", 24, UI.GOLD, true)
	top.add_child(_money)
	col.add_child(top)
	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override("h_separation", 6)
	_tab_row.add_theme_constant_override("v_separation", 6)
	col.add_child(_tab_row)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, 430.0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)
	_message = UI.label("", 20, UI.GOOD)
	col.add_child(_message)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} {leftright} choose   {action} buy / pick a colour   {camera} change tab   {cancel} close"))
	_tab_names.assign(Homes.catalog().categories)
	_tab_names.append_array(["Walls", "Floors"])
	for i in _tab_names.size():
		var t := UI.button(_tab_names[i], 20)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(show_tab.bind(i))
		_tab_row.add_child(t)
		_tabs.append(t)


func open(tab := 0) -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	_message.text = ""
	show_tab(clampi(tab, 0, _tab_names.size() - 1))


## The tab for wallpapers (Restyle: walls).
func walls_tab() -> int:
	return _tab_names.find("Walls")


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("rotate_left"):  # Q / LB (the arrows move between cards)
		get_viewport().set_input_as_handled()
		show_tab((_tab + _tab_names.size() - 1) % _tab_names.size())
	elif event.is_action_pressed("rotate_right"):  # E / RB
		get_viewport().set_input_as_handled()
		show_tab((_tab + 1) % _tab_names.size())


func show_tab(i: int, focus_key := "") -> void:
	_tab = i
	Homes.ensure(save)
	_money.text = "%d Shells   %.2f $GULL" % [int(save.get("shells", 0)), float(Harbour.ensure(save).gull)]
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var tab_name := _tab_names[i]
	var focus: Control = null
	if tab_name == "Walls" or tab_name == "Floors":
		var list: Array = Homes.catalog().walls if tab_name == "Walls" else Homes.catalog().floors
		for entry in list:
			var key := str(entry.pattern) if tab_name == "Walls" else str(entry.kind)
			var card := _style_card(tab_name == "Walls", entry)
			_grid.add_child(card.node)
			if focus == null or key == focus_key:
				focus = card.focus
	else:
		for it in Homes.catalog().items:
			if str(it.cat) != tab_name:
				continue
			var card := _item_card(it)
			_grid.add_child(card.node)
			if focus == null or str(it.base) == focus_key:
				focus = card.focus
	if focus:
		UI.focus_soon(focus)
	audio.play("click", -8.0)


# --- cards -----------------------------------------------------------------------------

func _card_shell() -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.11, 0.17, 0.95), Color(0.2, 0.3, 0.42), 2, 8.0))
	panel.custom_minimum_size = Vector2(222.0, 0.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0.0, 104.0)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(pic)
	return {"node": panel, "box": v, "pic": pic}


func _item_card(it: Dictionary) -> Dictionary:
	var base := str(it.base)
	var colours: Array = it.colours
	var c := str(_pick.get(base, colours[0]))
	var id := Homes.item_id(base, c)
	var shell := _card_shell()
	var v: VBoxContainer = shell.box
	shell.pic.texture = _texture("res://art/decor/home/%s_%s.png" % [base, c])
	var title := UI.label("%s" % it.n, 19, UI.CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var inv: Dictionary = save.get("furniture_inv", {})
	var have := int(inv.get(id, 0))
	v.add_child(UI.label("%s, %d Shells%s" % [Homes.colour_name(c), int(it.price), ("   (you have %d)" % have) if have > 0 else ""], 16, UI.SKY))
	v.add_child(_swatches(colours, c, func(nc: String) -> void:
		_pick[base] = nc
		show_tab(_tab, base)))
	var buy := UI.button("Buy", 20)
	buy.alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy.pressed.connect(_buy_item.bind(id, base))
	v.add_child(buy)
	return {"node": shell.node, "focus": buy}


func _style_card(is_wall: bool, entry: Dictionary) -> Dictionary:
	var key := str(entry.pattern) if is_wall else str(entry.kind)
	var colours: Array = entry.colours
	var c := str(_pick.get(("w:" if is_wall else "f:") + key, colours[0]))
	var tex := Homes.wall_tex(key, c) if is_wall else Homes.floor_tex(key, c)
	var h := Homes.ensure(save)
	var shell := _card_shell()
	var v: VBoxContainer = shell.box
	shell.pic.texture = _texture("res://art/tex/%s.png" % tex)
	shell.pic.stretch_mode = TextureRect.STRETCH_TILE
	v.add_child(UI.label("%s" % entry.n, 19, UI.CREAM, true))
	var owned: bool = tex in (h.styles as Array)
	var current: bool = tex == str(h.wall if is_wall else h.floor)
	v.add_child(UI.label("%s, %s" % [Homes.colour_name(c), "yours" if owned else "%d Shells" % int(entry.price)], 16, UI.SKY))
	v.add_child(_swatches(colours, c, func(nc: String) -> void:
		_pick[("w:" if is_wall else "f:") + key] = nc
		show_tab(_tab, key)))
	var b := UI.button("In use" if current else ("Use" if owned else "Buy and use"), 20)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.disabled = current
	b.pressed.connect(_use_style.bind(tex, key))
	v.add_child(b)
	return {"node": shell.node, "focus": b}


## A row of colour buttons; the chosen one has a gold edge.
func _swatches(colours: Array, chosen: String, pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	for col in colours:
		var key := str(col)
		var b := Button.new()
		b.custom_minimum_size = Vector2(22.0, 22.0)
		b.tooltip_text = Homes.colour_name(key)
		var fill := Homes.colour(key)
		var edge := UI.GOLD if key == chosen else Color(0.05, 0.05, 0.08)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := UI.box(fill.lightened(0.15) if state == "hover" else fill, UI.CREAM if state == "focus" else edge, 3 if key == chosen or state == "focus" else 2, 0.0)
			if key == "gradient":
				sb.bg_color = Color("#9945ff")
				sb.border_color = Color("#14f195") if key != chosen and state != "focus" else sb.border_color
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(pick.bind(key))
		row.add_child(b)
	return row


func _texture(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


# --- buying ----------------------------------------------------------------------------

func _buy_item(id: String, base: String) -> void:
	var r := Homes.buy_item(save, id)
	if not r.ok:
		_fail(str(r.reason))
		return
	_done("Bought the %s. Press B at home to put it somewhere." % str(r.n).to_lower())
	show_tab(_tab, base)


func _use_style(tex: String, key: String) -> void:
	var r := Homes.use_style(save, tex)
	if not r.ok:
		_fail(str(r.reason))
		return
	_done("New %s up!" % ("wallpaper" if tex.begins_with("home/wall_") else "floor") if r.bought else "Changed it.")
	if on_style_changed.is_valid():
		on_style_changed.call()
	show_tab(_tab, key)


func _done(text: String) -> void:
	SaveGame.write(save)
	hud.set_shells(save.get("shells", 0))
	audio.play("buy")
	_message.add_theme_color_override("font_color", UI.GOOD)
	_message.text = text


func _fail(text: String) -> void:
	audio.play("error")
	_message.add_theme_color_override("font_color", UI.BAD)
	_message.text = text
