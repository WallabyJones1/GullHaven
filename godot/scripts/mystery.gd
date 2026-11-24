extends Node3D
## The mystery of the Gull's Eye. Fifty years ago, in the Storm Year, keeper Elias Marrow
## took the great lens out of Gullhaven's lighthouse to keep it from smugglers, hid it, and
## split the way to it into marks (a gull with one wing) that only a fisher would follow.
## Then he vanished. Each mark hides a page of his notes behind a puzzle:
##   1. a loose stone in the lighthouse          5. Kelpwood's lanterns, lit in order
##   2. the estuary stone, dug out at low tide   6. Silverjaw, the old pike of Mirrorlake
##   3. the mill's four bells, rung in order     7. the keeper's chest on Lantern Key
##   4. the standing stones of Gull Rock         8. the cave on Ember Isle
## Set the Eye back in the lamp and the Warden wakes in the Deep.
## Also floating about the sea: twelve message bottles, each holding one of the letters.

const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")

const RANGE := 1.9
# where things are (x, z on the map)
const ESTUARY_STONE := Vector2(460.0, 368.5)
const BELLS := [Vector2(297.4, 231.6), Vector2(297.4, 232.8), Vector2(297.4, 234.0), Vector2(297.4, 235.2)]
const GULL_STONES := [Vector2(565.6, 477.4), Vector2(571.0, 479.0), Vector2(579.1, 475.0)]
const STONE_TARGETS := [Vector2(510.0, 543.5), Vector2(1066.0, 872.0), Vector2(150.0, 112.0)]  # the light, the fire, the mirror
const LANTERNS := [Vector2(769.6, 637.6), Vector2(759.6, 647.6), Vector2(750.2, 638.4), Vector2(759.6, 627.6)]  # E S W N
const LANTERN_ORDER := [0, 1, 2, 3]  # sunrise, noon, sunset, night
const BELL_ORDER := [0, 3, 1, 2]  # biggest, smallest, second, third
const CHEST := Vector2(970.7, 554.7)
const CHEST_CODE := [3, 4, 4]  # Gullhaven's docks, the mill's sails, Kelpwood's lanterns
const CAVE := Vector2(1067.0, 872.4)
const LAKE_MARK := Vector2(186.0, 104.0)
const BOTTLES := {
	"letter_1": Vector2(480.0, 585.0), "letter_2": Vector2(520.0, 700.0), "letter_3": Vector2(470.0, 360.0),
	"letter_4": Vector2(1040.0, 240.0), "letter_5": Vector2(1084.0, 172.0), "letter_6": Vector2(470.0, 565.0),
	"letter_7": Vector2(600.0, 790.0), "letter_8": Vector2(1200.0, 520.0), "letter_9": Vector2(727.0, 640.0),
	"letter_10": Vector2(770.0, 360.0), "letter_11": Vector2(1033.0, 767.0), "letter_12": Vector2(556.5, 482.0),
}
const PAGES := [
	{"title": "A rumour", "text": "Old Marlo says the lighthouse once held a great crystal lens, the Gull's Eye. It vanished with keeper Elias Marrow the night the lamp went out, fifty years ago.",
		"riddle": "Marrow lived in the lighthouse on the breakwater. Have a look around inside."},
	{"title": "The keeper's first page", "text": "\"If you're reading this, the Eye is safe and I am not. The smugglers want the lens, and they'd tear the light apart for it. So I've taken it down and hidden it, and split the way to it into marks only a fisher would follow. Look for my gull with one wing.\"  Elias Marrow, Keeper, the Storm Year",
		"riddle": "\"My first mark stands where the river meets the sea, by the bridge. The water hides what I buried at its foot. Come when the tide is low.\""},
	{"title": "Under the estuary stone", "text": "\"Low water. Good: you read the tides like a fisher. The miller at Willowford was my friend. He hung four bells by his door to call the boats home, and they still know my lullaby.\"",
		"riddle": "\"Ring the mill's four bells for my lullaby: the biggest, then the smallest, then the second, then the third.\""},
	{"title": "Behind the mill bells", "text": "\"Old Ottie kept this safe for me. Next, row out to Gull Rock. Three stones stand there, blind. Give them back their sight.\"",
		"riddle": "\"Turn the three stones of Gull Rock to look on what they guard. The first watches the light, the second the fire, the third the mirror.\""},
	{"title": "Under the Gull Rock stones", "text": "\"The fog round Kelpwood keeps honest boats away, which is why the smugglers loved it. I hid a page among the lanterns there. Bring a lamp of your own.\"",
		"riddle": "\"Light Kelpwood's four lanterns as the sun goes round: where it rises, where it stands at noon, where it sets, and where it sleeps.\""},
	{"title": "In the Kelpwood lanterns", "text": "\"The key to my chest I fed to Silverjaw, the old pike of Mirrorlake, who never takes a hook twice. She only rises at dawn, when the lake lies still as glass.\"",
		"riddle": "Catch Silverjaw on Mirrorlake at dawn in calm weather. (The ranger's permit opens the way into the hills.)"},
	{"title": "Silverjaw's key", "text": "A brass key, green with age, engraved LANTERN KEY. Oilcloth is wrapped round it: \"My chest is on Lantern Key. Its dials want three numbers.\"",
		"riddle": "\"Count the docks of Gullhaven, the sails of the Willowford mill, and the lanterns of Kelpwood.\" Then open the keeper's chest on Lantern Key."},
	{"title": "The keeper's chest", "text": "Inside: a chart, a lock of grey hair, and Marrow's last page. \"The Eye was born in the fire mountain, so I took it home. It rests in the cave on Ember Isle, warm and waiting. Bring it back to the light, fisher. Something in the trench has been waiting too.\"",
		"riddle": "Find the cave on Ember Isle, behind the village, where the rock breathes warm air. (The harbourmaster's permit lets you land.)"},
	{"title": "The Gull's Eye", "text": "Wrapped in sailcloth on a ledge of black rock: a lens as big as a cartwheel's hub, still full of light.",
		"riddle": "Take the Gull's Eye home and set it in the lighthouse lamp."},
	{"title": "The light returns", "text": "The Eye catches the flame and the whole bay turns gold. Far out past the shelf, something vast rolls over in the dark. The Warden is awake.",
		"riddle": "The Warden swims in the Deep at night. Bring your best rod and a boat built for the open ocean."},
]
const LETTERS := {
	"letter_1": "To whoever finds this: I'm throwing a letter a year into the sea until somebody writes back. The tide always brings them home in the end. M.",
	"letter_2": "The night the lamp went out, the whole harbour came down to the quay with lanterns. Keeper Marrow's boat was gone, and so was the great lens. Some say he stole it. I never believed that.",
	"letter_3": "Five boats, one harbour, and not enough fish for all of us. That was the start of the trouble. My father sold his nets to the smugglers' co-op. I wish he hadn't.",
	"letter_4": "When the tide's right you can hear it: a bell, ringing under the water out past the wrecks. Gran says it's the old church that slid into the sea. I think something rings it.",
	"letter_5": "Old Gravel-Jaw took the Mary Ann's whole net last night, floats and all. Three men on the winch and it pulled them to their knees. Nobody fishes the wrecks in a storm now.",
	"letter_6": "Saw a golden fish under the piers at the king tide, long as my arm and shining like a lamp. By the time I fetched my rod it was gone. Once a moon, they say.",
	"letter_7": "In the fog a pale shape glides over the flats at low tide, wide as a door. The children call her the Pale Lady. She means no harm. She's lonely, I think.",
	"letter_8": "The keeper told me what he saw from the lamp room the winter before he went: a shadow in the trench longer than the breakwater, rising when the Eye's light swept over it. \"It's watching the light,\" he said. \"While the Eye burns, it keeps its distance.\"",
	"letter_9": "The co-op wanted Kelpwood's waters to themselves. They hung lanterns in the fog to lure honest boats onto the rocks. The keeper put a stop to it. That's why they wanted his lens.",
	"letter_10": "We made peace at the lighthouse, all five boats, the spring after the Storm Year. We shared out the grounds and swore to keep the light burning. A plain lamp, mind. The Eye was never found.",
	"letter_11": "Hooked something odd today. It looked at me. It had too many fins and I think it winked. I let it go. I'm not telling anyone. Except you, bottle.",
	"letter_12": "Where I hid the key is a fish's business now. Silverjaw never takes a hook twice. If you're clever, she'll take it once. E.M.",
}

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var _bells: Array[Node3D] = []
var _bell_seq: Array = []
var _stones: Array[Node3D] = []
var _lanterns: Array = []  # {node, light, flame}
var _lit: Array = []
var _bottles := {}  # letter id -> Sprite3D
var _bob_t := 0.0
var _chest_ui: CanvasLayer
var _dials: Array[Label] = []
var _dial := [0, 0, 0]
var _dial_i := 0
var _chest_open := false
var _fire_tex: Texture2D


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node) -> void:
	world = w
	player = p
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	var m: Dictionary = save.mystery
	for k in ["step", "stones"]:
		if not m.has(k):
			m[k] = 0 if k == "step" else [0, 0, 0]
	_fire_tex = load("res://art/decor/fire.png")
	_build_marks()
	_build_bells()
	_build_stones()
	_build_lanterns()
	_build_chest()
	_build_cave()
	_build_bottles()
	_build_chest_ui()


func step() -> int:
	return int(save.mystery.step)


func page(i: int) -> Dictionary:
	return PAGES[clampi(i, 0, PAGES.size() - 1)]


## Move the story on: note the page in the Journal and say so.
func advance(to: int) -> void:
	if step() >= to:
		return
	save.mystery.step = to
	SaveGame.write(save)
	var p := page(to)
	audio.play("fanfare2", -2.0)
	audio.play("cardflip", -4.0)
	hud.show_area(str(p.title), "A new page for your Journal (J)", true)
	hud.toast(str(p.riddle))


# --- the world's mystery objects --------------------------------------------------------

func _ground(v: Vector2) -> Vector3:
	return Vector3(v.x, world.stand_height(v.x, v.y), v.y)


func _sprite(tex: String, at: Vector3, px := 1.0 / 32.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load("res://art/decor/%s.png" % tex)
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(s)
	s.global_position = at + Vector3(0.0, s.texture.get_height() * px * 0.5, 0.0)
	return s


func _mat(tex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/tex/%s.png" % tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


func _flat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.4 if glow == 0.0 else 0.0
	m.roughness = 0.5
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	mi.position = at
	return mi


func _build_marks() -> void:
	_sprite("mark_stone", _ground(ESTUARY_STONE))
	_sprite("mark_stone", _ground(LAKE_MARK))
	_sprite("mark_stone", _ground(Vector2(298.6, 229.6)), 1.0 / 40.0)  # by the mill bells
	_sprite("mark_stone", _ground(Vector2(756.0, 637.0)), 1.0 / 40.0)  # among Kelpwood's lanterns
	_sprite("mark_stone", _ground(CHEST + Vector2(-1.6, -0.6)), 1.0 / 40.0)
	_sprite("mark_stone", _ground(CAVE + Vector2(-1.8, 1.2)), 1.0 / 40.0)


func _build_bells() -> void:
	var base := _ground(Vector2(297.4, 233.4))
	var frame := Node3D.new()
	add_child(frame)
	frame.global_position = base
	var wood := _mat("timber")
	for z in [-2.3, 2.3]:
		_box(Vector3(0.18, 2.6, 0.18), Vector3(0.0, 1.3, z), wood, frame)
	_box(Vector3(0.2, 0.2, 4.8), Vector3(0.0, 2.55, 0.0), wood, frame)
	var brass := _flat(Color(0.82, 0.62, 0.26))
	for i in 4:
		var size := 0.42 - i * 0.07  # biggest to smallest
		var bell := Node3D.new()
		frame.add_child(bell)
		bell.position = Vector3(0.0, 2.45, BELLS[i].y - base.z)
		var cone := CylinderMesh.new()
		cone.top_radius = size * 0.45
		cone.bottom_radius = size
		cone.height = size * 1.5
		cone.radial_segments = 12
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = brass
		mi.position.y = -size * 0.75 - 0.08
		bell.add_child(mi)
		_bells.append(bell)


func _build_stones() -> void:
	var stones: Array = save.mystery.stones
	var eye := StandardMaterial3D.new()
	eye.albedo_texture = load("res://art/decor/eye_carving.png")
	eye.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	eye.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	for i in 3:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.global_position = _ground(GULL_STONES[i])
		_box(Vector3(0.9, 2.0, 0.7), Vector3(0.0, 1.0, 0.0), _mat("stone"), pivot)
		_box(Vector3(1.05, 0.25, 0.85), Vector3(0.0, 2.1, 0.0), _mat("stone"), pivot)
		var q := QuadMesh.new()
		q.size = Vector2(0.6, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = eye
		mi.position = Vector3(0.0, 1.5, -0.36)  # the eye looks along -Z
		mi.rotation.y = PI
		pivot.add_child(mi)
		pivot.rotation.y = -int(stones[i]) * PI * 0.25
		_stones.append(pivot)


## Which of 8 directions (0 north, clockwise) points from a to b.
static func dir8(a: Vector2, b: Vector2) -> int:
	var d := b - a
	var ang := atan2(d.x, -d.y)  # 0 north, positive clockwise
	return posmod(int(round(ang / (PI * 0.25))), 8)


func _build_lanterns() -> void:
	var solved := step() > 4
	for i in 4:
		var at := _ground(LANTERNS[i])
		var root := Node3D.new()
		add_child(root)
		root.global_position = at
		_box(Vector3(0.5, 0.9, 0.5), Vector3(0.0, 0.45, 0.0), _mat("stone"), root)
		_box(Vector3(0.6, 0.12, 0.6), Vector3(0.0, 0.96, 0.0), _mat("stone"), root)
		_box(Vector3(0.42, 0.4, 0.42), Vector3(0.0, 1.22, 0.0), _flat(Color(0.25, 0.22, 0.2)), root)
		_box(Vector3(0.66, 0.14, 0.66), Vector3(0.0, 1.5, 0.0), _mat("stone"), root)
		var flame := Sprite3D.new()
		flame.texture = _fire_tex
		flame.hframes = 4
		flame.pixel_size = 1.0 / 48.0
		flame.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		flame.shaded = false
		flame.position = Vector3(0.0, 1.24, 0.0)
		root.add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.4)
		light.omni_range = 6.0
		light.light_energy = 1.4
		light.position = Vector3(0.0, 1.4, 0.0)
		root.add_child(light)
		_lanterns.append({"node": root, "flame": flame, "light": light})
		_set_lantern(i, solved)


func _set_lantern(i: int, on: bool) -> void:
	var l: Dictionary = _lanterns[i]
	var flame: Sprite3D = l.flame
	var light: OmniLight3D = l.light
	flame.visible = on
	light.visible = on


func _build_chest() -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = _ground(CHEST)
	root.rotation.y = 0.4
	_box(Vector3(1.2, 0.6, 0.75), Vector3(0.0, 0.3, 0.0), _mat("timber"), root)
	_box(Vector3(1.24, 0.24, 0.8), Vector3(0.0, 0.72, 0.0), _mat("planks"), root)
	var iron := _flat(Color(0.3, 0.3, 0.34))
	for x in [-0.42, 0.42]:
		_box(Vector3(0.08, 0.86, 0.82), Vector3(x, 0.43, 0.0), iron, root)
	_box(Vector3(0.3, 0.22, 0.06), Vector3(0.0, 0.55, 0.4), _flat(Color(0.82, 0.62, 0.26)), root)


func _build_cave() -> void:
	var at := _ground(CAVE)
	var s := _sprite("cave_mouth", at + Vector3(0.6, 0.0, 0.3), 1.0 / 20.0)
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.rotation.y = -PI * 0.55  # facing the village
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.2)
	glow.omni_range = 5.0
	glow.light_energy = 1.2
	add_child(glow)
	glow.global_position = at + Vector3(0.0, 0.6, 0.0)


func _build_bottles() -> void:
	var book: Dictionary = save.log
	for id in BOTTLES:
		if book.has(id):
			continue  # already found
		var v: Vector2 = BOTTLES[id]
		var s := _sprite("bottle", Vector3(v.x, 0.0, v.y), 1.0 / 28.0)
		_bottles[id] = s


func _process(delta: float) -> void:
	_bob_t += delta
	for id in _bottles:
		var s: Sprite3D = _bottles[id]
		var wl: float = world.sea_level
		s.global_position.y = wl + 0.25 + sin(_bob_t * 2.0 + s.global_position.x) * 0.08
		s.rotation.z = sin(_bob_t * 1.3 + s.global_position.z) * 0.25
	for l in _lanterns:
		var flame: Sprite3D = l.flame
		if flame.visible:
			flame.frame = int(_bob_t * 8.0) % 4
	for b in _bells:
		b.rotation.x = lerpf(b.rotation.x, 0.0, minf(1.0, delta * 3.0)) if absf(b.rotation.x) > 0.001 else 0.0
	if _chest_open:
		_chest_input()


# --- interacting ---------------------------------------------------------------------------

func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if _chest_open:
		return {}
	var best := {}
	var best_d := RANGE
	var cands: Array = []
	cands.append({"at": ESTUARY_STONE, "kind": "estuary", "text": "Space: Look at the carved stone"})
	cands.append({"at": LAKE_MARK, "kind": "lakemark", "text": "Space: Look at the carved stone"})
	for i in 4:
		cands.append({"at": BELLS[i] + Vector2(-0.9, 0.0), "kind": "bell", "i": i, "text": "Space: Ring the %s bell" % ["biggest", "second", "third", "smallest"][i]})
		cands.append({"at": LANTERNS[i], "kind": "lantern", "i": i, "text": "Space: Light the lantern"})
	for i in 3:
		cands.append({"at": GULL_STONES[i], "kind": "stone", "i": i, "text": "Space: Turn the standing stone"})
	cands.append({"at": CHEST, "kind": "chest", "text": "Space: Look at the old sea chest"})
	cands.append({"at": CAVE, "kind": "cave", "text": "Space: Look into the cave"})
	for id in _bottles:
		var s: Sprite3D = _bottles[id]
		cands.append({"at": Vector2(s.global_position.x, s.global_position.z), "kind": "bottle", "id": id, "text": "Space: Fish out the bottle", "reach": 3.0})
	for c in cands:
		var at: Vector2 = c.at
		var to := at - Vector2(pos.x, pos.z)
		var d := to.length()
		var reach := float(c.get("reach", RANGE))
		if d > reach or d > best_d + (reach - RANGE):
			continue
		if c.kind != "bottle" and absf(pos.y - float(world.stand_height(at.x, at.y))) > 2.5:
			continue
		if d > 0.8 and Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.25:
			continue
		if c.kind == "lantern" and (_lit.has(int(c.i)) or step() > 4):
			continue
		best_d = d
		best = c.duplicate()
		best["kind"] = "mystery_" + str(c.kind)
		best["dist"] = d
	return best


func use(it: Dictionary) -> void:
	match str(it.kind):
		"mystery_estuary":
			_estuary()
		"mystery_lakemark":
			hud.toast("A carved stone: a gull with one wing. Beneath it, scratched small: \"S. rises at first light, when the water is glass.\"")
			audio.play("pin", -6.0)
		"mystery_bell":
			_ring(int(it.i))
		"mystery_stone":
			_turn_stone(int(it.i))
		"mystery_lantern":
			_light(int(it.i))
		"mystery_chest":
			_chest()
		"mystery_cave":
			_cave()
		"mystery_bottle":
			_bottle(str(it.id))


func _estuary() -> void:
	if step() < 1:
		hud.toast("An old stone carved with a gull. It has only one wing.")
		audio.play("pin", -6.0)
		return
	if step() > 1:
		hud.toast("The hollow where the keeper's tin was buried. Empty now.")
		return
	var tide := float(sea.env.tide)
	if tide > 0.3:
		hud.toast("The water's lapping at the stone's foot. Something's buried there; come back at low tide.")
		audio.play("plop", -6.0)
		return
	audio.play("crank", -2.0)
	audio.play("thud", -4.0)
	hud.toast("You dig at the foot of the stone and turn up a rusty tin. Inside, wrapped in oilcloth: a page.")
	advance(2)


func _ring(i: int) -> void:
	var pitch: float = [0.62, 0.8, 1.0, 1.28][i]
	audio.play("pin", -2.0, pitch)
	audio.play("coin", -14.0, pitch * 0.7)
	_bells[i].rotation.x = 0.5
	if step() != 2:
		return
	_bell_seq.append(i)
	if _bell_seq.size() > BELL_ORDER.size():
		_bell_seq = _bell_seq.slice(_bell_seq.size() - BELL_ORDER.size())
	if _bell_seq == BELL_ORDER:
		_bell_seq.clear()
		audio.play("thud", -4.0)
		hud.toast("As the last note fades, a board on the bell frame drops loose. Behind it, tucked in the timber: a page.")
		advance(3)


func _turn_stone(i: int) -> void:
	var stones: Array = save.mystery.stones
	stones[i] = (int(stones[i]) + 1) % 8
	var pivot: Node3D = _stones[i]
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:y", -int(stones[i]) * PI * 0.25 - (TAU if stones[i] == 0 else 0.0), 0.35)
	if int(stones[i]) == 0:
		tw.tween_callback(func() -> void: pivot.rotation.y = 0.0)
	audio.play("thud", -6.0, 0.6)
	SaveGame.write(save)
	if step() != 3:
		return
	for k in 3:
		if int(stones[k]) != dir8(GULL_STONES[k], STONE_TARGETS[k]):
			return
	audio.play("crank", -2.0)
	hud.toast("With a grinding of stone, the middle stone's base slides aside. In the hollow beneath: a page in a jar.")
	advance(4)


func _light(i: int) -> void:
	if step() > 4 or _lit.has(i):
		return
	_lit.append(i)
	_set_lantern(i, true)
	audio.play("whoosh", -8.0, 1.4)
	if step() != 4:
		if _lit.size() >= 4:
			_gutter(false)
		return
	var k := _lit.size() - 1
	if int(_lit[k]) != LANTERN_ORDER[k]:
		_gutter(true)
		return
	if _lit.size() == 4:
		audio.play("crank", -2.0)
		hud.toast("All four lanterns burn, and in their crossed light you see it: a page pinned under the eaves of the old well.")
		advance(5)


## The lanterns gutter out, all of them.
func _gutter(say: bool) -> void:
	await get_tree().create_timer(0.8).timeout
	if step() > 4:
		return
	for j in 4:
		_set_lantern(j, false)
	_lit.clear()
	audio.play("plop", -6.0, 0.6)
	if say:
		hud.toast("The lanterns gutter out. The order must matter.")


func _chest() -> void:
	if step() < 6:
		hud.toast("An old sea chest chained to the rock. Three brass dials and a keyhole, and a one-winged gull on the lid.")
		audio.play("pin", -6.0)
		return
	if step() > 6:
		hud.toast("The keeper's chest, open and empty.")
		return
	_open_dials()


func _cave() -> void:
	if step() < 7:
		hud.toast("A dark cleft in the rock. Warm air breathes out of it, and somewhere deep inside, a glow.")
		audio.play("whoosh", -12.0, 0.6)
		return
	if step() > 7:
		hud.toast("The keeper's cave. Warm, and empty now.")
		return
	audio.play("whoosh", -6.0, 0.5)
	audio.play("jackpot", -2.0)
	save.mystery.eye = true
	player.show_off(load("res://art/decor/gulls_eye.png"))
	hud.toast("Deep in the cave, on a ledge of black rock, wrapped in sailcloth: the Gull's Eye. It's warm in your hands.")
	advance(8)
	await get_tree().create_timer(2.5).timeout
	player.hide_held()


## The lighthouse lamp room. Returns true if the Eye was set in the lamp.
func restore_light() -> bool:
	if step() != 8:
		return false
	save.mystery.restored = true
	save.shells = int(save.shells) + 5000
	hud.set_shells(save.shells)
	world.restore_light()
	audio.play("jackpot")
	hud.toast("You set the Gull's Eye in the lamp. The light pours out gold across the bay. Gullhaven pays its keeper: +5000 Shells.")
	advance(9)
	return true


func _bottle(id: String) -> void:
	var s: Sprite3D = _bottles.get(id, null)
	if s:
		s.queue_free()
	_bottles.erase(id)
	var book: Dictionary = save.log
	var entry: Dictionary = book.get(id, {})
	entry["count"] = int(entry.get("count", 0)) + 1
	book[id] = entry
	SaveGame.write(save)
	audio.play("splash", -8.0)
	audio.play("cardflip", -4.0)
	var e: Dictionary = sea.by_id.get(id, {})
	hud.toast("A message in a bottle: \"%s\". It's in your Journal (J)." % str(e.get("n", "A letter")).get_slice(": ", 1))


## Called when something bites: the mystery's special fish, if it's time for one.
func special_catch(zone: String) -> Dictionary:
	var E: Dictionary = sea.env
	var h := float(E.hour)
	if zone == "lake" and step() == 5 and h >= 4.5 and h < 8.0 and str(E.sky) == "calm" and randf() < 0.4:
		return sea.by_id.get("silverjaw", {})
	if zone == "deep" and step() >= 9 and (h >= 20.0 or h < 4.0) and randf() < 0.12:
		return sea.by_id.get("the_warden", {})
	return {}


## Called when you land something: Silverjaw carries the key.
func on_catch(id: String, _cm := 0.0, _variant := "") -> void:
	if id == "silverjaw" and step() == 5:
		hud.toast("Something glints in Silverjaw's jaw: a brass key, wrapped in oilcloth.")
		advance(6)


# --- the chest's dials ------------------------------------------------------------------------

func _build_chest_ui() -> void:
	_chest_ui = CanvasLayer.new()
	_chest_ui.layer = 21
	_chest_ui.visible = false
	add_child(_chest_ui)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest_ui.add_child(center)
	var panel := UI.panel(20.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var title := UI.label("The keeper's chest", 30, UI.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	for i in 3:
		var l := UI.label("0", 64, UI.CREAM, true)
		l.custom_minimum_size = Vector2(70.0, 0.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		_dials.append(l)
	var hint := UI.label("Left/right: choose a dial   Up/down: turn it   Space: try the lock   Esc: leave it", 18, UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _open_dials() -> void:
	_chest_open = true
	_chest_ui.visible = true
	hud.modal = true
	player.can_move = false
	_dial_i = 0
	_show_dials()
	audio.play("click")


func _close_dials() -> void:
	_chest_open = false
	_chest_ui.visible = false
	hud.modal = false
	hud.block_input(0.25)
	player.can_move = true


func _show_dials() -> void:
	for i in 3:
		_dials[i].text = str(_dial[i])
		_dials[i].add_theme_color_override("font_color", UI.GOLD if i == _dial_i else UI.CREAM)


func _chest_input() -> void:
	if Input.is_action_just_pressed("cancel"):
		_close_dials()
		return
	if Input.is_action_just_pressed("move_left"):
		_dial_i = (_dial_i + 2) % 3
		audio.play("click", -8.0)
	if Input.is_action_just_pressed("move_right"):
		_dial_i = (_dial_i + 1) % 3
		audio.play("click", -8.0)
	if Input.is_action_just_pressed("move_up"):
		_dial[_dial_i] = (int(_dial[_dial_i]) + 1) % 10
		audio.play("crank", -12.0, 1.6)
	if Input.is_action_just_pressed("move_down"):
		_dial[_dial_i] = (int(_dial[_dial_i]) + 9) % 10
		audio.play("crank", -12.0, 1.6)
	if Input.is_action_just_pressed("action"):
		if _dial == CHEST_CODE:
			_close_dials()
			audio.play("crank", -2.0)
			hud.toast("The dials click, the key turns, and the lid creaks open.")
			advance(7)
		else:
			audio.play("thud", -6.0)
			hud.toast("The key turns halfway and sticks. Wrong numbers.")
	_show_dials()
