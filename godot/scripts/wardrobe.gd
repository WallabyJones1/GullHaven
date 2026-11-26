extends CanvasLayer
## Making your fisher, and Threads & Tides, the outfitter in Gullhaven.
## A new game opens the creator: skin, hair, face, hat, shirt, jacket, trousers or a dress,
## shoes, all with a live preview. Odette at Threads & Tides lets you change any of it
## later, and sells what the creator doesn't have: more hats, patterns, overalls and aprons,
## dresses, and dyes for brighter colours. Pick freely, see the total, then buy and wear.
## {updown} picks a row, {leftright} changes it, {action} on the last row finishes.

const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Character := preload("res://scripts/character.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const HAIR_STYLES := ["short", "bob", "long", "ponytail", "bun", "spiky", "bald"]
const BEARDS := ["", "stubble", "mustache", "short", "full"]
const HATS := ["", "beanie", "cap", "bucket", "straw", "bandana", "ranger", "captain"]
const TOPS := ["tee", "coat", "vest", "overalls", "apron"]
const PATTERNS := ["none", "stripes", "checks", "floral"]
const LEGS := ["trousers", "dress"]
const NAMES := {"": "None", "short": "Short", "bob": "Bob", "long": "Long", "ponytail": "Ponytail", "bun": "Bun", "spiky": "Spiky",
	"bald": "Bald", "stubble": "Stubble", "mustache": "Moustache", "full": "Full beard", "beanie": "Knitted beanie",
	"cap": "Cap", "bucket": "Bucket hat", "straw": "Straw hat", "bandana": "Bandana", "ranger": "Ranger's hat",
	"captain": "Captain's cap", "tee": "Just the shirt", "coat": "Rain jacket", "vest": "Waistcoat", "overalls": "Overalls",
	"apron": "Apron", "none": "Plain", "stripes": "Stripes", "checks": "Checks", "floral": "Flowers", "trousers": "Trousers",
	"dress": "Dress", "fair": "Fair", "rose": "Rose", "olive": "Olive", "tan": "Tan", "brown": "Brown", "deep": "Deep",
	"false": "No", "true": "Yes"}
const HAIR_COLOURS := ["#2a1a14", "#4a2a1a", "#6a4028", "#a8642a", "#d8782a", "#e8c070", "#c8c4bc", "#ece8e0"]
const HAIR_DYES := ["#c84a6a", "#8a3a8a", "#3a6aaa", "#5aa86a"]
const CLOTH := ["#e8b23a", "#c84a3a", "#2e3f6e", "#5f8f5a", "#2f8a8a", "#f4f0e8", "#3a3a40", "#7aa0d8", "#8a6a3a", "#5a3a26"]
const CLOTH_DYES := ["#e88aa0", "#c87ac8", "#3aa8a0", "#f0d050", "#6a3a4a", "#d8604a", "#1a1a22", "#a8d8a0"]
# what Odette sells (anything not listed is free)
const PRICES := {"top:overalls": 400, "top:apron": 300, "pattern:checks": 250, "pattern:floral": 350, "legs:dress": 450,
	"hat:bucket": 300, "hat:straw": 350, "hat:bandana": 250, "hat:ranger": 600, "hat:captain": 1200, "dye:hair": 300,
	"dye:bright": 500}
const ITEM_NAMES := {"top:overalls": "overalls", "top:apron": "an apron", "pattern:checks": "check cloth",
	"pattern:floral": "flowery cloth", "legs:dress": "a dress", "hat:bucket": "a bucket hat", "hat:straw": "a straw hat",
	"hat:bandana": "a bandana", "hat:ranger": "a ranger's hat", "hat:captain": "a captain's cap", "dye:hair": "hair dye",
	"dye:bright": "bright dyes"}
const GREETINGS := ["Odette: \"Come in, come in! Salt air is murder on a wardrobe. Let's fix you up.\"",
	"Odette: \"Ah, a fisher with taste. Or at least a fisher. Let's see what we can do.\"",
	"Odette: \"Fresh bolts in from the islands. That captain's cap won't wear itself, you know.\""]

var save: Dictionary
var hud: CanvasLayer
var audio: Node
var player: CharacterBody3D
var is_open := false
var mode := ""  # "create" or "shop"
var look := {}
var _before := {}
var _rows: Array = []  # {key, label, kind, options, box, value, swatch, price, name}
var _sel := 0
var _done: Variant = null
var _tex: Texture2D
var _preview: TextureRect
var _atlas: AtlasTexture
var _title: Label
var _sub: Label
var _total: Label
var _msg: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _anim_t := 0.0


var _leave_btn: Button

func setup(sv: Dictionary, h: CanvasLayer, a: Node, p: CharacterBody3D) -> void:
	save = sv
	hud = h
	audio = a
	player = p
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.08, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UI.panel(18.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = UI.label("", 34, UI.GOLD, true)
	col.add_child(_title)
	_sub = UI.label("", 20, UI.SKY)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(900.0, 0.0)
	col.add_child(_sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var stage := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.5, 0.62)
	sb.set_corner_radius_all(6)
	stage.add_theme_stylebox_override("panel", sb)
	row.add_child(stage)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(256.0, 384.0)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(_preview)
	_atlas = AtlasTexture.new()
	_preview.texture = _atlas
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(640.0, 440.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_total = UI.label("", 22, UI.GOLD, true)
	col.add_child(_total)
	_msg = UI.label("", 20, UI.GOOD)
	col.add_child(_msg)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	var hint := Glyphs.bind(UI.label("", 18, UI.DIM), "{updown} choose   {leftright} change   {action} on the last row to finish   {cancel} leave")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	# buttons too, for touch screens and mice
	var leave := UI.button("Back", 20)
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func() -> void:
		if is_open and mode == "shop":
			look = _before
			_close())
	foot.add_child(leave)
	_leave_btn = leave
	var done := UI.button("Done", 22)
	done.focus_mode = Control.FOCUS_NONE
	done.add_theme_color_override("font_color", UI.GOLD)
	done.pressed.connect(func() -> void:
		if is_open:
			_finish())
	foot.add_child(done)


## A new game: make your fisher. done() runs when you're happy.
func open_create(done: Variant = null) -> void:
	mode = "create"
	_done = done
	look = Character.default_look()
	var stored: Dictionary = save.look
	if not stored.is_empty():
		look.merge(stored, true)
	_title.text = "Make your fisher"
	_sub.text = "Gran always said you could tell a fisher by their hat. Odette at Threads & Tides in Gullhaven sells more of everything later."
	_open()


## Threads & Tides (the town service handler: who, title, kind).
func open_shop(_who := "Odette", title := "Threads & Tides", _kind := "outfitter") -> void:
	mode = "shop"
	_done = null
	look = Character.default_look()
	look.merge(save.look, true)
	_title.text = title
	_sub.text = GREETINGS[randi() % GREETINGS.size()]
	_open()


func _open() -> void:
	_before = look.duplicate()
	_build_rows()
	_sel = 0
	is_open = true
	visible = true
	if _leave_btn:
		_leave_btn.visible = mode == "shop"
	get_tree().paused = true
	hud.modal = true
	_msg.text = ""
	_rebuild()
	_mark()
	audio.play("cardflip", -6.0)


func _close() -> void:
	is_open = false
	visible = false
	hud.modal = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.35)


func owned(item: String) -> bool:
	if item == "" or not PRICES.has(item):
		return true
	return (save.wardrobe as Array).has(item)


func _available(item: String) -> bool:
	return mode == "shop" or owned(item)


# --- the rows -------------------------------------------------------------------------------

func _build_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	_add_row("skin", "Skin", "list", Character.SKIN_ORDER, "")
	_add_row("style", "Hair", "list", HAIR_STYLES, "")
	_add_row("hair", "Hair colour", "colour", _colours(HAIR_COLOURS, HAIR_DYES, "dye:hair"), "")
	_add_row("beard", "Beard", "list", BEARDS, "")
	_add_row("glasses", "Glasses", "toggle", [false, true], "")
	_add_row("hat", "Hat", "list", _filter(HATS, "hat"), "hat")
	_add_row("hatc", "Hat colour", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("shirt", "Shirt", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("pattern", "Pattern", "list", _filter(PATTERNS, "pattern"), "pattern")
	_add_row("patc", "Pattern colour", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("top", "Jacket", "list", _filter(TOPS, "top"), "top")
	_add_row("garment", "Jacket colour", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("legs", "Legs", "list", _filter(LEGS, "legs"), "legs")
	_add_row("pants", "Trousers", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("shoes", "Shoes", "colour", _colours(CLOTH, CLOTH_DYES, "dye:bright"), "")
	_add_row("done", "", "done", [], "")


func _filter(options: Array, prefix: String) -> Array:
	var out: Array = []
	for o in options:
		var item := "%s:%s" % [prefix, str(o)] if str(o) != "" else ""
		if _available(item):
			out.append(o)
	return out


func _colours(basic: Array, dyes: Array, dye_item: String) -> Array:
	var out: Array = basic.duplicate()
	if _available(dye_item):
		out.append_array(dyes)
	return out


func _add_row(key: String, label: String, kind: String, options: Array, prefix: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_list.add_child(box)
	var row := {"key": key, "kind": kind, "options": options, "prefix": prefix, "box": box}
	if kind == "done":
		var b := UI.label("", 24, UI.GOLD, true)
		b.custom_minimum_size = Vector2(600.0, 40.0)
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(b)
		row["name"] = b
		_rows.append(row)
		return
	var name_l := UI.label(label, 22, UI.CREAM, true)
	name_l.custom_minimum_size = Vector2(190.0, 0.0)
	box.add_child(name_l)
	var left := UI.button("<", 20)
	left.focus_mode = Control.FOCUS_NONE
	left.pressed.connect(_click.bind(_rows.size(), -1))
	box.add_child(left)
	var value := UI.label("", 21, UI.CREAM)
	value.custom_minimum_size = Vector2(200.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var right := UI.button(">", 20)
	right.focus_mode = Control.FOCUS_NONE
	right.pressed.connect(_click.bind(_rows.size(), 1))
	box.add_child(right)
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(34.0, 26.0)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(sw)
	var price := UI.label("", 18, UI.GOLD)
	box.add_child(price)
	row["name"] = name_l
	row["value"] = value
	row["swatch"] = sw
	row["price"] = price
	_rows.append(row)


func _item_for(row: Dictionary, v: Variant) -> String:
	var key := str(row.key)
	if str(row.kind) == "colour":
		if key == "hair":
			return "dye:hair" if HAIR_DYES.has(v) else ""
		return "dye:bright" if CLOTH_DYES.has(v) else ""
	if str(row.prefix) != "" and str(v) != "":
		return "%s:%s" % [str(row.prefix), str(v)]
	return ""


## Rows that don't matter for this look are dimmed (a jacket colour with no jacket...).
func _relevant(row: Dictionary) -> bool:
	match str(row.key):
		"hatc":
			return str(look.get("hat", "")) != ""
		"patc":
			return str(look.get("pattern", "none")) != "none"
		"garment":
			return str(look.get("top", "tee")) in ["vest", "overalls", "apron"]
		"pants":
			return str(look.get("legs", "trousers")) == "trousers"
	return true


func _refresh_rows() -> void:
	var cost := _cost()
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var name_l: Label = row.name
		if str(row.kind) == "done":
			var verb := "Done: off to Gullhaven!" if mode == "create" else (
				"Wear this" if cost == 0 else "Buy and wear for %d Shells" % cost)
			name_l.text = ("> " if i == _sel else "   ") + verb
			continue
		var v: Variant = look.get(str(row.key))
		var value: Label = row.value
		var sw: ColorRect = row.swatch
		var price: Label = row.price
		match str(row.kind):
			"colour":
				value.text = ""
				sw.visible = true
				sw.color = Color(str(v))
			"toggle":
				value.text = str(NAMES.get(str(bool(v)).to_lower(), str(v)))
				sw.visible = false
			_:
				value.text = str(NAMES.get(str(v), str(v).capitalize()))
				sw.visible = str(row.key) == "skin"
				if str(row.key) == "skin":
					sw.color = Color(str(Character.SKINS.get(str(v), "#f0bea0")))
		var item := _item_for(row, v)
		price.text = "" if owned(item) else "%d Shells" % int(PRICES[item])
		var on := _relevant(row)
		name_l.text = ("> " if i == _sel else "   ") + str(name_l.text).trim_prefix("> ").trim_prefix("   ")
		name_l.add_theme_color_override("font_color", UI.GOLD if i == _sel else (UI.CREAM if on else UI.DIM))
		value.add_theme_color_override("font_color", UI.CREAM if on else UI.DIM)
	_total.text = "" if mode == "create" or cost == 0 else "To pay: %d Shells   (you have %d)" % [cost, int(save.shells)]


func _cost() -> int:
	if mode != "shop":
		return 0
	var items := {}
	for row: Dictionary in _rows:
		if str(row.kind) == "done" or not _relevant(row):
			continue
		var item := _item_for(row, look.get(str(row.key)))
		if item != "" and not owned(item):
			items[item] = true
	var total := 0
	for item in items:
		total += int(PRICES[item])
	return total


func _mark() -> void:
	_refresh_rows()
	var box: Control = _rows[_sel].box
	_scroll.ensure_control_visible(box)


func _click(i: int, dir: int) -> void:
	_sel = i
	_change(dir)


func _change(dir: int) -> void:
	var row: Dictionary = _rows[_sel]
	if str(row.kind) == "done":
		return
	var opts: Array = row.options
	if opts.is_empty():
		return
	var cur := opts.find(look.get(str(row.key)))
	var nxt: Variant = opts[posmod(cur + dir, opts.size())]
	look[str(row.key)] = nxt
	audio.play("click", -6.0)
	_msg.text = ""
	_rebuild()
	_mark()


func _rebuild() -> void:
	_tex = Character.texture(look)
	_atlas.atlas = _tex
	_anim_t = 0.0
	_update_frame()


func _update_frame() -> void:
	if _tex == null:
		return
	var dirs := [0, 2, 1, 3]  # down, left, up, right
	var d: int = dirs[int(_anim_t / 1.6) % 4]
	var poses := [0, 1, 0, 2]
	var p: int = poses[int(_anim_t / 0.2) % 4]
	var fw := _tex.get_width() / 5.0
	var fh := _tex.get_height() / 4.0
	_atlas.region = Rect2(p * fw, d * fh, fw, fh)


func _process(delta: float) -> void:
	if not is_open:
		return
	_anim_t += delta
	_update_frame()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_sel = posmod(_sel - 1, _rows.size())
		audio.play("click", -10.0)
		_mark()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_sel = posmod(_sel + 1, _rows.size())
		audio.play("click", -10.0)
		_mark()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_change(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_change(1)
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		if event is InputEventMouseButton:
			return  # clicks go to the arrow buttons
		if str(_rows[_sel].kind) == "done":
			_finish()
		else:
			_change(1)
	elif event.is_action_pressed("cancel"):
		if mode == "shop":
			look = _before
			_close()
			audio.play("click")
		else:
			_sel = _rows.size() - 1
			_mark()
	else:
		return
	get_viewport().set_input_as_handled()


func _finish() -> void:
	var cost := _cost()
	if cost > int(save.shells):
		_msg.add_theme_color_override("font_color", UI.BAD)
		_msg.text = "Odette: \"That comes to %d Shells, love. You're %d short.\"" % [cost, cost - int(save.shells)]
		audio.play("error")
		return
	if cost > 0:
		save.shells = int(save.shells) - cost
		hud.set_shells(save.shells)
		for row: Dictionary in _rows:
			if str(row.kind) == "done" or not _relevant(row):
				continue
			var item := _item_for(row, look.get(str(row.key)))
			if item != "" and not owned(item):
				(save.wardrobe as Array).append(item)
		audio.play("buy")
		audio.play("coin", -4.0)
	save.look = look.duplicate()
	SaveGame.write(save)
	apply()
	_close()
	if mode == "shop":
		hud.toast("Odette: \"Now that's a fisher. Mind the fish guts.\"" if cost > 0 else "Looking sharp.")
	if _done is Callable:
		(_done as Callable).call()


## Dress the player in the saved look (nothing changes if there isn't one yet).
func apply() -> void:
	var stored: Dictionary = save.look
	if stored.is_empty():
		return
	var full := Character.default_look()
	full.merge(stored, true)
	var tex := Character.texture(full)
	if tex and player.get("sprite"):
		var spr: Sprite3D = player.get("sprite")
		spr.texture = tex
