extends CanvasLayer
## The tackle and bait shops: Hale's Tackle in Gullhaven sells rods, reels, lines and bait;
## the general store and the island tea houses sell the baits their waters call for.
## All at the web game's prices. Up/down picks, Space (or Enter, pad A, a click) buys,
## left/right changes tab, Esc leaves. The game pauses while you browse.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TAB_NAMES := {"rod": "Rods", "reel": "Reels", "line": "Lines", "bait": "Bait", "kit": "Kit"}
# other ways to fish, unlocked by fisher level (see progress.gd)
const KIT := {
	"pot": {"n": "Crab pot", "price": 250, "max": 4, "d": "Drop it in the shallows, the estuary, kelp or a wreck; haul it up later for crabs and lobsters."},
	"net": {"n": "Cast net", "price": 900, "max": 1, "d": "Throw it over a bait school for live bait and a few small fish at once."},
	"troll": {"n": "Trolling rig", "price": 1400, "max": 1, "d": "Tow lures behind your boat at speed. The fast fish of open water hit hard."},
	"spear": {"n": "Snorkel and speargun", "price": 1600, "max": 1, "d": "Stop your boat over clear water (reef, kelp, shallows, a wreck) and dive."},
}
const KIT_ORDER := ["pot", "net", "troll", "spear"]
const KINDS := ["rod", "reel", "line"]
# What each kind of shop sells: its tabs and the baits its waters call for.
const STOCK := {
	"tackle": {"tabs": ["rod", "reel", "line", "bait", "kit"], "bait": ["worm", "prawn", "pilchard", "weedbait", "squidjig", "metal", "livebait", "glow"]},
	"general": {"tabs": ["line", "bait"], "bait": ["worm", "prawn", "weedbait", "crabbait"]},
	"baittea": {"tabs": ["bait"], "bait": ["worm", "prawn", "pilchard", "squid", "crabbait", "livebait"]},
	"kelptea": {"tabs": ["bait"], "bait": ["squid", "crabbait", "squidjig", "popper", "glow"]},
}
const GREETINGS := {
	"tackle": [
		"Line's cheap, fish aren't. What'll it be?",
		"Back again? The fish must be biting.",
		"Mind the hooks. What can I get you?",
		"Worms are fresh today. Mostly.",
	],
	"general": [
		"A bit of everything, and fresh worms by the door.",
		"River fish like a worm. Bream like a prawn.",
	],
	"baittea": [
		"Tea's on the pot and the prawns are lively. Take your pick, love.",
		"The shallows round here are thick with whiting. Worms, I'd say.",
	],
	"kelptea": [
		"Squid in the kelp take a jig. Patience takes tea.",
		"The deep things like a glow. Pricey, but they work.",
	],
}

var sea: Node
var save: Dictionary
var audio: Node
var hud: CanvasLayer
var progress: Node  # fisher level: better gear and kit need higher levels
var is_open := false
var kind := "tackle"
var keeper := "Hale"
var _tabs_here: Array = ["rod", "reel", "line", "bait"]
var _bait_here: Array = []
var _tab := 0
var _title: Label
var _tab_row: HBoxContainer
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
	_title = UI.label("Hale's Tackle", 34, UI.GOLD, true)
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

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	col.add_child(_tab_row)

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
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} choose   {action} buy   {leftright} change tab   {cancel} leave"))


## Open a shop: who's behind the counter, the sign over the door, and what kind of shop.
func open(who := "Hale", title := "Hale's Tackle", shop_kind := "tackle") -> void:
	if not STOCK.has(shop_kind):
		shop_kind = "tackle"
	if shop_kind != kind:
		_tab = 0
	kind = shop_kind
	keeper = who
	_tabs_here = STOCK[kind].tabs
	_bait_here = STOCK[kind].bait
	_title.text = title
	_make_tabs()
	is_open = true
	visible = true
	get_tree().paused = true
	var lines: Array = GREETINGS.get(kind, GREETINGS.tackle)
	_greeting.text = "%s: \"%s\"" % [keeper, lines[randi() % lines.size()]]
	_message.text = ""
	_show_tab(mini(_tab, _tabs_here.size() - 1))


func _make_tabs() -> void:
	for t in _tabs:
		t.queue_free()
	_tabs.clear()
	for i in _tabs_here.size():
		var t := UI.button(str(TAB_NAMES[_tabs_here[i]]), 22)
		t.alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.custom_minimum_size = Vector2(120.0, 0.0)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(i))
		_tab_row.add_child(t)
		_tabs.append(t)
	_tab_row.visible = _tabs_here.size() > 1


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
		_show_tab((_tab + _tabs_here.size() - 1) % _tabs_here.size())
	elif (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_show_tab((_tab + 1) % _tabs_here.size())


func _show_tab(i: int, focus_row := 0) -> void:
	_tab = i
	_shells.text = "%d Shells" % int(save.shells)
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	for c in _list.get_children():
		c.queue_free()
	var rows: Array[Button] = []
	var what := str(_tabs_here[i])
	if what == "bait":
		rows = _bait_rows()
	elif what == "kit":
		rows = _kit_rows()
	else:
		rows = _gear_rows(what)
	var focusable: Array[Button] = []
	for b in rows:
		_list.add_child(b)
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		focusable[clampi(focus_row, 0, focusable.size() - 1)].call_deferred("grab_focus")
	audio.play("click", -8.0)


func _gear_rows(gear_kind: String) -> Array[Button]:
	var out: Array[Button] = []
	var list: Array = sea.gear.get(gear_kind, [])
	var cur := int(save.gear.get(gear_kind, 0))
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
		var locked := progress != null and i > cur and not progress.gear_ok(gear_kind, i)
		if locked:
			status = "Needs Fisher Lv %d" % progress.gear_level(gear_kind, i)
		b.text = "%s   %s\n    %s" % [g.n, status, _describe(gear_kind, g, i)]
		if i <= cur:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		else:
			b.pressed.connect(_buy_gear.bind(gear_kind, i))
			if int(save.shells) < int(g.price) or locked:
				b.add_theme_color_override("font_color", UI.DIM)
		out.append(b)
	return out


func _describe(gear_kind: String, g: Dictionary, i: int) -> String:
	match gear_kind:
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
	for k in _bait_here:
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


func _buy_gear(gear_kind: String, i: int) -> void:
	var g: Dictionary = sea.gear[gear_kind][i]
	var price := int(g.price)
	if progress and not progress.gear_ok(gear_kind, i):
		_fail("%s: \"That one's for a more practised hand. Come back at Fisher level %d.\"" % [keeper, progress.gear_level(gear_kind, i)])
		return
	if int(save.shells) < price:
		_fail("You need %d more Shells for the %s." % [price - int(save.shells), g.n])
		return
	save.shells = int(save.shells) - price
	save.gear[gear_kind] = i
	_done("Bought the %s!" % g.n)
	_show_tab(_tab, 0)


func _kit_rows() -> Array[Button]:
	var out: Array[Button] = []
	var kit: Dictionary = save.kit
	for k in KIT_ORDER:
		var item: Dictionary = KIT[k]
		var have := int(kit.get(k, 0))
		var row := UI.button("", 20)
		var lv := 1
		if progress:
			lv = int(progress.KIT_LEVEL.get(k, 1))
		var locked := progress != null and not progress.kit_ok(k)
		if have >= int(item.max):
			row.text = "%s   %s\n    %s" % [item.n, "Owned" if int(item.max) == 1 else "You have %d (the most you can use)" % have, item.d]
			row.disabled = true
			row.focus_mode = Control.FOCUS_NONE
		else:
			var status := "Needs Fisher Lv %d" % lv if locked else "%d Shells" % int(item.price)
			if int(item.max) > 1 and have > 0:
				status += "   (you have %d)" % have
			row.text = "%s   %s\n    %s" % [item.n, status, item.d]
			row.pressed.connect(_buy_kit.bind(k))
			if locked or int(save.shells) < int(item.price):
				row.add_theme_color_override("font_color", UI.DIM)
		out.append(row)
	return out


func _buy_kit(k: String) -> void:
	var item: Dictionary = KIT[k]
	if progress and not progress.kit_ok(k):
		_fail("%s: \"Get a few more fish under your belt first. Fisher level %d.\"" % [keeper, int(progress.KIT_LEVEL.get(k, 1))])
		return
	var price := int(item.price)
	if int(save.shells) < price:
		_fail("You need %d more Shells for the %s." % [price - int(save.shells), str(item.n).to_lower()])
		return
	save.shells = int(save.shells) - price
	var kit: Dictionary = save.kit
	kit[k] = int(kit.get(k, 0)) + 1
	_done("Bought the %s! Use your kit with {tool}." % str(item.n).to_lower())
	_message.text = Glyphs.plain(_message.text)
	_show_tab(_tab, KIT_ORDER.find(k))


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
	var row := _bait_here.find(k)
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
