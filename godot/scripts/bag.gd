extends CanvasLayer
## Your bag (I, or from the game menu): gear, bait, materials, special items and permits,
## your boat, and furniture waiting at the hut.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Furniture := preload("res://scripts/furniture.gd")
const Boats := preload("res://scripts/boats.gd")

var save: Dictionary
var sea: Node
var hud: CanvasLayer
var audio: Node
var extra_sections: Array[Callable] = []  # other systems add their own lines (pots, clothes...)
var is_open := false
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
	panel.custom_minimum_size = Vector2(820.0, 580.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UI.label("Your bag", 34, UI.GOLD, true))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(780.0, 470.0)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UI.font(false))
	_text.add_theme_font_override("bold_font", UI.font(true))
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_text.add_theme_color_override("default_color", UI.CREAM)
	col.add_child(_text)
	col.add_child(Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} scroll   {bag} or {cancel} close"))


func open() -> void:
	_text.text = _contents()
	is_open = true
	visible = true
	get_tree().paused = true
	audio.play("cardflip", -6.0)


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("bag"):
		get_viewport().set_input_as_handled()
		close()
	elif (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		_text.get_v_scroll_bar().value += 60.0
	elif (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		_text.get_v_scroll_bar().value -= 60.0


func _head(t: String) -> String:
	return "[color=#ffd24d][b]%s[/b][/color]\n" % t


func _contents() -> String:
	var out := ""
	out += _head("Gear")
	var gear: Dictionary = save.gear
	for k in ["rod", "reel", "line"]:
		var list: Array = sea.gear.get(k, [])
		var i := int(gear.get(k, 0))
		if i < list.size():
			out += "%s: %s\n" % [k.capitalize(), str(list[i].n)]
	out += "\n" + _head("Bait tin")
	var tin: Dictionary = save.bait
	var any := false
	for k in sea.bait_order:
		var n := int(tin.get(k, 0))
		var b: Dictionary = sea.bait.get(k, {})
		if n > 0 or k == "dough":
			any = true
			out += "%s: %s%s\n" % [str(b.get("n", k)), "plenty" if k == "dough" else str(n), "   (on your hook)" if str(save.bait_sel) == str(k) else ""]
	if not any:
		out += "Empty.\n"
	out += "\n" + _head("Materials")
	var m: Dictionary = save.materials
	out += "Driftwood %d   Rope %d   Scrap metal %d\n" % [int(m.get("wood", 0)), int(m.get("rope", 0)), int(m.get("scrap", 0))]
	out += "\n" + _head("Special things")
	var specials: Array[String] = []
	var myst: Dictionary = save.mystery
	if int(myst.get("step", 0)) >= 6 and int(myst.get("step", 0)) < 8:
		specials.append("A brass key marked LANTERN KEY")
	if bool(myst.get("eye", false)) and not bool(myst.get("restored", false)):
		specials.append("The Gull's Eye, wrapped in sailcloth")
	var permits: Dictionary = save.permits
	if permits.has("permit_ranger"):
		specials.append("Ranger's permit (the highlands and Mirrorlake)")
	if permits.has("permit_ember"):
		specials.append("Ember Isle landing permit")
	out += ("\n".join(specials) if not specials.is_empty() else "Nothing yet.") + "\n"
	out += "\n" + _head("Boat")
	var boat := str(save.boat)
	if boat == "":
		out += "No boat yet. The Boatyard in Gullhaven sells them.\n"
	else:
		var info: Dictionary = Boats.boat_info(boat)
		var parts: Dictionary = save.boat_parts
		out += "%s%s\n" % [str(info.get("n", boat)), "   with a deck lamp" if parts.has("lamp") else ""]
	for f in extra_sections:
		out += "\n" + str(f.call())
	var inv: Dictionary = save.furniture_inv
	if not inv.is_empty():
		out += "\n" + _head("Furniture waiting at your hut")
		var items: Array[String] = []
		for id in inv:
			var data: Dictionary = Furniture.ITEMS.get(id, {})
			items.append("%s x%d" % [str(data.get("n", id)), int(inv[id])])
		out += ", ".join(items) + "\n"
	return out
