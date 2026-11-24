extends CanvasLayer
## Hale's Tackle: rods, reels, lines and bait, at the web game's prices.
## Up/down picks, E (or Enter, Space, pad A, a click) buys, left/right changes tab,
## Q or Esc leaves. The game pauses while you browse.

const UI := preload("res://scripts/ui_kit.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TABS := ["Rods", "Reels", "Lines", "Bait"]
const KINDS := ["rod", "reel", "line"]
# Baits that make sense in the harbour and on the beach.
const BAIT_STOCK := ["worm", "prawn", "pilchard", "weedbait", "squidjig", "metal", "livebait", "glow"]
const GREETINGS := [
	"Line's cheap, fish aren't. What'll it be?",
	"Back again? The fish must be biting.",
	"Mind the hooks. What can I get you?",
	"Worms are fresh today. Mostly.",
]

var sea: Node
var save: Dictionary
var audio: Node
var hud: CanvasLayer
var is_open := false
var _tab := 0
var _shells: Label
var _greeting: Label
var _message: Label
var _tabs: Array[Button] = []
var _list: VBoxContainer


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
	panel.custom_minimum_size = Vector2(760.0, 560.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_child(UI.label("Hale's Tackle", 34, UI.GOLD, true))
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
	scroll.custom_minimum_size = Vector2(0.0, 330.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_message = UI.label("", 20, UI.GOOD)
	col.add_child(_message)
	col.add_child(UI.label("Up/down choose   Space buy   Left/right change tab   Esc leave", 18, UI.DIM))


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	_greeting.text = "Hale: \"%s\"" % GREETINGS[randi() % GREETINGS.size()]
	_message.text = ""
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
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_show_tab((_tab + TABS.size() - 1) % TABS.size())
	elif event.is_action_pressed("move_right"):
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
	if i < 3:
		rows = _gear_rows(KINDS[i])
	else:
		rows = _bait_rows()
	var focusable: Array[Button] = []
	for b in rows:
		_list.add_child(b)
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		focusable[clampi(focus_row, 0, focusable.size() - 1)].call_deferred("grab_focus")
	audio.play("click", -8.0)


func _gear_rows(kind: String) -> Array[Button]:
	var out: Array[Button] = []
	var list: Array = sea.gear.get(kind, [])
	var cur := int(save.gear.get(kind, 0))
	for i in list.size():
		var g: Dictionary = list[i]
		var b := UI.button("", 20)
		var status := ""
		if i == cur:
			status = "Using"
		elif i < cur:
			status = "Owned"
		else:
			status = "%d Shells" % int(g.price)
		b.text = "%s   %s\n    %s" % [g.n, status, _describe(kind, g, i)]
		if i <= cur:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		else:
			b.pressed.connect(_buy_gear.bind(kind, i))
			if int(save.shells) < int(g.price):
				b.add_theme_color_override("font_color", UI.DIM)
		out.append(b)
	return out


func _describe(kind: String, g: Dictionary, i: int) -> String:
	match kind:
		"rod":
			var text := "Casts %d m, fish pull %d%% less" % [int(4.0 + 10.0 * float(g.cast)), int(round((1.0 - 1.0 / pow(float(g.power), 0.6)) * 100.0))]
			if i >= 2:
				text += ", can land legends"
			return text
		"reel":
			return "Reels %d%% faster, %d%% more drag" % [int(round((float(g.speed) - 1.0) * 100.0)), int(round((float(g.drag) - 1.0) * 100.0))]
		"line":
			return "Breaking strain x%.2f" % float(g.str)
	return ""


func _bait_rows() -> Array[Button]:
	var out: Array[Button] = []
	var dough := UI.button("Bread dough   Free\n    Endless. Small fish love it.", 20)
	dough.disabled = true
	dough.focus_mode = Control.FOCUS_NONE
	out.append(dough)
	for k in BAIT_STOCK:
		if not sea.bait.has(k):
			continue
		var b: Dictionary = sea.bait[k]
		var have := int(save.bait.get(k, 0))
		var lure := b.has("lure")
		var row := UI.button("", 20)
		var amount := "reusable" if lure else "pack of %d" % int(b.pack)
		if lure and have > 0:
			row.text = "%s   Owned\n    %s" % [b.n, b.d]
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			var held := "" if have == 0 else "   (you have %d)" % have
			row.text = "%s   %d Shells, %s%s\n    %s" % [b.n, int(b.price), amount, held, b.d]
			row.pressed.connect(_buy_bait.bind(k))
			if int(save.shells) < int(b.price):
				row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _buy_gear(kind: String, i: int) -> void:
	var g: Dictionary = sea.gear[kind][i]
	var price := int(g.price)
	if int(save.shells) < price:
		_fail("You need %d more Shells for the %s." % [price - int(save.shells), g.n])
		return
	save.shells = int(save.shells) - price
	save.gear[kind] = i
	_done("Bought the %s!" % g.n)
	_show_tab(_tab, 0)


func _buy_bait(k: String) -> void:
	var b: Dictionary = sea.bait[k]
	var price := int(b.price)
	if int(save.shells) < price:
		_fail("You need %d more Shells for %s." % [price - int(save.shells), str(b.n).to_lower()])
		return
	save.shells = int(save.shells) - price
	save.bait[k] = int(save.bait.get(k, 0)) + (1 if b.has("lure") else int(b.pack))
	save.bait_sel = k
	_done("Bought %s. It's on your hook now (R switches bait)." % str(b.n).to_lower())
	var row := BAIT_STOCK.find(k)
	_show_tab(_tab, row)


func _done(text: String) -> void:
	SaveGame.write(save)
	hud.set_shells(save.shells)
	hud.refresh_bait()
	audio.play("buy")
	audio.play("coin", -4.0)
	_message.add_theme_color_override("font_color", UI.GOOD)
	_message.text = text


func _fail(text: String) -> void:
	audio.play("error")
	_message.add_theme_color_override("font_color", UI.BAD)
	_message.text = text
