extends Node3D
## Driftwood Lane: twelve plots of land west of Gran's hut, one for each player. Walk up to a
## For Sale sign and the plot's yours (online, the shared town keeps track of who has which).
## - Your house: three sizes, walls of plaster, timber, stone or planks in any colour, a
##   roof, door and trim in any colour, a chimney and flower boxes. Inside it's your home:
##   the Home Catalogue's 342 pieces, wallpapers and floors (see scripts/token/homes.gd).
## - Your garden: a fence, and anything from the Garden Centre: veg patches that grow crops
##   like Gran's garden, trees, bushes, flowers, benches, lamps, a well, a gnome...
## - Everyone in the shared town sees everyone's plot, garden and crops, and can walk into
##   their house to look round.
## Your mailbox (at the front of your plot) opens the plot planner.

const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const D := preload("res://scripts/land_data.gd")
const Models := preload("res://scripts/models.gd")
## Garden things drawn with a Blender model: id -> [group, model]
const MODEL_OF := {"oak": ["plants", "oak0"], "birch": ["plants", "birch0"], "autumn": ["plants", "autumn0"], "palm": ["plants", "palm0"],
	"bush_pink": ["plants", "bush_pink"], "bush_yellow": ["plants", "bush_yellow"], "bush_white": ["plants", "bush_white"],
	"flowers_a": ["plants", "flowers0"], "flowers_b": ["plants", "flowers2"], "flowers_c": ["plants", "flowers4"]}
const Homes := preload("res://scripts/token/homes.gd")

const ORIGIN := Vector2(306.0, 656.0)
const COLS := 4
const ROWS := 3
const PLOT := Vector2(14.0, 12.0)
const STEP := Vector2(18.0, 16.0)
const LANE := "Driftwood Lane"
const HOUSES := [
	{"n": "Cosy cottage", "size": Vector3(6.0, 3.0, 5.0), "room": Vector2(7.0, 6.0), "price": 0, "mats": {}},
	{"n": "Family house", "size": Vector3(8.0, 3.4, 6.0), "room": Vector2(9.0, 7.0), "price": 3000, "mats": {"mat:wood": 40, "stone": 30}},
	{"n": "Grand villa", "size": Vector3(10.0, 4.2, 7.0), "room": Vector2(11.0, 8.0), "price": 12000, "mats": {"mat:wood": 90, "stone": 80, "iron_bar": 6}},
]
const WALLS := {"plaster": "Plaster", "timber": "Timber frame", "stone": "Stone", "planks": "Planks", "cobble": "Cobbles"}
const ROOFS := {"roof_red": "Red tiles", "roof_blue": "Blue slate", "roof_green": "Green tiles"}
const PAINTS := {"#ffffff": "Natural", "#f4e2b8": "Cream", "#f0b8b0": "Rose", "#b8d8f0": "Sky", "#c8e8b8": "Mint",
	"#f8e070": "Butter", "#d8b8f0": "Lilac", "#e8a060": "Apricot", "#9ab0c8": "Slate", "#7a5a4a": "Chocolate"}
const DOORS := {"#5a3624": "Oak", "#c83a3a": "Red", "#3a6ab8": "Blue", "#3a8a4a": "Green", "#f0c040": "Yellow",
	"#2a2a34": "Black", "#f4f0e8": "White", "#b85aa8": "Plum"}
const FENCES := {"none": "No fence", "picket": "White picket", "rail": "Wooden rail", "stone": "Low stone wall", "hedge": "Hedge"}
# The Garden Centre: things for outside. tex is a sprite (pixels per metre px), veg is a
# working veg patch.
const OUTDOOR := {
	"veg_patch": {"n": "Veg patch", "price": 150, "veg": true},
	"oak": {"n": "Oak tree", "price": 400, "tex": "res://art/plants/oak0.png", "px": 16.0},
	"birch": {"n": "Silver birch", "price": 400, "tex": "res://art/plants/birch0.png", "px": 16.0},
	"autumn": {"n": "Maple", "price": 450, "tex": "res://art/plants/autumn0.png", "px": 16.0},
	"palm": {"n": "Palm tree", "price": 500, "tex": "res://art/plants/palm0.png", "px": 16.0},
	"bush_pink": {"n": "Pink azalea", "price": 90, "tex": "res://art/plants/bush_pink.png", "px": 20.0},
	"bush_yellow": {"n": "Yellow broom", "price": 90, "tex": "res://art/plants/bush_yellow.png", "px": 20.0},
	"bush_white": {"n": "White hydrangea", "price": 90, "tex": "res://art/plants/bush_white.png", "px": 20.0},
	"flowers_a": {"n": "Flower bed (red)", "price": 40, "tex": "res://art/plants/flowers0.png", "px": 20.0},
	"flowers_b": {"n": "Flower bed (blue)", "price": 40, "tex": "res://art/plants/flowers2.png", "px": 20.0},
	"flowers_c": {"n": "Flower bed (gold)", "price": 40, "tex": "res://art/plants/flowers4.png", "px": 20.0},
	"bench": {"n": "Garden bench", "price": 180, "tex": "res://art/land/outdoor/bench.png", "px": 28.0},
	"lamppost": {"n": "Lamp post", "price": 220, "tex": "res://art/land/outdoor/lamppost.png", "px": 28.0, "light": true},
	"well": {"n": "Wishing well", "price": 600, "tex": "res://art/land/outdoor/well.png", "px": 28.0},
	"birdbath": {"n": "Bird bath", "price": 240, "tex": "res://art/land/outdoor/birdbath.png", "px": 28.0},
	"gnome": {"n": "Garden gnome", "price": 120, "tex": "res://art/land/outdoor/gnome.png", "px": 28.0},
	"umbrella": {"n": "Beach umbrella", "price": 200, "tex": "res://art/land/outdoor/umbrella.png", "px": 28.0},
	"stump": {"n": "Tree stump seat", "price": 60, "tex": "res://art/land/outdoor/stump.png", "px": 28.0},
	"scarecrow": {"n": "Scarecrow", "price": 160, "tex": "res://art/decor/scarecrow.png", "px": 28.0},
	"hay_bale": {"n": "Hay bale", "price": 80, "tex": "res://art/decor/hay_bale.png", "px": 28.0},
	"pumpkin_lantern": {"n": "Pumpkin lantern", "price": 140, "tex": "res://art/decor/pumpkin_lantern.png", "px": 28.0},
	"planter": {"n": "Herb planter", "price": 110, "tex": "res://art/decor/planter.png", "px": 28.0},
	"crates": {"n": "Crates", "price": 60, "tex": "res://art/decor/crates.png", "px": 28.0},
	"anchor": {"n": "Old anchor", "price": 300, "tex": "res://art/decor/anchor.png", "px": 28.0},
}

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var interiors: Node3D
var land: Node3D
var dialogue: CanvasLayer
var online: Node
var others := {}  # slot -> {owner, data}: other players' plots, from the shared town
var _nodes := {}  # slot -> Node3D (what's built there now)
var _built_key := {}  # slot -> the data it was built from, so it's only rebuilt on a change
var _doors := {}  # slot -> {pos, room, size, owner, mine}
var _beds := []  # {slot, i, pos, rec} veg patches you can work (your own plot only)
var _signs := {}  # slot -> sale sign position
var _mailbox := Vector3.INF
var _mats := {}
var _placing := ""  # an outdoor item being placed
var _ghost: Sprite3D
var _ghost_ok := false
var _ghost_pos := Vector3.ZERO
var menu: CanvasLayer
var _menu_list: VBoxContainer
var _menu_title: Label
var _menu_msg: Label
var _menu_tab := 0
var _menu_tabs := ["Your house", "Colours", "Garden Centre", "Your garden"]
var _tab_row: HBoxContainer
var _tick := 0.0


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node, i: Node3D, l: Node3D) -> void:
	world = w
	player = p
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	interiors = i
	land = l
	if not save.has("plot") or not (save.plot is Dictionary):
		save["plot"] = {}
	_ensure()
	_build_menu()
	rebuild_all()
	town.providers.append(self)


## Before the world is built: clear the trees off the lane so the plots are open ground.
static func clear_lane(w: Node3D) -> void:
	var r := Rect2(ORIGIN.x - 4.0, ORIGIN.y - 4.0, COLS * STEP.x + 6.0, ROWS * STEP.y + 6.0)
	var veg: Dictionary = w._veg_list
	for c in veg.keys():
		var list: Array = veg[c]
		for i in range(list.size() - 1, -1, -1):
			var p: Array = list[i]
			if r.has_point(Vector2(float(p[0]), float(p[1]))):
				list.remove_at(i)


func _ensure() -> Dictionary:
	var pl: Dictionary = save.plot
	var base := {"slot": -1, "house": {"size": 0, "wall": "plaster", "tint": "#f4e2b8", "roof": "roof_red", "rtint": "#ffffff",
		"door": "#5a3624", "trim": "#ffffff", "chimney": true, "boxes": true}, "fence": "picket", "items": [], "inv": {}}
	for k in base:
		if not pl.has(k):
			pl[k] = base[k]
	var hs: Dictionary = pl.house
	for k in base.house:
		if not hs.has(k):
			hs[k] = base.house[k]
	return pl


func my_slot() -> int:
	return int(_ensure().slot)


static func slot_rect(i: int) -> Rect2:
	var c := i % COLS
	var r := i / COLS
	return Rect2(ORIGIN.x + c * STEP.x, ORIGIN.y + r * STEP.y, PLOT.x, PLOT.y)


## What gets shared with the shared town: the plot and the inside of your home.
func share_data() -> Dictionary:
	var pl := _ensure()
	var home := Homes.ensure(save)
	var items: Array = []
	for it in pl.items:
		if it is Dictionary:
			items.append(it)
	return {"slot": int(pl.slot), "house": pl.house, "fence": str(pl.fence), "items": items,
		"home": {"wall": str(home.wall), "floor": str(home.floor), "furniture": home.furniture}}


# --- building the lane ------------------------------------------------------------------

func rebuild_all() -> void:
	for i in COLS * ROWS:
		_rebuild(i)


## Build (or rebuild) one plot from whoever owns it.
func _rebuild(i: int) -> void:
	var data := {}
	var owner := ""
	var mine := false
	if i == my_slot():
		data = share_data()
		owner = "Your"
		mine = true
	elif others.has(i):
		var o: Dictionary = others[i]
		data = o.get("data", {})
		owner = "%s's" % str(o.get("owner", "Someone"))
	var key := JSON.stringify([owner, _key_of(data)])
	if _built_key.get(i, "") == key and _nodes.has(i):
		return
	_built_key[i] = key
	if _nodes.has(i):
		var old: Node3D = _nodes[i]
		for l in old.find_children("*", "OmniLight3D", true, false):
			world.lamps.erase(l)
		old.queue_free()
	_doors.erase(i)
	_signs.erase(i)
	if mine:
		_beds.clear()
		_mailbox = Vector3.INF
	var root := Node3D.new()
	root.name = "Plot%d" % i
	add_child(root)
	_nodes[i] = root
	var r := slot_rect(i)
	if data.is_empty():
		var at := _ground(r.position.x + r.size.x * 0.5, r.end.y - 1.0)
		if not _model(root, "outdoor", "sale_sign", at):
			_sprite(root, load("res://art/land/outdoor/sale_sign.png"), 28.0, at)
		_signs[i] = at
		return
	var hs: Dictionary = data.get("house", {})
	_house(root, i, hs, owner, mine, data.get("home", {}))
	_fence(root, r, str(data.get("fence", "none")))
	var mb := _ground(r.end.x - 1.2, r.end.y - 0.8)
	if not _model(root, "outdoor", "mailbox", mb, PI * 0.5):
		_sprite(root, load("res://art/land/outdoor/mailbox.png"), 28.0, mb)
	if mine:
		_mailbox = mb
	var items: Array = data.get("items", [])
	for k in items.size():
		var it: Dictionary = items[k]
		var info: Dictionary = OUTDOOR.get(str(it.get("id", "")), {})
		if info.is_empty():
			continue
		var at := _ground(r.position.x + float(it.get("x", 0.0)), r.position.y + float(it.get("z", 0.0)))
		if bool(info.get("veg", false)):
			_veg_patch(root, it, at, mine, i, k)
		else:
			var id := str(it.get("id", ""))
			var src: Array = MODEL_OF.get(id, ["outdoor", id])
			var turn := 0.0  # models' fronts face Blender's -Y, which is the camera's way
			if str(src[0]) == "plants":
				turn = fposmod(float(it.get("x", 0.0)) * 2.3 + float(it.get("z", 0.0)) * 1.7, TAU)
			elif id in ["gnome", "pumpkin_lantern"]:
				turn = -PI * 0.5  # these face +X
			if not _model(root, str(src[0]), str(src[1]), at, turn):
				var tex: Texture2D = load(str(info.tex))
				_sprite(root, tex, float(info.px), at)
			if bool(info.get("light", false)):
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.85, 0.55)
				l.omni_range = 7.0
				l.light_energy = 1.2
				root.add_child(l)
				l.global_position = at + Vector3(0.0, 2.1, 0.0)
				world.lamps.append(l)


## What a plot looks like (crops by their growth stage, not the minute), to tell when it needs
## rebuilding.
func _key_of(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var now: float = sea.now()
	for it in out.get("items", []):
		if it is Dictionary and str(it.get("id", "")) == "veg_patch":
			it["grow"] = int(land.stage(it)) if str(it.get("s", "")) == "crop" else 0
			it["wet"] = float(it.get("wet", 0.0)) > now
	out.erase("home")
	return out


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, float(world.height_at(x, z)), z)


## A Blender model on the ground (facing the lane, so its front faces the camera); false if
## there's no model for it.
func _model(parent: Node3D, group: String, name: String, at: Vector3, turn := 0.0) -> bool:
	var n := Models.make(group, name)
	if n == null:
		return false
	parent.add_child(n)
	n.global_position = at
	n.rotation.y = turn
	return true


func _sprite(parent: Node3D, tex: Texture2D, px_per_m: float, at: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 1.0 / px_per_m
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(s)
	if tex:
		s.global_position = at + Vector3(0.0, tex.get_height() / px_per_m * 0.5 - 0.05, 0.0)
	return s


func _mat(tex: String, tint: String) -> StandardMaterial3D:
	var key := "%s|%s" % [tex, tint]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if tex != "":
		m.albedo_texture = load("res://art/tex/%s.png" % tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.albedo_color = Color(tint)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.92
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = at
	parent.add_child(mi)
	return mi


func _house(root: Node3D, i: int, hs: Dictionary, owner: String, mine: bool, home: Dictionary) -> void:
	var r := slot_rect(i)
	var tier := clampi(int(hs.get("size", 0)), 0, HOUSES.size() - 1)
	var info: Dictionary = HOUSES[tier]
	var size: Vector3 = info.size
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + 1.0 + size.z * 0.5
	var y := minf(float(world.height_at(cx - size.x * 0.4, cz)), float(world.height_at(cx + size.x * 0.4, cz)))
	y = minf(y, float(world.height_at(cx, cz + size.z * 0.4)))
	var pivot := StaticBody3D.new()
	root.add_child(pivot)
	pivot.global_position = Vector3(cx, y, cz)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y + 2.0, size.z)
	col.shape = shape
	col.position.y = (size.y + 2.0) * 0.5
	pivot.add_child(col)
	var wall_tex := str(hs.get("wall", "plaster"))
	if not WALLS.has(wall_tex):
		wall_tex = "plaster"
	var trim := _mat("", str(hs.get("trim", "#ffffff")))
	# a stone footing for slopes, the walls, corner posts and a roof
	_box(pivot, Vector3(size.x + 0.3, 1.2, size.z + 0.3), Vector3(0.0, -0.45, 0.0), _mat("stone", "#ffffff"))
	_box(pivot, size, Vector3(0.0, size.y * 0.5, 0.0), _mat(wall_tex, str(hs.get("tint", "#ffffff"))))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(pivot, Vector3(0.22, size.y, 0.22), Vector3(sx * size.x * 0.5, size.y * 0.5, sz * size.z * 0.5), trim)
	var roof_tex := str(hs.get("roof", "roof_red"))
	if not ROOFS.has(roof_tex):
		roof_tex = "roof_red"
	var roof_h := 2.0 + tier * 0.4
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z + 0.9, roof_h, size.x + 0.9)
	prism.material = _mat(roof_tex, str(hs.get("rtint", "#ffffff")))
	var roof := MeshInstance3D.new()
	roof.mesh = prism
	roof.position = Vector3(0.0, size.y + roof_h * 0.5, 0.0)
	roof.rotation.y = PI * 0.5
	pivot.add_child(roof)
	if bool(hs.get("chimney", true)):
		_box(pivot, Vector3(0.6, 1.6, 0.6), Vector3(size.x * 0.28, size.y + 1.5, -0.5), _mat("stone", "#ffffff"))
	var front := size.z * 0.5 + 0.03
	# the door, its frame and a step
	var door_m := _mat("", str(hs.get("door", "#5a3624")))
	_box(pivot, Vector3(1.3, 2.2, 0.06), Vector3(0.0, 1.1, front), trim)
	_box(pivot, Vector3(1.0, 1.95, 0.1), Vector3(0.0, 0.98, front + 0.02), door_m)
	_box(pivot, Vector3(0.12, 0.12, 0.08), Vector3(0.32, 1.0, front + 0.08), _mat("", "#f0d040"))
	_box(pivot, Vector3(1.8, 0.2, 0.8), Vector3(0.0, 0.1, front + 0.4), _mat("stone", "#ffffff"))
	# windows, with flower boxes if you like
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.72, 0.9)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.85, 0.5)
	glass.emission_energy_multiplier = 0.35
	var n := 1 + tier
	for k in n * 2:
		var side := -1.0 if k < n else 1.0
		var j := k % n
		var wx := side * (1.4 + j * 1.6)
		if absf(wx) > size.x * 0.5 - 0.6:
			continue
		_box(pivot, Vector3(1.0, 1.0, 0.08), Vector3(wx, size.y * 0.55, front), trim)
		_box(pivot, Vector3(0.8, 0.8, 0.1), Vector3(wx, size.y * 0.55, front + 0.02), glass)
		if bool(hs.get("boxes", true)):
			_box(pivot, Vector3(1.0, 0.22, 0.3), Vector3(wx, size.y * 0.55 - 0.6, front + 0.15), _mat("planks", "#ffffff"))
			var fl3 := Models.make("plants", "flowers%d" % ((i + k) % 5))
			if fl3:
				pivot.add_child(fl3)
				fl3.scale = Vector3(1.0, 0.7, 0.35)
				fl3.position = Vector3(wx, size.y * 0.55 - 0.49, front + 0.15)
			else:
				var fl := Sprite3D.new()
				fl.texture = load("res://art/plants/flowers%d.png" % ((i + k) % 5))
				fl.pixel_size = 1.0 / 40.0
				fl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				fl.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				fl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				pivot.add_child(fl)
				fl.position = Vector3(wx, size.y * 0.55 - 0.35, front + 0.18)
	# a name board over the door
	var l := Label3D.new()
	l.text = "%s home" % owner if owner == "Your" else "%s home" % owner
	l.font = load("res://art/fonts/pixelify_sans.woff2")
	l.font_size = 36
	l.pixel_size = 0.008
	l.modulate = Color(0.28, 0.18, 0.12)
	l.outline_size = 0
	pivot.add_child(l)
	l.position = Vector3(0.0, 2.55, front + 0.08)
	_box(pivot, Vector3(maxf(2.0, l.text.length() * 0.2 + 0.4), 0.42, 0.06), Vector3(0.0, 2.55, front + 0.03), _mat("", "#f4ecd8"))
	var door := pivot.global_transform * Vector3(0.0, 0.0, size.z * 0.5 + 0.9)
	_doors[i] = {"pos": door, "room": info.room, "size": size, "owner": owner, "mine": mine, "home": home}


func _fence(root: Node3D, r: Rect2, style: String) -> void:
	if style == "none" or not FENCES.has(style):
		return
	var m: Material
	var h := 0.9
	var thick := 0.12
	match style:
		"picket":
			m = _mat("", "#f4f0e8")
		"rail":
			m = _mat("timber", "#ffffff")
		"stone":
			m = _mat("stone", "#ffffff")
			h = 0.7
			thick = 0.4
		"hedge":
			m = _mat("", "#4a8a3a")
			h = 1.1
			thick = 0.6
	var gate := 2.4
	var runs := [
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)],
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)],
		[Vector2(r.position.x, r.end.y), Vector2(r.position.x + r.size.x * 0.5 - gate * 0.5, r.end.y)],
		[Vector2(r.position.x + r.size.x * 0.5 + gate * 0.5, r.end.y), Vector2(r.end.x, r.end.y)],
	]
	for run: Array in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var steps := maxi(1, int(a.distance_to(b) / 2.0))
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := (p0 + p1) * 0.5
			var gy := float(world.height_at(mid.x, mid.y))
			var horiz := absf(p1.x - p0.x) > absf(p1.y - p0.y)
			var len_ := p0.distance_to(p1)
			if style == "picket" or style == "rail":
				var rail := _box(root, Vector3(len_ if horiz else thick, 0.1, thick if horiz else len_), Vector3(mid.x, gy + h * 0.75, mid.y), m)
				rail.position = Vector3(mid.x, gy + h * 0.75, mid.y)
				_box(root, Vector3(len_ if horiz else thick, 0.1, thick if horiz else len_), Vector3(mid.x, gy + h * 0.35, mid.y), m)
				_box(root, Vector3(0.14, h, 0.14), Vector3(p0.x, float(world.height_at(p0.x, p0.y)) + h * 0.5, p0.y), m)
			else:
				_box(root, Vector3(len_ + 0.05 if horiz else thick, h, thick if horiz else len_ + 0.05), Vector3(mid.x, gy + h * 0.5, mid.y), m)


func _veg_patch(root: Node3D, it: Dictionary, at: Vector3, mine: bool, slot: int, k: int) -> void:
	var soil := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.8, 1.8)
	var m := StandardMaterial3D.new()
	var wet := float(it.get("wet", 0.0)) > float(sea.now())
	m.albedo_texture = load("res://art/tex/soil_wet.png" if wet else "res://art/tex/soil.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if str(it.get("s", "wild")) == "wild":
		m.albedo_color = Color(0.78, 0.85, 0.6)
	q.material = m
	soil.mesh = q
	root.add_child(soil)
	soil.global_position = at + Vector3(0.0, 0.04, 0.0)
	if str(it.get("s", "")) == "crop":
		var tex: Texture2D = load("res://art/land/crops/%s_%d.png" % [str(it.crop), int(land.stage(it))])
		var c := Sprite3D.new()
		c.texture = tex
		c.pixel_size = 1.0 / 18.0
		c.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		c.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		c.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		root.add_child(c)
		c.global_position = at + Vector3(0.0, tex.get_height() / 18.0 * 0.5 - 0.05, 0.0)
	if mine:
		_beds.append({"slot": slot, "i": k, "pos": at})


# --- every second: crops grow, the lane is rebuilt where it changed -----------------------

func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 2.0
		_grow()
		rebuild_all()
	if _placing != "":
		_update_ghost()


func _grow() -> void:
	var pl := _ensure()
	var now: float = sea.now()
	var last := float(pl.get("tick_t", now))
	var dt := clampf(now - last, 0.0, 2880.0)
	pl["tick_t"] = now
	var raining := str(sea.env.get("sky", "")) in ["rain", "storm"]
	for it in pl.items:
		if not (it is Dictionary) or str(it.get("id", "")) != "veg_patch" or str(it.get("s", "")) != "crop":
			continue
		if raining and float(it.get("wet", 0.0)) < now + 30.0:
			it["wet"] = now + 60.0
		var watered := minf(now, float(it.get("wet", 0.0))) - last
		if watered > 0.0:
			it["grow"] = float(it.get("grow", 0.0)) + minf(watered, dt)


# --- interactions ----------------------------------------------------------------------------

func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if world.indoor or _placing != "":
		return {}
	if not Rect2(ORIGIN.x - 8.0, ORIGIN.y - 8.0, COLS * STEP.x + 16.0, ROWS * STEP.y + 16.0).has_point(Vector2(pos.x, pos.z)):
		return {}
	var best := {}
	var best_d := 99.0
	var p2 := Vector2(pos.x, pos.z)
	for i in _signs:
		var at: Vector3 = _signs[i]
		var d := p2.distance_to(Vector2(at.x, at.z))
		if d < 1.8 and d < best_d:
			best_d = d
			var text := "Space: Make this plot on %s yours" % LANE if my_slot() < 0 else "A free plot (you have one already)"
			best = {"kind": "claim", "slot": int(i), "dist": d, "text": text}
	for i in _doors:
		var dr: Dictionary = _doors[i]
		var at: Vector3 = dr.pos
		var d := p2.distance_to(Vector2(at.x, at.z))
		if d < 1.7 and d < best_d and _facing(pos, at - Vector3(0.0, 0.0, 1.0), facing):
			best_d = d
			best = {"kind": "door", "slot": int(i), "dist": d,
				"text": "Space: Go into your house" if bool(dr.mine) else "Space: Visit %s home" % str(dr.owner)}
	if _mailbox != Vector3.INF:
		var d := p2.distance_to(Vector2(_mailbox.x, _mailbox.z))
		if d < 1.6 and d < best_d:
			best_d = d
			best = {"kind": "mailbox", "dist": d, "text": "Space: Open the plot planner (your mailbox)"}
	var items: Array = _ensure().items
	for b in _beds:
		var at: Vector3 = b.pos
		var d := p2.distance_to(Vector2(at.x, at.z))
		if d < 1.3 and d < best_d:
			best_d = d
			var rec: Dictionary = items[int(b.i)]
			best = {"kind": "patch", "i": int(b.i), "dist": d, "text": land._bed_text(rec)}
	return best


func _facing(pos: Vector3, target: Vector3, facing: Vector3) -> bool:
	var to := Vector2(target.x - pos.x, target.z - pos.z)
	if to.length() < 0.8:
		return true
	return Vector2(facing.x, facing.z).normalized().dot(to.normalized()) > 0.2


func use(it: Dictionary) -> void:
	match str(it.get("kind", "")):
		"claim":
			_claim(int(it.slot))
		"door":
			_enter(int(it.slot))
		"mailbox":
			open_menu()
		"patch":
			_use_patch(int(it.i))


func _claim(slot: int) -> void:
	if my_slot() >= 0:
		hud.toast("You've already got a plot on %s." % LANE)
		return
	if others.has(slot):
		hud.toast("Someone's just taken that one.")
		return
	_ensure()["slot"] = slot
	if online and online.is_online():
		online.send_plot()
	SaveGame.write(save)
	audio.play("fanfare2")
	hud.show_banner(LANE, "Plot %d is yours!" % (slot + 1))
	dialogue.say(LANE, ["It's yours! A cosy cottage, a white picket fence and a mailbox with your name on it.",
		"Your mailbox opens the plot planner: change your house's walls, roof and door, make it bigger, and buy things for the garden.",
		"Veg patches from the Garden Centre grow crops just like Gran's garden. Inside, the Home Catalogue has everything for your rooms.",
		"Friends in the shared town will see it all, and can come in and look round."])
	_built_key.erase(slot)
	_rebuild(slot)


func _enter(slot: int) -> void:
	var dr: Dictionary = _doors[slot]
	var b := {"name": "%s home" % str(dr.owner), "kind": "plot_home", "role": "", "town": "", "door": dr.pos,
		"away": Vector3.BACK, "size": dr.size, "room": dr.room}
	if not bool(dr.mine):
		var h: Dictionary = (dr.home as Dictionary).duplicate()
		h["owner"] = str(dr.owner).trim_suffix("'s")
		b["visit"] = h
	interiors.enter(b)


func _use_patch(i: int) -> void:
	var items: Array = _ensure().items
	var rec: Dictionary = items[i]
	var now: float = sea.now()
	match str(rec.get("s", "wild")):
		"wild":
			if land.tool_tier("hoe") <= 0:
				hud.toast("You'll need a hoe to dig it over. Farmer Bramble, by Gran's hut, sells them.")
				return
			rec["s"] = "tilled"
			land.add_xp("farming", 3)
			audio.play("step_sand", -4.0, 0.8)
			hud.toast("Dug over and ready for seeds.")
		"tilled":
			var options: Array = []
			for crop in D.CROP_ORDER:
				if int(land.count("seed_%s" % crop)) > 0:
					options.append("seed_%s" % crop)
			if options.is_empty():
				hud.toast("You've no seeds. Farmer Bramble sells them.")
				return
			var labels: Array = []
			for sid in options:
				labels.append("%s (%d)" % [D.item_name(str(sid)), int(land.count(str(sid)))])
			labels.append("Not now")
			dialogue.say("Your veg patch", ["What will you plant?"], null, labels, _planted.bind(i, options))
			return
		"crop":
			var crop := str(rec.crop)
			if int(land.stage(rec)) >= 3:
				var info: Dictionary = D.CROPS[crop]
				var y: Array = info["yield"]
				var n := randi_range(int(y[0]), int(y[1])) + int(land.skill_level("farming")) / 3
				hud.toast("Harvested: %s." % land.add_item(crop, n))
				land.add_xp("farming", int(info.xp))
				land.land_event.emit("harvest", crop, n)
				audio.play("good", -6.0)
				items[i] = {"id": "veg_patch", "x": rec.x, "z": rec.z, "s": "tilled"}
			elif float(rec.get("wet", 0.0)) <= now:
				if land.tool_tier("can") <= 0:
					hud.toast("It needs water: you need a watering can (Farmer Bramble).")
					return
				rec["wet"] = now + float(D.WATER_MINUTES)
				land.land_event.emit("water", crop, 1)
				audio.play("splash", -4.0, 1.4)
				hud.toast("Watered.")
			else:
				var info2: Dictionary = D.CROPS[crop]
				hud.toast("Coming along: about %d minutes of watered growing to go." % int(maxf(0.0, float(info2.grow) - float(rec.get("grow", 0.0)))))
				return
	_changed()


func _planted(choice: int, i: int, options: Array) -> void:
	if choice < 0 or choice >= options.size():
		return
	var sid := str(options[choice])
	if not land.take(sid, 1):
		return
	var items: Array = _ensure().items
	var rec: Dictionary = items[i]
	var crop := str(D.ITEMS[sid].crop)
	items[i] = {"id": "veg_patch", "x": rec.x, "z": rec.z, "s": "crop", "crop": crop, "grow": 0.0, "wet": 0.0}
	land.add_xp("farming", 2)
	land.land_event.emit("plant", crop, 1)
	audio.play("step_sand", -4.0, 1.2)
	hud.toast("Planted %s. Give them some water." % D.item_name(crop).to_lower())
	_changed()


## Something about your plot changed: save it, rebuild it, tell the shared town.
func _changed() -> void:
	SaveGame.write(save)
	if my_slot() >= 0:
		_rebuild(my_slot())
	if online and online.is_online():
		online.send_plot()


# --- the shared town ---------------------------------------------------------------------------

## The shared town's list of plots: slot -> {owner, data}. Yours is kept from your save.
func set_others(list: Dictionary, my_name: String) -> void:
	others.clear()
	for k in list:
		var slot := int(k)
		var rec: Dictionary = list[k]
		if str(rec.get("owner", "")) == my_name:
			if my_slot() != slot:
				_ensure()["slot"] = slot  # the town remembers your plot
			continue
		if slot == my_slot():
			# someone else has your old slot in this town: you'll be given another
			_ensure()["slot"] = -1
		others[slot] = rec
	rebuild_all()


# --- placing things in your garden -----------------------------------------------------------

func start_placing(id: String) -> void:
	if my_slot() < 0:
		return
	_placing = id
	var info: Dictionary = OUTDOOR[id]
	if _ghost:
		_ghost.queue_free()
	_ghost = Sprite3D.new()
	if bool(info.get("veg", false)):
		_ghost.texture = load("res://art/tex/soil.png")
		_ghost.pixel_size = 1.8 / 32.0
		_ghost.axis = Vector3.AXIS_Y
	else:
		_ghost.texture = load(str(info.tex))
		_ghost.pixel_size = 1.0 / float(info.px)
		_ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_ghost.shaded = false
	add_child(_ghost)
	hud.modal = true
	player.can_move = true
	hud.toast("Walk to where it goes: %s puts it down, %s stops." % [Glyphs.key("action"), Glyphs.key("cancel")])


func _update_ghost() -> void:
	player.can_move = true
	var r := slot_rect(my_slot())
	var p: Vector3 = player.global_position + player.facing * 1.6
	p.x = snappedf(p.x, 0.5)
	p.z = snappedf(p.z, 0.5)
	var local := Vector2(p.x - r.position.x, p.z - r.position.y)
	var info: Dictionary = OUTDOOR[_placing]
	var tier := clampi(int(_ensure().house.size), 0, 2)
	var hsize: Vector3 = HOUSES[tier].size
	var house := Rect2(r.size.x * 0.5 - hsize.x * 0.5 - 0.5, 0.5, hsize.x + 1.0, hsize.z + 2.4)
	_ghost_ok = Rect2(0.6, 0.6, r.size.x - 1.2, r.size.y - 1.2).has_point(local) and not house.has_point(local)
	_ghost_pos = _ground(p.x, p.z)
	var tex_h := 0.0 if bool(info.get("veg", false)) else _ghost.texture.get_height() * _ghost.pixel_size * 0.5
	_ghost.global_position = _ghost_pos + Vector3(0.0, tex_h + 0.06, 0.0)
	_ghost.modulate = Color(0.7, 1.0, 0.7, 0.7) if _ghost_ok else Color(1.0, 0.5, 0.5, 0.6)
	if Input.is_action_just_pressed("cancel"):
		_stop_placing()
	elif Input.is_action_just_pressed("action"):
		if not _ghost_ok:
			audio.play("error", -6.0)
			hud.toast("Inside your fence, and not in front of the house.")
			return
		var pl := _ensure()
		var inv: Dictionary = pl.inv
		if int(inv.get(_placing, 0)) <= 0:
			_stop_placing()
			return
		inv[_placing] = int(inv[_placing]) - 1
		var it := {"id": _placing, "x": snappedf(local.x, 0.5), "z": snappedf(local.y, 0.5)}
		if bool(info.get("veg", false)):
			it["s"] = "wild"
		(pl.items as Array).append(it)
		audio.play("thud", -6.0)
		_changed()
		if int(inv[_placing]) <= 0:
			_stop_placing()


func _stop_placing() -> void:
	_placing = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	hud.modal = false
	hud.block_input(0.25)


# --- the plot planner (your mailbox) -------------------------------------------------------

func _build_menu() -> void:
	menu = CanvasLayer.new()
	menu.layer = 20
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.visible = false
	add_child(menu)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := UI.panel(18.0)
	panel.custom_minimum_size = Vector2(820.0, 600.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_menu_title = UI.label("Your plot on %s" % LANE, 32, UI.GOLD, true)
	col.add_child(_menu_title)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	col.add_child(_tab_row)
	for k in _menu_tabs.size():
		var t := UI.button(str(_menu_tabs[k]), 20)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(k))
		_tab_row.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 380.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_menu_list = VBoxContainer.new()
	_menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_menu_list)
	_menu_msg = UI.label("", 20, UI.GOOD)
	_menu_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_menu_msg)
	col.add_child(UI.label(Glyphs.plain("{updown} choose   {action} pick   {leftright} change tab   {cancel} close"), 18, UI.DIM))


func open_menu(tab := 0) -> void:
	menu.visible = true
	get_tree().paused = true
	_menu_msg.text = ""
	_show_tab(tab)


func close_menu() -> void:
	menu.visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)


func is_menu_open() -> bool:
	return menu.visible


func _input(event: InputEvent) -> void:
	if not menu or not menu.visible:
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_show_tab((_menu_tab + _menu_tabs.size() - 1) % _menu_tabs.size())
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_show_tab((_menu_tab + 1) % _menu_tabs.size())


func _row(text: String, cb: Callable, dim := false, off := false) -> Button:
	var b := UI.button(text, 20)
	if off:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	else:
		b.pressed.connect(cb)
	if dim:
		b.add_theme_color_override("font_color", UI.DIM)
	_menu_list.add_child(b)
	return b


func _show_tab(k: int, focus := 0) -> void:
	_menu_tab = k
	for c in _menu_list.get_children():
		c.queue_free()
	for t in _tab_row.get_child_count():
		(_tab_row.get_child(t) as Button).add_theme_color_override("font_color", UI.GOLD if t == k else UI.CREAM)
	var pl := _ensure()
	var hs: Dictionary = pl.house
	_menu_title.text = "Your plot on %s   %d Shells" % [LANE, int(save.shells)]
	var rows: Array[Button] = []
	match k:
		0:
			var tier := int(hs.size)
			for t in HOUSES.size():
				var h: Dictionary = HOUSES[t]
				var cost := _cost_text(int(h.price), h.mats)
				var status := "Your house now" if t == tier else ("Done" if t < tier else cost)
				rows.append(_row("%s   %s" % [h.n, status], _upgrade.bind(t), t == tier + 1 and _short(int(h.price), h.mats) != "", t != tier + 1))
			for wk in WALLS:
				rows.append(_row("Walls: %s%s   Free" % [WALLS[wk], "  (now)" if str(hs.wall) == wk else ""], _set_house.bind("wall", wk), false, str(hs.wall) == wk))
			for rk in ROOFS:
				rows.append(_row("Roof: %s%s   Free" % [ROOFS[rk], "  (now)" if str(hs.roof) == rk else ""], _set_house.bind("roof", rk), false, str(hs.roof) == rk))
			rows.append(_row("Chimney: %s" % ("on" if bool(hs.chimney) else "off"), _set_house.bind("chimney", not bool(hs.chimney))))
			rows.append(_row("Flower boxes under the windows: %s" % ("on" if bool(hs.boxes) else "off"), _set_house.bind("boxes", not bool(hs.boxes))))
			for fk in FENCES:
				rows.append(_row("Fence: %s%s" % [FENCES[fk], "  (now)" if str(pl.fence) == fk else ""], _set_fence.bind(fk), false, str(pl.fence) == fk))
		1:
			for part in [["tint", "Wall colour"], ["rtint", "Roof colour"], ["door", "Door colour"], ["trim", "Window and corner trim"]]:
				var table: Dictionary = DOORS if str(part[0]) == "door" else PAINTS
				for c in table:
					var now := str(hs.get(part[0], "")) == str(c)
					var b := _row("%s: %s%s   Free" % [part[1], table[c], "  (now)" if now else ""], _set_house.bind(str(part[0]), str(c)), false, now)
					b.add_theme_color_override("font_color", Color(str(c)).lerp(UI.CREAM, 0.25) if not now else UI.GOLD)
					rows.append(b)
		2:
			var inv: Dictionary = pl.inv
			for id in OUTDOOR:
				var info: Dictionary = OUTDOOR[id]
				var b := _row("%s   %d Shells   (you have %d to place)" % [info.n, int(info.price), int(inv.get(id, 0))], _buy.bind(str(id)),
					int(save.shells) < int(info.price))
				if info.has("tex"):
					b.icon = load(str(info.tex))
					b.expand_icon = false
					b.add_theme_constant_override("icon_max_width", 36)
				rows.append(b)
		3:
			var inv2: Dictionary = pl.inv
			var any := false
			for id in inv2:
				if int(inv2[id]) > 0 and OUTDOOR.has(id):
					any = true
					rows.append(_row("Place: %s (%d)" % [OUTDOOR[id].n, int(inv2[id])], _place.bind(str(id))))
			if not any:
				rows.append(_row("Nothing to place: buy things in the Garden Centre tab.", Callable(), false, true))
			var items: Array = pl.items
			for i in items.size():
				var it: Dictionary = items[i]
				if not OUTDOOR.has(str(it.get("id", ""))):
					continue
				var label := str(OUTDOOR[str(it.id)].n)
				if str(it.id) == "veg_patch" and str(it.get("s", "")) == "crop":
					label += " (growing %s)" % D.item_name(str(it.crop)).to_lower()
				rows.append(_row("Pick up: %s" % label, _pick_up.bind(i)))
	var focusable: Array[Button] = []
	for b in rows:
		if b.focus_mode != Control.FOCUS_NONE:
			focusable.append(b)
	if not focusable.is_empty():
		UI.focus_soon(focusable[clampi(focus, 0, focusable.size() - 1)])
	audio.play("click", -8.0)


func _cost_text(price: int, mats: Dictionary) -> String:
	var parts: Array[String] = []
	if price > 0:
		parts.append("%d Shells" % price)
	for k in mats:
		parts.append("%d %s" % [int(mats[k]), D.item_name(str(k)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "Free"


func _short(price: int, mats: Dictionary) -> String:
	var need: Array[String] = []
	if int(save.shells) < price:
		need.append("%d Shells" % (price - int(save.shells)))
	for k in mats:
		var gap := int(mats[k]) - int(land.count(str(k)))
		if gap > 0:
			need.append("%d %s" % [gap, D.item_name(str(k)).to_lower()])
	return "" if need.is_empty() else "You need %s more." % " and ".join(need)


func _msg(text: String, good := true) -> void:
	_menu_msg.add_theme_color_override("font_color", UI.GOOD if good else UI.BAD)
	_menu_msg.text = text
	audio.play("buy" if good else "error", -4.0)


func _upgrade(t: int) -> void:
	var h: Dictionary = HOUSES[t]
	var short := _short(int(h.price), h.mats)
	if short != "":
		_msg(short, false)
		return
	save.shells = int(save.shells) - int(h.price)
	for k in h.mats:
		land.take(str(k), int(h.mats[k]))
	_ensure().house["size"] = t
	hud.set_shells(save.shells)
	_changed()
	_msg("Your house is now a %s! More room inside, too." % str(h.n).to_lower())
	_show_tab(0)


func _set_house(key: String, value: Variant) -> void:
	_ensure().house[key] = value
	_changed()
	_msg("Done.")
	_show_tab(_menu_tab)


func _set_fence(style: String) -> void:
	_ensure()["fence"] = style
	_changed()
	_msg("New fence up.")
	_show_tab(_menu_tab)


func _buy(id: String) -> void:
	var info: Dictionary = OUTDOOR[id]
	if int(save.shells) < int(info.price):
		_msg("You need %d more Shells." % (int(info.price) - int(save.shells)), false)
		return
	save.shells = int(save.shells) - int(info.price)
	var inv: Dictionary = _ensure().inv
	inv[id] = int(inv.get(id, 0)) + 1
	hud.set_shells(save.shells)
	SaveGame.write(save)
	_msg("Bought: %s. Place it from the Your garden tab." % str(info.n).to_lower())
	_show_tab(2, OUTDOOR.keys().find(id))


func _place(id: String) -> void:
	close_menu()
	start_placing.call_deferred(id)


func _pick_up(i: int) -> void:
	var pl := _ensure()
	var items: Array = pl.items
	if i >= items.size():
		return
	var it: Dictionary = items[i]
	items.remove_at(i)
	var inv: Dictionary = pl.inv
	inv[str(it.id)] = int(inv.get(str(it.id), 0)) + 1
	_changed()
	_msg("Picked up. It's back in your garden things.")
	_show_tab(3)
