extends Node3D
## Taming the town cats, and a companion of your own. Every cat on the coast has a name and
## a mind of its own. Offer one a fish (a pilchard, a live yakka, a bit of squid or a prawn
## from your bait tin) once a town hour and it trusts you a little more. When it trusts you
## completely, ask it to come along: it follows you about, sits beside you while you fish,
## rides in your boat, curls up in your hut, and now and then sniffs out something buried
## in the sand. One companion at a time; the last one goes home if you take another.

const Billboard := preload("res://scripts/billboard.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TAME := 4  # fish it takes
const FISH := ["pilchard", "livebait", "squid", "prawn"]
const NAMES := ["Sardine", "Pickles", "Captain", "Mittens", "Pebble", "Socks", "Kipper", "Nori", "Bramble", "Tofu",
	"Marmalade", "Waffles", "Salty", "Barnacle", "Inky", "Cinder", "Toast", "Olive", "Gus", "Pilot", "Smudge", "Clove",
	"Rascal", "Shrimp", "Moss", "Ziggy", "Pudding", "Fig", "Dot", "Bosun"]
const PIXEL := 1.0 / 40.0
const COLS := 5

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var fishing: Node
var boats: Node3D
var sprite: Sprite3D  # your companion, or null
var _id := ""
var _walk_t := 0.0
var _idle_t := 0.0
var _dir := Vector3.BACK
var _sniff_t := 50.0
var _sniff_to := Vector3.INF
var _heart_tex: ImageTexture


func setup(w: Node3D, p: CharacterBody3D, c: Camera3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node) -> void:
	world = w
	player = p
	cam = c
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	_heart_tex = town._heart_tex
	for i in world.cats.size():
		var cat: Sprite3D = world.cats[i]
		cat.set_meta("cat_id", "cat_%d" % i)
	if str(save.companion) != "":
		_adopt(str(save.companion), false)


func cat_id(cat: Sprite3D) -> String:
	return str(cat.get_meta("cat_id", ""))


func cat_name(id: String) -> String:
	var i := int(id.trim_prefix("cat_"))
	return NAMES[i % NAMES.size()]


func trust(id: String) -> int:
	var cats: Dictionary = save.cats
	return int(cats.get(id, {}).get("trust", 0))


func _fish_on_hand() -> String:
	var tin: Dictionary = save.bait
	for k in FISH:
		if int(tin.get(k, 0)) > 0:
			return k
	return ""


## What happens if you press Space at a town cat.
func cat_prompt(cat: Sprite3D) -> String:
	var id := cat_id(cat)
	var n := cat_name(id)
	if trust(id) >= TAME:
		return "Space: Ask %s to come along" % n
	var fish := _fish_on_hand()
	if fish != "" and _hungry(id):
		return "Space: Offer %s a %s" % [n, _bait_name(fish)]
	return "Space: Pet %s" % n


func _bait_name(k: String) -> String:
	var b: Dictionary = sea.bait.get(k, {})
	return str(b.get("n", k)).to_lower()


func _hungry(id: String) -> bool:
	var cats: Dictionary = save.cats
	return sea.now() >= float(cats.get(id, {}).get("fed", -999.0)) + 60.0


func cat_use(cat: Sprite3D) -> void:
	var id := cat_id(cat)
	var n := cat_name(id)
	var t := trust(id)
	if t >= TAME:
		_adopt(id, true)
		return
	var fish := _fish_on_hand()
	if fish == "" or not _hungry(id):
		town._pet(cat)
		if fish == "" and t == 0:
			hud.toast("%s sniffs your hand. Cats love fish: Hale's Tackle sells pilchards." % n)
		elif fish != "":
			hud.toast("%s isn't hungry right now. Try again in a town hour." % n)
		return
	var tin: Dictionary = save.bait
	tin[fish] = int(tin[fish]) - 1
	var cats: Dictionary = save.cats
	var rec: Dictionary = cats.get(id, {})
	rec["trust"] = t + 1
	rec["fed"] = sea.now()
	cats[id] = rec
	SaveGame.write(save)
	town._pet(cat)
	audio.play("purr", 0.0, 1.1)
	if t + 1 >= TAME:
		hud.toast("%s gobbles the %s and winds round your legs. %s trusts you completely! Press Space to ask it along." % [n, _bait_name(fish), n])
		audio.play("fanfare1", -4.0)
	else:
		var hearts := "<3 ".repeat(t + 1)
		hud.toast("%s gobbles the %s. Trust: %s(%d of %d)" % [n, _bait_name(fish), hearts, t + 1, TAME])


func _adopt(id: String, announce: bool) -> void:
	var town_cat: Sprite3D = null
	for c: Sprite3D in world.cats:
		if cat_id(c) == id:
			town_cat = c
	if town_cat == null:
		save.companion = ""
		return
	# the last companion goes home
	if _id != "" and _id != id:
		for c: Sprite3D in world.cats:
			if cat_id(c) == _id:
				c.visible = true
		if announce:
			hud.toast("%s heads home." % cat_name(_id))
	if sprite:
		sprite.queue_free()
	_id = id
	save.companion = id
	town_cat.visible = false
	sprite = Billboard.sprite(town_cat.texture, PIXEL, COLS, 4, 29.0)
	add_child(sprite)
	var face: Vector3 = player.facing
	sprite.global_position = player.global_position - face * 1.2
	if announce:
		SaveGame.write(save)
		audio.play("purr")
		audio.play("fanfare2", -6.0)
		hud.toast("%s is your companion now! It'll follow you everywhere, and sniff out buried finds." % cat_name(id))


func companion_name() -> String:
	return cat_name(_id) if _id != "" else ""


## Your companion, as something to pet.
func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if sprite == null:
		return {}
	var to := Vector2(sprite.global_position.x - pos.x, sprite.global_position.z - pos.z)
	var d := to.length()
	if d > 1.4 or absf(sprite.global_position.y - pos.y) > 1.5:
		return {}
	if d > 0.7 and Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.3:
		return {}
	return {"kind": "companion", "dist": d, "text": "Space: Pet %s" % cat_name(_id)}


func use(_it: Dictionary) -> void:
	if sprite:
		town._pet(sprite)
		_idle_t = 0.0


func _process(delta: float) -> void:
	if sprite == null:
		return
	var p := player.global_position
	var riding: bool = player.riding
	var fishing_now: bool = fishing != null and int(fishing.state) != 0
	# where it wants to be: just behind you (or beside you while you fish)
	var face: Vector3 = player.facing
	var want := p - face * 1.1 + face.cross(Vector3.UP) * 0.5
	if fishing_now or riding:
		want = p + face.cross(Vector3.UP) * 0.7
	if _sniff_to != Vector3.INF:
		want = _sniff_to
	var here := sprite.global_position
	var flat := Vector3(want.x - here.x, 0.0, want.z - here.z)
	var dist := flat.length()
	# too far, or somewhere it can't walk (indoors, aboard): just be there
	if dist > 22.0 or absf(here.y - p.y) > 3.0 or riding:
		sprite.global_position = Vector3(want.x, p.y, want.z)
		dist = 0.0
	var moving := false
	if dist > 0.35 and not riding:
		var speed := clampf(dist * 2.2, 1.5, 6.5)
		var step := flat.normalized() * minf(speed * delta, dist)
		var next := here + step
		var indoors: bool = world.indoor
		var wet: bool = not indoors and world.is_water(next.x, next.z) and float(world.water_depth(next.x, next.z)) > 0.3
		if not wet:
			moving = true
			_dir = flat.normalized()
			next.y = p.y if indoors else float(world.stand_height(next.x, next.z))
			sprite.global_position = next
	if moving:
		_walk_t += delta * 9.0
		_idle_t = 0.0
	else:
		_idle_t += delta
		if _sniff_to != Vector3.INF and dist <= 0.4:
			_dig_here()
	if fishing_now:
		_dir = face
	var row := Billboard.row_for(_dir, cam)
	var col := 0
	if moving:
		col = [1, 0, 2, 0][int(_walk_t) % 4]
	elif _idle_t > 25.0:
		col = 4
		row = Billboard.DOWN
	elif _idle_t > 2.0 or fishing_now or riding:
		col = 3
	sprite.frame = row * COLS + col
	_sniff(delta)


## Every so often your cat trots off and paws at the sand: something's buried there.
func _sniff(delta: float) -> void:
	if world.indoor or player.riding or player.swimming or _sniff_to != Vector3.INF:
		return
	_sniff_t -= delta
	if _sniff_t > 0.0:
		return
	_sniff_t = randf_range(45.0, 90.0)
	var p := player.global_position
	for attempt in 16:
		var a := randf() * TAU
		var r := randf_range(4.0, 10.0)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		var m: String = world.mat_at(x, z)
		var h: float = world.height_at(x, z)
		if m in ["sand", "pebble", "rock"] and h > float(world.sea_level) + 0.15 and h < float(world.sea_level) + 2.5 and world.walkable(x, z):
			_sniff_to = Vector3(x, h, z)
			return


func _dig_here() -> void:
	var at := _sniff_to
	_sniff_to = Vector3.INF
	town.add_comb_at(at)
	audio.play("purr", -6.0, 1.3)
	hud.toast("%s paws at the ground and looks at you. Something's buried here!" % cat_name(_id))
