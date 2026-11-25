extends RefCounted
## Homes (Harbour economy build, the Club Penguin / Habbo part): buy a plot in one of the
## season-1 districts with $GULL, then visit your home and make it yours: pick the
## wallpaper and floor, buy furniture in every colour from the catalogue, and arrange it.
## Everything comes from res://data/home_catalog.json (tools/godot_home_catalog.py).
## Catalogue pieces have ids like "sofa@red"; their sprites are art/decor/home/sofa_red.png.

const Harbour := preload("res://scripts/token/harbour.gd")
const CATALOG_PATH := "res://data/home_catalog.json"
const DEFAULT_WALL := "home/wall_plain_cream"
const DEFAULT_FLOOR := "home/floor_planks_oak"

static var _cat: Dictionary = {}
static var _bases: Dictionary = {}  # base -> catalogue entry
static var _cache: Dictionary = {}  # id -> data()


static func catalog() -> Dictionary:
	if _cat.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(CATALOG_PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		_cat = parsed if parsed is Dictionary else {}
		for k in ["items", "walls", "floors", "districts", "categories"]:
			if not _cat.has(k):
				_cat[k] = []
		for k in ["colours", "colour_names"]:
			if not _cat.has(k):
				_cat[k] = {}
		for it in _cat.items:
			_bases[str(it.base)] = it
	return _cat


static func colour_name(c: String) -> String:
	return str(catalog().colour_names.get(c, c.capitalize()))


static func colour(c: String) -> Color:
	return Color(str(catalog().colours.get(c, "#888888")))


static func item_id(base: String, c: String) -> String:
	return "%s@%s" % [base, c]


static func is_home_id(id: String) -> bool:
	return id.contains("@")


static func base_entry(base: String) -> Dictionary:
	catalog()
	return _bases.get(base, {})


## Everything the game needs to know about one catalogue piece, or {} if it isn't one.
## Same shape as Furniture.ITEMS entries (n, kind, cells / y, price) plus sprite, base,
## colour, cat and d.
static func data(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var out := {}
	var parts := id.split("@")
	if parts.size() == 2:
		var it := base_entry(parts[0])
		if not it.is_empty() and parts[1] in it.colours:
			out = {"n": "%s (%s)" % [it.n, colour_name(parts[1])], "kind": str(it.kind), "price": int(it.price),
				"cat": str(it.cat), "d": str(it.d), "sprite": "home/%s_%s" % [parts[0], parts[1]],
				"base": parts[0], "colour": parts[1], "mats": {}}
			if str(it.kind) == "wall":
				out.y = float(it.y)
			else:
				out.cells = Vector2i(int(it.cells[0]), int(it.cells[1]))
	_cache[id] = out
	return out


static func all_ids() -> Array:
	var out: Array = []
	for it in catalog().items:
		for c in it.colours:
			out.append(item_id(str(it.base), str(c)))
	return out


static func wall_tex(pattern: String, c: String) -> String:
	return "home/wall_%s_%s" % [pattern, c]


static func floor_tex(kind: String, c: String) -> String:
	return "home/floor_%s_%s" % [kind, c]


## The Shells price of a wallpaper or floor texture name, or -1 if it isn't one.
static func style_price(tex: String) -> int:
	for w in catalog().walls:
		for c in w.colours:
			if wall_tex(str(w.pattern), str(c)) == tex:
				return int(w.price)
	for f in catalog().floors:
		for c in f.colours:
			if floor_tex(str(f.kind), str(c)) == tex:
				return int(f.price)
	return -1


static func district(id: String) -> Dictionary:
	for d in catalog().districts:
		if str(d.id) == id:
			return d
	return {}


# --- the save's home ------------------------------------------------------------------

static func defaults() -> Dictionary:
	return {
		"plot": "",  # e.g. "V-001" ("" = no home yet)
		"district": "",
		"wall": DEFAULT_WALL,
		"floor": DEFAULT_FLOOR,
		"styles": [DEFAULT_WALL, DEFAULT_FLOOR],  # wallpapers and floors you own
		"furniture": [],  # placed in your home: same shape as save.furniture
	}


static func ensure(save: Dictionary) -> Dictionary:
	var h: Dictionary = save.get("home", {})
	var base := defaults()
	for k in base:
		if not h.has(k):
			h[k] = base[k]
	save["home"] = h
	return h


static func has_home(save: Dictionary) -> bool:
	return str(ensure(save).plot) != ""


## The room size (metres) of your home, from its district.
static func room_size(save: Dictionary) -> Vector2:
	var d := district(str(ensure(save).district))
	if d.is_empty():
		return Vector2(8.0, 7.0)
	return Vector2(float(d.room[0]), float(d.room[1]))


## Buy a plot with $GULL. `taken` is plot ids other players own (the server's list once
## homes are shared; empty in single player). You get the first free number.
static func buy_plot(save: Dictionary, district_id: String, taken := {}) -> Dictionary:
	var h := ensure(save)
	if str(h.plot) != "":
		return {"ok": false, "reason": "You already have a home at %s." % h.plot}
	var d := district(district_id)
	if d.is_empty():
		return {"ok": false, "reason": "There's no district called %s." % district_id}
	var plot := ""
	for n in range(1, int(d.count) + 1):
		var id := "%s-%03d" % [str(d.prefix), n]
		if not taken.has(id):
			plot = id
			break
	if plot == "":
		return {"ok": false, "reason": "Every %s plot has been taken." % d.n}
	var r := Harbour.spend(save, float(d.gull), "a %s plot" % d.n)
	if not r.ok:
		return r
	h.plot = plot
	h.district = district_id
	return {"ok": true, "plot": plot, "split": r.split}


static func buy_item(save: Dictionary, id: String) -> Dictionary:
	var d := data(id)
	if d.is_empty():
		return {"ok": false, "reason": "That isn't in the catalogue."}
	var price := int(d.price)
	if int(save.get("shells", 0)) < price:
		return {"ok": false, "reason": "You need %d more Shells for the %s." % [price - int(save.get("shells", 0)), str(d.n).to_lower()]}
	save["shells"] = int(save.get("shells", 0)) - price
	var inv: Dictionary = save.get("furniture_inv", {})
	inv[id] = int(inv.get(id, 0)) + 1
	save["furniture_inv"] = inv
	return {"ok": true, "n": d.n}


## Use a wallpaper or floor: free if you own it, otherwise it's bought (Shells) first.
static func use_style(save: Dictionary, tex: String) -> Dictionary:
	var h := ensure(save)
	var price := style_price(tex)
	if price < 0:
		return {"ok": false, "reason": "That isn't a wallpaper or a floor."}
	var owned: Array = h.styles
	var bought := false
	if not tex in owned:
		if int(save.get("shells", 0)) < price:
			return {"ok": false, "reason": "You need %d more Shells for that." % (price - int(save.get("shells", 0)))}
		save["shells"] = int(save.get("shells", 0)) - price
		owned.append(tex)
		bought = true
	if tex.begins_with("home/wall_"):
		h.wall = tex
	else:
		h.floor = tex
	return {"ok": true, "bought": bought}
