extends CanvasLayer
## Your Journal (J, or click the left stick): the mystery of the Gull's Eye so far, side
## quests and mini-game records, the bottle letters you've found, and how much of the sea
## you've collected. Q / E or left / right turn the page, Esc or J closes.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Mystery := preload("res://scripts/mystery.gd")

const TABS := ["The Gull's Eye", "Quests and games", "Letters", "Collection"]

var save: Dictionary
var sea: Node
var hud: CanvasLayer
var audio: Node
var mystery: Node3D
var sidequests: Node3D
var minigames: Node3D
var companion: Node3D
var story: Node  # the main story
var land_story: Node  # Harbour Life
var is_open := false
var _tab := 0
var _tabs: Array[Button] = []
var _text: RichTextLabel


func setup(sv: Dictionary, s: Node, h: CanvasLayer, a: Node) -> void:
	save = sv
	sea = s
	hud = h
	audio = a
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(860.0, 600.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UI.label("Journal", 34, UI.GOLD, true))
	for i in TABS.size():
		var t := UI.button(TABS[i], 20)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show.bind(i))
		top.add_child(t)
		_tabs.append(t)
	col.add_child(top)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.custom_minimum_size = Vector2(820.0, 470.0)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UI.font(false))
	_text.add_theme_font_override("bold_font", UI.font(true))
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_text.add_theme_color_override("default_color", UI.CREAM)
	col.add_child(_text)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{rotate_left}/{rotate_right} turn the page   {updown} scroll   {journal} or {cancel} close"))


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	audio.play("cardflip", -4.0)
	_show(_tab)


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("rotate_left") or (event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")):
		get_viewport().set_input_as_handled()
		_show((_tab + TABS.size() - 1) % TABS.size())
	elif event.is_action_pressed("rotate_right") or (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		_show((_tab + 1) % TABS.size())
	elif (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		_text.get_v_scroll_bar().value += 60.0
	elif (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		get_viewport().set_input_as_handled()
		_text.get_v_scroll_bar().value -= 60.0


func _show(i: int) -> void:
	_tab = i
	for t in _tabs.size():
		_tabs[t].add_theme_color_override("font_color", UI.GOLD if t == i else UI.CREAM)
	match i:
		0:
			_text.text = _mystery_text()
		1:
			_text.text = _quest_text()
		2:
			_text.text = _letters_text()
		_:
			_text.text = _collection_text()
	_text.scroll_to_line(0)
	audio.play("click", -10.0)


func _mystery_text() -> String:
	var step: int = mystery.step()
	var out := ""
	for k in range(0, step + 1):
		var p: Dictionary = mystery.page(k)
		out += "[color=#ffd24d][b]%s[/b][/color]\n%s\n" % [p.title, p.text]
		if k == step:
			out += "\n[color=#8fd3ff][b]What next:[/b] %s[/color]\n" % p.riddle
		out += "\n"
	if step >= 9:
		out += "[color=#8ad08a]You've solved the mystery of the Gull's Eye.[/color]\n"
	else:
		out += "[color=#9aa4b4]Look for the keeper's mark, a gull with one wing, carved in stone around the coast.[/color]\n"
	return out


func _quest_text() -> String:
	var lines: Array[String] = []
	if story:
		lines.append("[color=#ffd24d][b]The story[/b][/color]")
		lines.append_array(story.journal_lines())
		lines.append("")
	if land_story:
		lines.append("[color=#8ad08a][b]Harbour Life[/b][/color]")
		lines.append_array(land_story.journal_lines())
		lines.append("")
	var reqs: Array = save.requests
	if not reqs.is_empty():
		lines.append("[color=#ffd24d][b]Townsfolk requests[/b][/color] (optional: catch one that fits and bring it over)")
		for req in reqs:
			var e: Dictionary = sea.by_id.get(req.id, {})
			var what := str(e.get("n", req.id))
			if float(req.get("min", 0.0)) > 0.0:
				what += " %d cm+" % int(req.min)
			lines.append("%s wants: %s (%d Shells)%s" % [req.who, what, int(req.get("reward", 0)), "   [color=#8ad08a]Ready![/color]" if req.held else ""])
		lines.append("")
	lines.append("[color=#ffd24d][b]Side quests[/b][/color]")
	lines.append_array(sidequests.journal_lines())
	lines.append("")
	lines.append("[color=#ffd24d][b]Games[/b][/color]")
	lines.append_array(minigames.journal_lines())
	lines.append("")
	lines.append("[color=#ffd24d][b]Your companion[/b][/color]")
	var n: String = companion.companion_name()
	if n == "":
		lines.append("No companion yet. Feed a town cat fish from your bait tin (pilchards, live yakka, squid or prawns) to win its trust.")
	else:
		lines.append("%s follows you everywhere, and sniffs out buried finds." % n)
	return "\n".join(lines)


func _letters_text() -> String:
	var book: Dictionary = save.log
	var out := ""
	for i in range(1, 13):
		var id := "letter_%d" % i
		var e: Dictionary = sea.by_id.get(id, {})
		var title := str(e.get("n", "Letter %d" % i))
		if book.has(id):
			out += "[color=#ffd24d][b]%s[/b][/color]\n%s\n\n" % [title, Mystery.LETTERS.get(id, "")]
		else:
			out += "[color=#6a7080][b]Letter %d: not found yet[/b][/color]\n[color=#6a7080]%s[/color]\n\n" % [i, str(e.get("hint", "Bottles float about the sea."))]
	return out


func _collection_text() -> String:
	var book: Dictionary = save.log
	var groups := {"Fish": ["fish"], "Legends": ["legend"], "Shells and pearls": ["shell", "pearl"], "Coral": ["coral"],
		"Sea glass and curios": ["curio"], "Fossils": ["fossil"], "Treasure": ["treasure", "set"], "Junk": ["junk"]}
	var out := "[color=#ffd24d][b]Your collection[/b][/color]\n"
	var all_have := 0
	var all_total := 0
	for g in groups:
		var cats: Array = groups[g]
		var have := 0
		var total := 0
		for e in sea.items:
			if not cats.has(str(e.cat)) or str(e.get("how", "")) == "pot" or str(e.z) == "unknown":
				continue
			total += 1
			if book.has(e.id):
				have += 1
		if total == 0:
			continue
		all_have += have
		all_total += total
		var bar := int(round(20.0 * have / float(total)))
		out += "%s   [color=#ffd24d]%s[/color][color=#3a4050]%s[/color]  %d / %d\n" % [g.rpad(22), "|".repeat(bar), "|".repeat(20 - bar), have, total]
	out += "\n[b]Everything:[/b] %d of %d (%d%%)\n" % [all_have, all_total, int(round(100.0 * all_have / maxf(1.0, float(all_total))))]
	# rare variants you've caught
	var variants := {"g": "golden", "a": "albino", "m": "moonlit", "s": "storm-touched", "p": "ghostly", "r": "rainbow"}
	var vcount := {}
	for id in book:
		var entry: Dictionary = book[id]
		for v in variants:
			if int(entry.get(v, 0)) > 0:
				vcount[v] = int(vcount.get(v, 0)) + 1
	if not vcount.is_empty():
		var parts: Array[String] = []
		for v in vcount:
			parts.append("%d %s" % [int(vcount[v]), variants[v]])
		out += "[b]Rare variants caught:[/b] %s\n" % ", ".join(parts)
	return out
