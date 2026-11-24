extends CanvasLayer
## The Boatyard in Gullhaven and Lantern Boatworks: buy a boat (or switch between the ones
## you own), fit a deck lamp, and paint the hull. Gullhaven builds the small boats; the big
## ones come from Lantern Key. Up/down picks, Space buys, left/right changes tab, Esc leaves.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Boats := preload("res://scripts/boats.gd")

const TABS := ["Boats", "Parts", "Paint"]
const PAINT_NAMES := ["Rust", "Cream", "Harbour blue", "Red", "Navy", "Green", "Sunflower", "Violet", "Rose", "Charcoal"]
const PAINT_PRICE := 150
const GREETINGS := {
	"boatyard": ["Every fisher needs a boat. Let's find you one.", "Small boats built here. The big hulls come from Lantern Key."],
	"boatworks": ["Out here we build boats for the open sea.", "A Trawler shrugs off the breakers. A Cutter goes anywhere."],
}

var save: Dictionary
var audio: Node
var hud: CanvasLayer
var boats: Node3D
var player: CharacterBody3D
var is_open := false
var kind := "boatyard"
var _tab := 0
var _title: Label
var _shells: Label
var _greeting: Label
var _message: Label
var _tabs: Array[Button] = []
var _list: VBoxContainer


func setup(sv: Dictionary, a: Node, h: CanvasLayer, b: Node3D, p: CharacterBody3D) -> void:
	save = sv
	audio = a
	hud = h
	boats = b
	player = p
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
	_title = UI.label("Boatyard", 34, UI.GOLD, true)
	top.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_shells = UI.label("", 26, UI.GOLD, true)
	top.add_child(_shells)
	col.add_child(top)
	_greeting = UI.label("", 20, UI.SKY)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_greeting)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for i in TABS.size():
		var t := UI.button(TABS[i], 22)
		t.alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.custom_minimum_size = Vector2(120.0, 0.0)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(i))
		tabs.add_child(t)
		_tabs.append(t)
	col.add_child(tabs)
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
	kind = shop_kind if GREETINGS.has(shop_kind) else "boatyard"
	_title.text = title
	var lines: Array = GREETINGS[kind]
	_greeting.text = "%s: \"%s\"" % [keeper, lines[randi() % lines.size()]]
	_message.text = ""
	is_open = true
	visible = true
	get_tree().paused = true
	_show_tab(_tab)


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
	elif (event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")):
		get_viewport().set_input_as_handled()
		_show_tab((_tab + TABS.size() - 1) % TABS.size())
	elif (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_show_tab((_tab + 1) % TABS.size())


func _show_tab(i: int, focus_row := 0) -> void:
	_tab = i
	_shells.text = "%d Shells" % int(save.shells)
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	for c in _list.get_children():
		c.queue_free()
	var rows: Array[Button] = []
	match i:
		0:
			rows = _boat_rows()
		1:
			rows = _part_rows()
		_:
			rows = _paint_rows()
	var focusable: Array[Button] = []
	for b in rows:
		_list.add_child(b)
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		UI.focus_soon(focusable[clampi(focus_row, 0, focusable.size() - 1)])
	audio.play("click", -8.0)


func _boat_rows() -> Array[Button]:
	var out: Array[Button] = []
	var owned: Array = save.boats
	for b in Boats.BOATS:
		var k := str(b.k)
		var row := UI.button("", 20)
		var here := kind == "boatworks" or int(b.tier) <= 3
		var status := ""
		if str(save.boat) == k:
			status = "Your boat"
		elif owned.has(k):
			status = "Owned: switch to her"
		elif not here:
			status = "Built at Lantern Boatworks"
		else:
			status = "%d Shells" % int(b.price)
		row.text = "%s   %s\n    %s  Speed %d%%." % [b.n, status, b.d, int(round(float(b.spd) * 100.0))]
		if str(save.boat) == k or (not here and not owned.has(k)):
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			row.pressed.connect(_buy_boat.bind(k))
			if not owned.has(k) and int(save.shells) < int(b.price):
				row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _part_rows() -> Array[Button]:
	var out: Array[Button] = []
	for k in Boats.PARTS:
		var p: Dictionary = Boats.PARTS[k]
		var row := UI.button("", 20)
		var have: bool = boats.has_part(k)
		row.text = "%s   %s\n    %s" % [p.n, "Fitted" if have else "%d Shells" % int(p.price), p.d]
		if have:
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			row.pressed.connect(_buy_part.bind(k))
		out.append(row)
	return out


func _paint_rows() -> Array[Button]:
	var out: Array[Button] = []
	for i in Boats.PAINT.size():
		var row := UI.button("", 20)
		var on := int(save.boat_paint) == i
		row.text = "%s   %s" % [PAINT_NAMES[i], "On your hull" if on else "%d Shells" % PAINT_PRICE]
		row.add_theme_color_override("font_color", Color.html(str(Boats.PAINT[i])).lightened(0.25))
		if on:
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			row.pressed.connect(_buy_paint.bind(i))
		out.append(row)
	return out


func _buy_boat(k: String) -> void:
	var b: Dictionary = Boats.boat_info(k)
	var owned: Array = save.boats
	if not owned.has(k):
		var price := int(b.price)
		if int(save.shells) < price:
			_fail("You need %d more Shells for the %s." % [price - int(save.shells), b.n])
			return
		save.shells = int(save.shells) - price
		owned.append(k)
		save.boat_paint = -1  # a new boat comes in her own colours
	save.boat = k
	boats.spawn_at_dock(Vector3(player.global_position.x, 0.0, player.global_position.z))
	_done("The %s is tied up at the dock outside. Walk up to her and press Space to board." % b.n)
	_show_tab(_tab)


func _buy_part(k: String) -> void:
	var p: Dictionary = Boats.PARTS[k]
	if str(save.boat) == "":
		_fail("You'll want a boat to fit it to first.")
		return
	if int(save.shells) < int(p.price):
		_fail("You need %d more Shells for the %s." % [int(p.price) - int(save.shells), str(p.n).to_lower()])
		return
	save.shells = int(save.shells) - int(p.price)
	var parts: Dictionary = save.boat_parts
	parts[k] = true
	_respawn()
	_done("Fitted the %s." % str(p.n).to_lower())
	_show_tab(_tab)


func _buy_paint(i: int) -> void:
	if str(save.boat) == "":
		_fail("Buy a boat first, then we'll talk colours.")
		return
	if int(save.shells) < PAINT_PRICE:
		_fail("A coat of paint is %d Shells." % PAINT_PRICE)
		return
	save.shells = int(save.shells) - PAINT_PRICE
	save.boat_paint = i
	_respawn()
	_done("A fresh coat of %s. She looks grand." % PAINT_NAMES[i].to_lower())
	_show_tab(_tab, i)


## Rebuild the boat where she floats, with her new paint or parts.
func _respawn() -> void:
	if boats.boat:
		boats.spawn(boats.boat.global_position, boats.heading)


func _done(text: String) -> void:
	SaveGame.write(save)
	hud.set_shells(save.shells)
	audio.play("buy")
	audio.play("coin", -4.0)
	_message.add_theme_color_override("font_color", UI.GOOD)
	_message.text = text


func _fail(text: String) -> void:
	audio.play("error")
	_message.add_theme_color_override("font_color", UI.BAD)
	_message.text = text
