extends RefCounted
## Puts your character together from the layered art in art/wardrobe (made by
## tools/godot_wardrobe.py): hair behind, body and clothes, glasses, beard, hair in front and
## a hat, each pixel coloured from your choices with the same colour ramp the townsfolk
## painter uses, then outlined. The result is a normal 5 x 4 character sheet.

const LAYERS_JSON := "res://art/wardrobe/layers.json"
const LAYERS_BIN := "res://art/wardrobe/layers.bin"

const SKINS := {"fair": "#f6d2b4", "rose": "#f0bea0", "olive": "#d0a47a", "tan": "#d9a07a", "brown": "#a8714e", "deep": "#7a4e36"}
const SKIN_ORDER := ["fair", "rose", "olive", "tan", "brown", "deep"]

static var _meta := {}
static var _layers := {}  # name -> PackedByteArray (RGBA rows)
static var _filled := {}  # name -> PackedInt32Array of the pixels that aren't empty
static var _w := 160
static var _h := 192
static var _fw := 32
static var _fh := 48


## The look you start with: the fisher in the knitted beanie and mustard rain jacket.
static func default_look() -> Dictionary:
	return {"skin": "rose", "hair": "#6a4028", "style": "short", "beard": "", "glasses": false, "hat": "beanie",
		"hatc": "#2f8a8a", "shirt": "#e8b23a", "pattern": "none", "patc": "#f4f0e8", "top": "coat", "garment": "#5f8f5a",
		"legs": "trousers", "pants": "#2e3f6e", "shoes": "#5a3a26"}


static func meta() -> Dictionary:
	_load()
	return _meta


static func _load() -> bool:
	if not _layers.is_empty():
		return true
	var jf := FileAccess.open(LAYERS_JSON, FileAccess.READ)
	var bf := FileAccess.open(LAYERS_BIN, FileAccess.READ)
	if jf == null or bf == null:
		push_warning("Character layers missing (run tools/godot_wardrobe.py)")
		return false
	var parsed: Variant = JSON.parse_string(jf.get_as_text())
	if not (parsed is Dictionary):
		return false
	_meta = parsed
	_w = int(_meta.size[0])
	_h = int(_meta.size[1])
	_fw = int(_meta.frame[0])
	_fh = int(_meta.frame[1])
	var raw := bf.get_buffer(bf.get_length()).decompress(int(_meta.bytes), FileAccess.COMPRESSION_GZIP)
	var n := _w * _h * 4
	var offsets: Dictionary = _meta.layers
	for name in offsets:
		var o := int(offsets[name])
		var data := raw.slice(o, o + n)
		_layers[name] = data
		var px := PackedInt32Array()
		for i in _w * _h:
			if data[i * 4 + 3] != 0:
				px.append(i)
		_filled[name] = px
	return true


# --- the same colour ramp as tools/godot_art.py ----------------------------------------------

static func _shift(c: Color, dv: float, ds := 0.0) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * (1.0 + ds), 0.0, 1.0), clampf(c.v * (1.0 + dv), 0.0, 1.0))


static func _toward(c: Color, target_h: float, amount: float) -> Color:
	var d := fposmod(target_h - c.h + 0.5, 1.0) - 0.5
	return Color.from_hsv(fposmod(c.h + d * amount, 1.0), c.s, c.v)


## outline, dark, mid, base, light, highlight: shadows lean blue, lights lean warm.
static func ramp(base: Color) -> Array[Color]:
	return [_toward(_shift(base, -0.6, 0.25), 0.72, 0.2), _toward(_shift(base, -0.3, 0.15), 0.68, 0.12),
		_toward(_shift(base, -0.14, 0.06), 0.68, 0.06), base, _toward(_shift(base, 0.14, -0.12), 0.12, 0.06),
		_toward(_shift(base, 0.3, -0.3), 0.12, 0.1)]


static func colour_of(look: Dictionary, slot: String) -> Color:
	match slot:
		"skin":
			return Color(str(SKINS.get(str(look.get("skin", "rose")), "#f0bea0")))
		"hair":
			return Color(str(look.get("hair", "#6a4028")))
		"hat":
			return Color(str(look.get("hatc", "#888888")))
		"pattern", "floral":
			return Color(str(look.get("patc", "#f4f0e8")))
		_:
			return Color(str(look.get(slot, "#888888")))


## Which layers this look is made of, back to front.
static func layer_names(look: Dictionary) -> Array[String]:
	var style := str(look.get("style", "short"))
	var names: Array[String] = ["hair_back/" + style]
	names.append("body/%s/%s/%s" % [str(look.get("legs", "trousers")), str(look.get("top", "tee")), str(look.get("pattern", "none"))])
	if bool(look.get("glasses", false)):
		names.append("glasses")
	if str(look.get("beard", "")) != "":
		names.append("beard/" + str(look.beard))
	names.append("hair_front/" + style)
	if str(look.get("hat", "")) != "":
		names.append("hat/" + str(look.hat))
	return names


static func image(look: Dictionary) -> Image:
	if not _load():
		return null
	var slots: Array = _meta.slots
	var dvs: Array = _meta.dvs
	# every colour each slot can come out as: [slot][darkening][tone] -> rgb
	var tables: Array[PackedByteArray] = []
	var outline_rgb: Array[PackedByteArray] = []
	for s in slots.size():
		var tb := PackedByteArray()
		var ob := PackedByteArray()
		ob.resize(3)
		if str(slots[s]) != "":
			var base := colour_of(look, str(slots[s]))
			for dv in dvs:
				var r := ramp(base if float(dv) == 0.0 else _shift(base, float(dv)))
				for c in r:
					tb.append(c.r8)
					tb.append(c.g8)
					tb.append(c.b8)
			var o0 := ramp(base)[0]
			ob[0] = o0.r8
			ob[1] = o0.g8
			ob[2] = o0.b8
		tables.append(tb)
		outline_rgb.append(ob)
	var out := PackedByteArray()
	out.resize(_w * _h * 4)
	var edge := PackedByteArray()  # each pixel's outline colour
	edge.resize(_w * _h * 3)
	for name in layer_names(look):
		if not _layers.has(name):
			continue
		var data: PackedByteArray = _layers[name]
		var px: PackedInt32Array = _filled[name]
		for i in px:
			var o := i * 4
			if data[o + 3] == 254:
				var slot := data[o]
				var k := (data[o + 1] * 6 + data[o + 2]) * 3
				var tb := tables[slot]
				out[o] = tb[k]
				out[o + 1] = tb[k + 1]
				out[o + 2] = tb[k + 2]
				var ob := outline_rgb[slot]
				edge[i * 3] = ob[0]
				edge[i * 3 + 1] = ob[1]
				edge[i * 3 + 2] = ob[2]
			else:
				out[o] = data[o]
				out[o + 1] = data[o + 1]
				out[o + 2] = data[o + 2]
				edge[i * 3] = int(data[o] * 0.35)
				edge[i * 3 + 1] = int(data[o + 1] * 0.35)
				edge[i * 3 + 2] = int(data[o + 2] * 0.35)
			out[o + 3] = 255
	# the outline: empty pixels touching the sprite (within the same frame) take the darkest
	# tone of what they touch
	var solid := PackedByteArray()
	solid.resize(_w * _h)
	for i in _w * _h:
		solid[i] = 1 if out[i * 4 + 3] != 0 else 0
	for i in _w * _h:
		if solid[i] == 0:
			continue
		var x := i % _w
		var y := i / _w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= _w or ny >= _h or nx / _fw != x / _fw or ny / _fh != y / _fh:
				continue
			var j := ny * _w + nx
			if solid[j] != 0 or out[j * 4 + 3] != 0:
				continue
			out[j * 4] = edge[i * 3]
			out[j * 4 + 1] = edge[i * 3 + 1]
			out[j * 4 + 2] = edge[i * 3 + 2]
			out[j * 4 + 3] = 255
	return Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, out)


static func texture(look: Dictionary) -> Texture2D:
	var img := image(look)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
