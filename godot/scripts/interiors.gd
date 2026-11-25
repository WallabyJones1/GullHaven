extends Node3D
## Inside every building. Face a door and press Space to go in: the screen fades, and you
## step into a furnished room built for that kind of place (a tackle shop with rod racks,
## a tavern with a fire, the aquarium with your own catches swimming in the tanks, a
## cottage, your hut...). Shopkeepers wait behind their counters. Walk back out through
## the door to leave.
## Rooms are built high above their building, out of sight of the world, which is hidden
## while you're indoors. The camera comes in closer and only turns a little.

const Billboard := preload("res://scripts/billboard.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Furniture := preload("res://scripts/furniture.gd")
const Homes := preload("res://scripts/token/homes.gd")

const ROOM_Y := 240.0
const WALL_H := 3.2
const FRONT_H := 0.7  # the near wall is cut away so you can see in
const DOOR_W := 1.6
const PX := 1.0 / 32.0  # decor sprites: 32 px to the metre
const DOOR_RANGE := 1.6
const THING_RANGE := 1.5
const FADE := 0.22
const FLOORS := {"wood": "floor_wood", "dark": "floor_wood_dark", "tile": "floor_tile", "blue": "floor_tile_blue",
	"stone": "floor_stone"}

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var day_night: Node
var hut_build: Node  # arranging furniture in your hut
var catalogue: CanvasLayer  # the Home Catalogue (Harbour economy build), see token/catalogue.gd
var map_screen: CanvasLayer  # the lighthouse shows you the bay
var mystery: Node3D  # the Gull's Eye
var minigames: Node3D  # darts in the tavern
var inside := {}  # the building you're in ({} outdoors)
var _room: Node3D
var _target: Node3D  # where new pieces go (the room, or one piece of furniture)
var furniture_nodes: Array = []  # [{item, node}] for what's placed in your hut
var _origin := Vector3.ZERO
var _w := 8.0
var _d := 7.0
var _keeper_at := Vector3.ZERO
var _swapped := {}  # who -> their outdoor sprite, while they're in here with you
var _things: Array = []  # {pos, text, kind, data}
var _fires: Array[Sprite3D] = []
var _swimmers: Array = []  # {node, from, to, t, speed}
var _sky_mats: Array[StandardMaterial3D] = []
var _mats := {}
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _settle := 0.0
var _out_yaw := 0.0
var _t := 0.0
var on_gallery := false  # up on the lighthouse's lamp gallery, outdoors
var _gallery: Node3D
var _lighthouse := {}  # the lighthouse building, while you're up top
var _stair_top := Vector3.INF  # the top of the lighthouse stair (room space): walk up and you climb


func setup(w: Node3D, p: CharacterBody3D, c: Camera3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, dn: Node) -> void:
	world = w
	player = p
	cam = c
	hud = h
	audio = a
	sea = s
	save = sv
	day_night = dn
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 30
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	# shopkeepers (and anyone else who lives indoors) wait inside, not in the street
	for who in world.folk:
		var f: Dictionary = world.folk[who]
		if str(f.inside) != "":
			var node: Sprite3D = f.node
			node.visible = false


func is_inside() -> bool:
	return not inside.is_empty()


## The door you're standing at (facing it), as an interaction, or {}.
func door_near(pos: Vector3, facing: Vector3) -> Dictionary:
	if is_inside() or _busy:
		return {}
	var best := {}
	var best_d := DOOR_RANGE
	for b in world.buildings:
		var door: Vector3 = b.door
		var d := Vector2(pos.x - door.x, pos.z - door.z).length()
		if d > best_d or absf(pos.y - door.y) > 2.0:
			continue
		var node: Node3D = b.node
		if not is_instance_valid(node):
			continue
		var to := Vector2(node.global_position.x - pos.x, node.global_position.z - pos.z)
		if Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.2:
			continue
		best_d = d
		best = {"kind": "door", "building": b, "dist": d, "text": "Space: Go into %s" % _title(b)}
	return best


## Something in this room you could use (a bed, the notice board, a tank), or {}.
func thing_near(pos: Vector3, facing: Vector3) -> Dictionary:
	if on_gallery and not _busy:
		return {"kind": "descend", "text": "{action} Climb back down", "dist": 1.0, "pos": pos}
	if not is_inside() or _busy:
		return {}
	var best := {}
	var best_d := THING_RANGE
	for it in _things:
		var at: Vector3 = it.pos
		var to := Vector2(at.x - pos.x, at.z - pos.z)
		var d := to.length()
		if d > best_d:
			continue
		if d > 0.7 and Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.3:
			continue
		best_d = d
		best = it.duplicate()
		best["dist"] = d
	return best


func use(it: Dictionary) -> void:
	match str(it.get("kind", "")):
		"door":
			enter(it.building)
		"bed":
			_sleep(int(it.get("data", 0)))
		"board":
			_read_board()
		"tank":
			_look_tank()
		"trophy":
			_look_trophy()
		"look":
			hud.toast(str(it.data))
			audio.play("pin", -8.0)
		"arrange":
			if hut_build:
				hut_build.begin()
		"catalogue":
			if catalogue:
				catalogue.open(int(it.get("data", 0)))
		"climb":
			_climb()
		"descend":
			_descend()
		"keeper_stone":
			_keeper_stone()
		"darts":
			if minigames:
				minigames.start_darts()


func enter(b: Dictionary) -> void:
	if _busy or is_inside():
		return
	_busy = true
	player.can_move = false
	audio.play("step_wood", -4.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(_go_in.bind(b))
	tw.tween_property(_fade, "color:a", 0.0, FADE * 1.4)
	tw.tween_callback(_done)


func leave() -> void:
	if _busy or not is_inside():
		return
	_busy = true
	player.can_move = false
	audio.play("step_wood", -4.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(_go_out)
	tw.tween_property(_fade, "color:a", 0.0, FADE * 1.4)
	tw.tween_callback(_done)


func _done() -> void:
	_busy = false
	player.can_move = true
	_settle = 0.5


func _process(delta: float) -> void:
	_t += delta
	if not is_inside():
		return
	_settle = maxf(0.0, _settle - delta)
	if _stair_top != Vector3.INF and not _busy and _settle <= 0.0:
		var local := player.global_position - _origin
		if local.y > _stair_top.y - 0.45 and local.x > _stair_top.x - 0.6:
			_climb()
	for f in _fires:
		f.frame = int(_t * 8.0) % 4
	for s in _swimmers:
		var node: Sprite3D = s.node
		s.t = float(s.t) + delta * float(s.speed)
		var k := 0.5 + 0.5 * sin(float(s.t))
		var a: Vector3 = s.from
		var b: Vector3 = s.to
		node.position = a.lerp(b, k) + Vector3(0.0, sin(float(s.t) * 2.3) * 0.04, 0.0)
		node.flip_h = cos(float(s.t)) < 0.0
	_update_sky()
	# walk back out through the door
	if _busy or _settle > 0.0:
		return
	var p := player.global_position
	var mat := _origin + Vector3(0.0, 0.0, _d * 0.5 - 0.2)
	if absf(p.x - mat.x) < DOOR_W * 0.5 and p.z > mat.z - 0.5 and player.facing.z > 0.5 and player.velocity.length() > 0.5:
		leave()


# --- going in and out ---------------------------------------------------------------

func _go_in(b: Dictionary) -> void:
	inside = b
	var door: Vector3 = b.door
	_origin = Vector3(door.x, ROOM_Y, door.z)
	_build_room(b)
	# bring the people who work here inside
	for who in world.folk:
		var f: Dictionary = world.folk[who]
		if str(f.inside) == "" or str(f.inside) != str(b.role) or str(f.town) != str(b.town):
			continue
		var outdoor: Sprite3D = f.node
		var s := Billboard.sprite(outdoor.texture, 1.0 / 26.0, 5, 4, 46.0)
		s.position = _keeper_at
		s.frame = Billboard.DOWN * 5
		_into().add_child(s)
		_swapped[who] = outdoor
		f.node = s
		_keeper_at += Vector3(1.6, 0.0, 0.0)
	player.global_position = _origin + Vector3(0.0, 0.05, _d * 0.5 - 1.3)
	player.velocity = Vector3.ZERO
	player.face(Vector3.FORWARD)
	world.set_indoor(true)
	day_night.indoor = true
	_out_yaw = cam.yaw
	cam.indoor = true
	cam.set_yaw(0.0)
	cam.snap()
	hud.show_area(str(b.name), "", false)


func _go_out() -> void:
	var b := inside
	for who in _swapped:
		if world.folk.has(who):
			world.folk[who].node = _swapped[who]
	_swapped.clear()
	_clear_room()
	inside = {}
	var door: Vector3 = b.door
	var node: Node3D = b.get("node")
	var away: Vector3 = b.get("away", Vector3.BACK)
	if node:
		away = Vector3(door.x - node.global_position.x, 0.0, door.z - node.global_position.z).normalized()
	if b.has("visit") and node:
		node.queue_free.call_deferred()
	var out := door + away * 0.4
	out.y = maxf(float(world.height_at(out.x, out.z)), door.y) + 0.1
	player.global_position = out
	player.velocity = Vector3.ZERO
	player.face(away)
	world.set_indoor(false)
	day_night.indoor = false
	cam.indoor = false
	cam.set_yaw(_out_yaw)
	cam.snap()


func _clear_room() -> void:
	if _room:
		_room.queue_free()
		_room = null
	_stair_top = Vector3.INF
	_target = null
	_things.clear()
	_fires.clear()
	_swimmers.clear()
	_sky_mats.clear()
	furniture_nodes.clear()


## Rebuild the room you're in (after moving furniture), leaving you where you stand.
func refresh() -> void:
	if not is_inside():
		return
	_clear_room()
	_build_room(inside)


## The room's size, and whether you're in your own hut.
func room_size() -> Vector2:
	return Vector2(_w, _d)


func in_hut() -> bool:
	return is_inside() and str(inside.get("kind", "")) == "hut" and not inside.has("visit")


## In your home (Harbour economy build): the plot house you bought.
func in_home() -> bool:
	return is_inside() and str(inside.get("kind", "")) == "plot_home" and not inside.has("visit")


## Somewhere you can arrange your furniture: your hut, or your home.
func can_arrange() -> bool:
	return in_hut() or in_home()


## The furniture placed where you are (the hut and the home each keep their own).
func placed_list() -> Array:
	if in_home():
		return Homes.ensure(save).furniture
	return save.furniture


func arrange_fixed() -> Dictionary:
	if in_home():
		return {"floor": [Rect2(-DOOR_W * 0.5 - 0.2, _d * 0.5 - 1.5, DOOR_W + 0.4, 1.5)], "walls": []}
	return hut_fixed()


## Go to your home from wherever you are (the game menu's Harbour page). Walking out of
## its door brings you back to where you were standing.
func visit_home() -> bool:
	if _busy or is_inside() or not Homes.has_home(save):
		return false
	var h := Homes.ensure(save)
	var d := Homes.district(str(h.district))
	var here := player.global_position
	var facing: Vector3 = player.get("facing")
	var away := Vector3(facing.x, 0.0, facing.z)
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	enter({"name": "Your home, %s %s" % [str(d.get("n", "")), str(h.plot)], "kind": "plot_home", "role": "", "town": "",
		"door": here, "away": away, "size": Vector3(6.0, 3.0, 5.0),
		"room": Homes.room_size(save)})
	return true


func origin() -> Vector3:
	return _origin


func _into() -> Node3D:
	return _target if _target else _room


func _title(b: Dictionary) -> String:
	var n := str(b.name)
	if n == "Cottage" or n == "Boathouse":
		return "a cottage" if n == "Cottage" else "the boathouse"
	if n == "Your Hut":
		return "your hut"
	if n.begins_with("The ") or n.ends_with("'s Tackle") or n.ends_with("'s Bakery"):
		return n
	return "the " + n


# --- building a room ---------------------------------------------------------------

func _build_room(b: Dictionary) -> void:
	_room = Node3D.new()
	_room.name = "Room"
	add_child(_room)
	_target = null
	_room.global_position = _origin
	var role := str(b.role)
	var kind := str(b.kind)
	var size: Vector3 = b.size
	var key := role if role != "" else kind
	var dims := {"museum": Vector2(16.0, 11.0), "tavern": Vector2(13.0, 10.0), "inn": Vector2(12.0, 9.0),
		"lodge": Vector2(13.0, 10.0), "lighthouse": Vector2(7.0, 7.0), "mill": Vector2(9.0, 8.0),
		"harbourmaster": Vector2(11.0, 8.0)}
	var wd: Vector2 = dims.get(key, Vector2(clampf(size.x * 1.5, 8.0, 12.0), clampf(size.z * 1.45, 7.0, 9.0)))
	if key == "plot_home":  # (not "home": that's the Home Goods shop)
		wd = b.get("room", Vector2(8.0, 7.0))
	elif key == "hut":
		var tier_now := int((b.get("visit", {}) as Dictionary).get("tier", world.hut_tier))
		wd = [Vector2(7.0, 6.0), Vector2(8.5, 7.0), Vector2(10.0, 8.0), Vector2(12.0, 9.0), Vector2(13.5, 10.0), Vector2(15.0, 11.0)][clampi(tier_now, 0, 5)]
	_w = wd.x
	_d = wd.y
	_keeper_at = Vector3(0.0, 0.0, -_d * 0.5 + 1.7)
	# a black void beneath and around, so nothing of the world shows
	var void_mat := StandardMaterial3D.new()
	void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_mat.albedo_color = Color(0.015, 0.012, 0.02)
	var void_mesh := PlaneMesh.new()
	void_mesh.size = Vector2(160.0, 160.0)
	void_mesh.material = void_mat
	var void_mi := MeshInstance3D.new()
	void_mi.mesh = void_mesh
	void_mi.position.y = -0.6
	_into().add_child(void_mi)
	# a warm light (and a second in big rooms)
	_light(Vector3(0.0, WALL_H - 0.5, 0.0), 1.5, maxf(_w, _d) * 0.95, true)
	if _w > 11.0:
		_light(Vector3(-_w * 0.3, WALL_H - 0.6, -_d * 0.1), 0.8, 8.0, false)
		_light(Vector3(_w * 0.3, WALL_H - 0.6, -_d * 0.1), 0.8, 8.0, false)
	match key:
		"tackle":
			_shell("wood", "wall_wood", "wall_wood_light")
			_counter(Vector3(-_w * 0.12, 0.0, -_d * 0.5 + 2.4), Vector3(4.0, 1.0, 0.8), "planks")
			_keeper_at = Vector3(-_w * 0.12, 0.0, -_d * 0.5 + 1.5)
			_wall("rod_rack", "back", -_w * 0.32, 0.0)
			_wall("rod_rack", "back", -_w * 0.12, 0.0)
			_wall("shelf_bait", "back", _w * 0.2, 1.1)
			_wall("net_wall", "left", 0.0, 1.0)
			_wall("painting_boat", "right", -0.6, 1.5)
			_wall("window", "back", _w * 0.38, 0.9)
			_stand("crates", Vector3(_w * 0.36, 0.0, -_d * 0.5 + 0.9))
			_stand("rope_coil", Vector3(-_w * 0.4, 0.0, _d * 0.12))
			_barrels(Vector3(_w * 0.36, 0.0, _d * 0.1))
			_rug("rug_green", Vector3(0.0, 0.0, _d * 0.15), Vector2(3.2, 2.0))
		"fishmonger":
			_shell("blue", "wall_plaster", "wall_paper_blue")
			_counter(Vector3(0.0, 0.0, -_d * 0.5 + 2.4), Vector3(4.6, 1.0, 0.9), "stone")
			for x in [-1.4, 0.0, 1.4]:
				_on_counter("fish_ice", Vector3(x, 1.0, -_d * 0.5 + 2.4))
			_wall("life_ring", "back", -_w * 0.34, 1.6)
			_wall("chart", "back", _w * 0.3, 1.3)
			_wall("net_wall", "right", 0.0, 1.0)
			_stand("crates", Vector3(-_w * 0.38, 0.0, _d * 0.15))
			_barrels(Vector3(_w * 0.38, 0.0, _d * 0.1))
		"tavern", "inn", "lodge":
			_shell("dark", "wall_wood", "wall_paper_green" if key != "lodge" else "wall_wood_light")
			_counter(Vector3(-_w * 0.22, 0.0, -_d * 0.5 + 2.2), Vector3(5.0, 1.1, 0.8), "timber")
			_keeper_at = Vector3(-_w * 0.22, 0.0, -_d * 0.5 + 1.3)
			_wall("shelf_jars", "back", -_w * 0.3, 1.2)
			_wall("shelf_jars", "back", -_w * 0.1, 1.2)
			_wall("painting_sea", "back", _w * 0.16, 1.6)
			_fireplace("right", -_d * 0.1)
			for i in 3:
				var tx := -_w * 0.2 + i * 2.6
				_table(Vector3(tx, 0.0, _d * 0.12 + (i % 2) * 0.6))
			_rug("rug_red", Vector3(_w * 0.28, 0.0, -_d * 0.05), Vector2(2.6, 3.4))
			_wall("lantern", "left", -1.0, 1.9)
			_wall("lantern", "left", 1.0, 1.9)
			if key == "lodge":
				_wall("bookshelf", "back", _w * 0.36, 0.0)
				_trophy("left", 0.0)
			else:
				_stand("clock", Vector3(_w * 0.42, 0.0, -_d * 0.5 + 0.5), true)
			if key == "tavern":
				_wall("dartboard", "back", _w * 0.3, 1.25)
				_things.append({"pos": _to_world(Vector3(_w * 0.3, 0.0, -_d * 0.5 + 2.3)), "text": "Space: Play darts",
					"kind": "darts", "data": 0})
			_bed_for_hire(key)
		"boatyard", "boatworks":
			_shell("wood", "wall_wood", "wall_wood_light")
			_counter(Vector3(_w * 0.15, 0.0, -_d * 0.5 + 2.3), Vector3(3.6, 1.0, 0.8), "planks")
			_keeper_at = Vector3(_w * 0.15, 0.0, -_d * 0.5 + 1.4)
			_box(Vector3(-_w * 0.25, 0.0, -_d * 0.5 + 1.6), Vector3(1.8, 0.8, 1.0), "timber")
			_on_counter("boat_model", Vector3(-_w * 0.25, 0.8, -_d * 0.5 + 1.6))
			_wall("ship_wheel", "back", -_w * 0.38, 1.4)
			_wall("chart", "back", _w * 0.32, 1.3)
			_wall("anchor", "left", -0.5, 1.2)
			_wall("painting_boat", "right", 0.0, 1.5)
			_stand("rope_coil", Vector3(-_w * 0.38, 0.0, _d * 0.15))
			_stand("crates", Vector3(_w * 0.38, 0.0, _d * 0.1))
		"bakery":
			_shell("tile", "wall_plaster", "wall_paper")
			_counter(Vector3(0.0, 0.0, -_d * 0.5 + 2.3), Vector3(3.8, 1.0, 0.8), "plaster")
			for x in [-1.1, 0.4]:
				_on_counter("bread", Vector3(x, 1.0, -_d * 0.5 + 2.3))
			_stand("stove", Vector3(_w * 0.32, 0.0, -_d * 0.5 + 0.6))
			_stand("sacks", Vector3(-_w * 0.34, 0.0, -_d * 0.5 + 0.8))
			_wall("shelf_jars", "back", -_w * 0.05, 1.3)
			_wall("window", "left", 0.0, 0.9)
			_table(Vector3(_w * 0.25, 0.0, _d * 0.15))
			_stand("plant_flower", Vector3(-_w * 0.4, 0.0, _d * 0.2))
		"outfitter":
			_shell("wood", "wall_plaster", "wall_paper_blue")
			_counter(Vector3(_w * 0.18, 0.0, -_d * 0.5 + 2.2), Vector3(3.0, 1.0, 0.8), "planks")
			_keeper_at = Vector3(_w * 0.18, 0.0, -_d * 0.5 + 1.3)
			_on_counter("fabric_rolls", Vector3(_w * 0.28, 1.0, -_d * 0.5 + 2.2))
			_stand("clothes_rack", Vector3(-_w * 0.3, 0.0, -_d * 0.5 + 0.7))
			_stand("clothes_rack", Vector3(-_w * 0.38, 0.0, _d * 0.05))
			_stand("mirror", Vector3(_w * 0.42, 0.0, -_d * 0.5 + 0.6))
			_stand("hat_stand", Vector3(-_w * 0.08, 0.0, -_d * 0.5 + 0.6))
			_stand("mannequin", Vector3(_w * 0.38, 0.0, _d * 0.12))
			_wall("window", "left", -0.8, 0.9)
			_wall("painting_sea", "right", -0.6, 1.5)
			_rug("rug_red", Vector3(0.0, 0.0, _d * 0.15), Vector2(3.0, 2.2))
			_stand("plant_flower", Vector3(-_w * 0.42, 0.0, _d * 0.35))
		"carpenter", "home":
			_shell("wood", "wall_wood", "wall_wood_light" if key == "carpenter" else "wall_paper")
			_counter(Vector3(_w * 0.2, 0.0, -_d * 0.5 + 2.2), Vector3(3.0, 1.0, 0.8), "planks")
			_keeper_at = Vector3(_w * 0.2, 0.0, -_d * 0.5 + 1.3)
			if key == "carpenter":
				_box(Vector3(-_w * 0.22, 0.0, -_d * 0.5 + 1.0), Vector3(3.0, 0.9, 1.0), "timber")  # workbench
				for i in 4:
					_box(Vector3(-_w * 0.38, 0.1 + i * 0.12, _d * 0.1), Vector3(0.5, 0.1, 2.6), "planks")
				_wall("notice_board", "left", 0.0, 1.1)
				_stand("crates", Vector3(_w * 0.4, 0.0, _d * 0.15))
			else:  # Home Goods: furniture on show
				_bed(Vector3(-_w * 0.3, 0.0, -_d * 0.5 + 1.3), "quilt_blue", false)
				_rug("rug_blue", Vector3(-_w * 0.1, 0.0, _d * 0.15), Vector2(3.0, 2.0))
				_stand("clock", Vector3(-_w * 0.05, 0.0, -_d * 0.5 + 0.5), true)
				_stand("plant_fern", Vector3(_w * 0.42, 0.0, _d * 0.2))
				_stand("plant_flower", Vector3(-_w * 0.42, 0.0, _d * 0.25))
				_wall("painting_sea", "right", 0.0, 1.5)
			_wall("window", "back", -_w * 0.05, 0.9)
		"museum":
			_shell("stone", "wall_plaster", "wall_paper_blue")
			_counter(Vector3(_w * 0.3, 0.0, _d * 0.12), Vector3(2.4, 1.0, 0.8), "timber")
			_keeper_at = Vector3(_w * 0.3, 0.0, _d * 0.12 - 0.9)
			_aquarium()
			_wall("portrait", "left", -1.2, 1.5)
			_wall("chart", "left", 1.2, 1.3)
			_rug("rug_blue", Vector3(-_w * 0.1, 0.0, _d * 0.1), Vector2(4.0, 2.4))
		"harbourmaster":
			_shell("wood", "wall_wood", "wall_paper_blue")
			_box(Vector3(0.0, 0.0, -_d * 0.5 + 2.2), Vector3(2.6, 0.85, 1.1), "timber")  # desk
			_keeper_at = Vector3(0.0, 0.0, -_d * 0.5 + 1.2)
			_wall("chart", "back", -_w * 0.28, 1.2)
			_wall("chart", "back", _w * 0.3, 1.2)
			_wall("notice_board", "left", 0.0, 1.0)
			_things.append({"pos": _to_world(Vector3(-_w * 0.5 + 0.8, 0.0, 0.0)), "text": "Space: Read the notice board",
				"kind": "board", "data": 0})
			_stand("telescope", Vector3(_w * 0.36, 0.0, _d * 0.1))
			_stand("clock", Vector3(_w * 0.42, 0.0, -_d * 0.5 + 0.5), true)
			_wall("ship_wheel", "right", -0.4, 1.4)
			_rug("rug_red", Vector3(0.0, 0.0, _d * 0.15), Vector2(3.0, 2.0))
		"mill":
			_shell("stone", "wall_stone", "wall_wood")
			_wall("gears", "back", -_w * 0.2, 1.0)
			_wall("gears", "back", _w * 0.25, 1.3)
			_stand("sacks", Vector3(-_w * 0.32, 0.0, _d * 0.1))
			_stand("sacks", Vector3(_w * 0.3, 0.0, _d * 0.15))
			_box(Vector3(0.0, 0.0, -_d * 0.5 + 1.4), Vector3(1.6, 0.6, 1.6), "stone")  # millstone base
			_cyl(Vector3(0.0, 0.6, -_d * 0.5 + 1.4), 0.75, 0.3, "stone")
			_keeper_at = Vector3(-1.5, 0.0, -_d * 0.5 + 1.8)
		"general":
			_shell("wood", "wall_wood", "wall_wood_light")
			_counter(Vector3(0.0, 0.0, -_d * 0.5 + 2.3), Vector3(3.6, 1.0, 0.8), "planks")
			_wall("shelf_jars", "back", -_w * 0.3, 1.2)
			_wall("shelf_bait", "back", _w * 0.28, 1.2)
			_stand("sacks", Vector3(-_w * 0.38, 0.0, _d * 0.12))
			_barrels(Vector3(_w * 0.38, 0.0, _d * 0.1))
			_stand("crates", Vector3(_w * 0.36, 0.0, -_d * 0.5 + 0.9))
		"ranger":
			_shell("wood", "wall_wood", "wall_wood_light")
			_box(Vector3(0.0, 0.0, -_d * 0.5 + 2.2), Vector3(2.4, 0.85, 1.0), "timber")
			_keeper_at = Vector3(0.0, 0.0, -_d * 0.5 + 1.3)
			_wall("chart", "back", -_w * 0.28, 1.3)
			_wall("window", "back", _w * 0.28, 0.9)
			_stand("telescope", Vector3(_w * 0.36, 0.0, _d * 0.12))
			_stand("plant_fern", Vector3(-_w * 0.4, 0.0, _d * 0.2))
			_stand("plant_fern", Vector3(-_w * 0.4, 0.0, -_d * 0.5 + 0.6))
		"baittea", "kelptea":
			_shell("tile" if key == "baittea" else "blue", "wall_plaster", "wall_paper_green")
			_counter(Vector3(-_w * 0.15, 0.0, -_d * 0.5 + 2.2), Vector3(3.4, 1.0, 0.8), "timber")
			_keeper_at = Vector3(-_w * 0.15, 0.0, -_d * 0.5 + 1.3)
			_on_counter("tea_set", Vector3(-_w * 0.15 - 0.8, 1.0, -_d * 0.5 + 2.2))
			_wall("shelf_bait", "back", _w * 0.22, 1.2)
			_wall("painting_sea", "left", 0.0, 1.5)
			_table(Vector3(_w * 0.22, 0.0, _d * 0.12))
			_stand("plant_fern", Vector3(-_w * 0.4, 0.0, _d * 0.2))
		"salvager":
			_shell("stone", "wall_wood", "wall_wood")
			_counter(Vector3(0.0, 0.0, -_d * 0.5 + 2.3), Vector3(3.2, 1.0, 0.8), "timber")
			_wall("anchor", "back", -_w * 0.3, 1.2)
			_wall("ship_wheel", "back", _w * 0.3, 1.4)
			_wall("net_wall", "right", 0.0, 1.0)
			_stand("crates", Vector3(-_w * 0.38, 0.0, _d * 0.12))
			_stand("crates", Vector3(-_w * 0.36, 0.0, -_d * 0.5 + 0.9))
			_barrels(Vector3(_w * 0.38, 0.0, _d * 0.15))
			_wall("life_ring", "left", 0.4, 1.6)
		"forge":
			_shell("stone", "wall_stone", "wall_stone")
			_stand("furnace", Vector3(-_w * 0.25, 0.0, -_d * 0.5 + 0.6))
			_light(Vector3(-_w * 0.25, 0.9, -_d * 0.5 + 1.2), 2.2, 5.0, false, Color(1.0, 0.45, 0.2))
			_stand("anvil", Vector3(0.6, 0.0, -_d * 0.5 + 2.0), true)
			_counter(Vector3(_w * 0.25, 0.0, -_d * 0.5 + 2.2), Vector3(2.6, 1.0, 0.8), "stone")
			_keeper_at = Vector3(_w * 0.25, 0.0, -_d * 0.5 + 1.3)
			_barrels(Vector3(_w * 0.38, 0.0, _d * 0.15))
		"lighthouse":
			_shell("stone", "wall_stone", "wall_plaster")
			_box(Vector3(-_w * 0.5 + 0.75, 0.0, -_d * 0.5 + 1.9), Vector3(0.9, 0.85, 1.6), "timber")
			_things.append({"pos": _to_world(Vector3(-_w * 0.5 + 1.6, 0.0, -_d * 0.5 + 1.9)), "text": "Space: Read the keeper's log",
				"kind": "look", "data": "The keeper's log: \"Fog again. Three boats home safe by the light. A great shadow seen off the Deep, bigger than any boat.\""})
			_things.append({"pos": _to_world(Vector3(-_w * 0.5 + 0.9, 0.0, _d * 0.15)), "text": "Space: Look at the loose stone by the stair",
				"kind": "keeper_stone", "data": 0})
			_stand("telescope", Vector3(1.4, 0.0, -_d * 0.5 + 1.7))
			_wall("chart", "left", 0.0, 1.3)
			_stand("clock", Vector3(_w * 0.4, 0.0, _d * 0.1), true)
			_lighthouse_stair()
		"hut":
			_hut_room()
		"plot_home":
			_home_room()
		_:  # a cottage
			_cottage(b)
	_rebuild_sky()


## The stair up to the lamp, along the back wall: walk up it and you come out on the
## gallery at the top (or press the action button at the bottom).
func _lighthouse_stair() -> void:
	var x0 := -1.1
	var x1 := _w * 0.5 - 0.55
	var rise := 2.1
	var depth := 0.9
	var zc := -_d * 0.5 + 0.1 + depth * 0.5
	var steps := 8
	var run := x1 - x0
	var stone := _tex("wall_stone", 0.5)
	for i in steps:
		var h := rise * (i + 1) / steps
		_vis_box(Vector3(x0 + run * (i + 0.5) / steps, 0.0, zc), Vector3(run / steps + 0.01, h, depth), stone)
	# a smooth slope under the steps to walk on
	var ang := atan2(rise, run)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var length := sqrt(run * run + rise * rise) + 0.3
	shape.size = Vector3(length, 0.2, depth)
	col.shape = shape
	body.add_child(col)
	var normal := Vector3(-sin(ang), cos(ang), 0.0)
	body.position = Vector3(x0 + run * 0.5, rise * 0.5, zc) - normal * 0.1
	body.rotation = Vector3(0.0, 0.0, ang)
	_into().add_child(body)
	_collider(Vector3(x1 + 0.25, rise - 0.2, zc), Vector3(0.5, 0.2, depth))  # the landing
	# a rope rail along the open side
	var rail := _flat(Color(0.55, 0.38, 0.22))
	for i in 5:
		var t := float(i) / 4.0
		_vis_box(Vector3(x0 + run * t, rise * t, zc + depth * 0.5), Vector3(0.06, 0.9, 0.06), rail)
	_stair_top = Vector3(x1, rise, zc)
	_things.append({"pos": _to_world(Vector3(x0 - 0.5, 0.0, zc + 0.9)), "text": "Space: Climb the stairs to the lamp",
		"kind": "climb", "data": 0})


## Floor, walls, wainscot, the cut-away front wall and the door mat.
func _shell(floor_kind: String, lower: String, upper: String) -> void:
	var hw := _w * 0.5
	var hd := _d * 0.5
	var floor_mat := _tex(str(FLOORS.get(floor_kind, floor_kind if floor_kind.begins_with("home/") else "floor_wood")), 0.5)
	_box(Vector3(0.0, -0.4, 0.0), Vector3(_w + 0.4, 0.4, _d + 0.4), "", floor_mat)
	var upper_mat := _tex(upper, 0.45)
	var lower_mat := _tex(lower, 0.45)
	var trim := _tex("timber", 0.5)
	# back and sides
	_box(Vector3(0.0, 0.0, -hd - 0.15), Vector3(_w + 0.6, WALL_H, 0.3), "", upper_mat)
	_box(Vector3(-hw - 0.15, 0.0, 0.0), Vector3(0.3, WALL_H, _d + 0.3), "", upper_mat)
	_box(Vector3(hw + 0.15, 0.0, 0.0), Vector3(0.3, WALL_H, _d + 0.3), "", upper_mat)
	# wainscot and a picture rail
	_vis_box(Vector3(0.0, 0.0, -hd + 0.03), Vector3(_w, 1.0, 0.06), lower_mat)
	_vis_box(Vector3(-hw + 0.03, 0.0, 0.0), Vector3(0.06, 1.0, _d), lower_mat)
	_vis_box(Vector3(hw - 0.03, 0.0, 0.0), Vector3(0.06, 1.0, _d), lower_mat)
	_vis_box(Vector3(0.0, 1.0, -hd + 0.05), Vector3(_w, 0.08, 0.1), trim)
	_vis_box(Vector3(-hw + 0.05, 1.0, 0.0), Vector3(0.1, 0.08, _d), trim)
	_vis_box(Vector3(hw - 0.05, 1.0, 0.0), Vector3(0.1, 0.08, _d), trim)
	_vis_box(Vector3(0.0, WALL_H - 0.12, -hd + 0.05), Vector3(_w, 0.12, 0.1), trim)
	# the near wall: low, with the doorway in the middle (tall invisible walls keep you in)
	var side_w := (_w - DOOR_W) * 0.5
	for s in [-1.0, 1.0]:
		var cx: float = s * (DOOR_W * 0.5 + side_w * 0.5)
		_box(Vector3(cx, 0.0, hd + 0.15), Vector3(side_w + 0.3, FRONT_H, 0.3), "", lower_mat)
		_vis_box(Vector3(cx, FRONT_H, hd + 0.15), Vector3(side_w + 0.34, 0.08, 0.36), trim)
		_collider(Vector3(cx, 0.0, hd + 0.15), Vector3(side_w + 0.3, WALL_H, 0.3))
	_collider(Vector3(0.0, 0.0, hd + 1.1), Vector3(DOOR_W + 0.6, WALL_H, 0.3))  # just past the door
	for s in [-1.0, 1.0]:  # door frame posts
		_vis_box(Vector3(s * (DOOR_W * 0.5 + 0.06), 0.0, hd + 0.15), Vector3(0.14, FRONT_H + 0.25, 0.4), trim)
	var mat := _flat(Color(0.55, 0.38, 0.24))
	_vis_box(Vector3(0.0, 0.0, hd - 0.35), Vector3(DOOR_W - 0.2, 0.03, 0.6), mat)


func _cottage(b: Dictionary) -> void:
	var door: Vector3 = b.door
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(door.x * 7.0 + door.z * 13.0))
	var floors := ["wood", "dark", "tile", "stone"]
	var papers := ["wall_paper", "wall_paper_green", "wall_paper_blue", "wall_plaster"]
	_shell(floors[rng.randi() % floors.size()], "wall_wood", papers[rng.randi() % papers.size()])
	var left := rng.randf() < 0.5
	var bx := -_w * 0.3 if left else _w * 0.3
	_bed(Vector3(bx, 0.0, -_d * 0.5 + 1.2), ["quilt_red", "quilt_blue"][rng.randi() % 2], false)
	if rng.randf() < 0.5:
		_fireplace("left" if not left else "right", -_d * 0.1)
	else:
		_stand("stove", Vector3(-bx, 0.0, -_d * 0.5 + 0.6))
	_table(Vector3(-bx * 0.5, 0.0, _d * 0.08))
	_rug(["rug_red", "rug_blue", "rug_green"][rng.randi() % 3], Vector3(0.0, 0.0, _d * 0.12), Vector2(2.6, 1.8))
	_wall(["painting_sea", "painting_boat", "portrait"][rng.randi() % 3], "back", 0.0, 1.5)
	_wall("window", "back", -bx * 0.9, 0.9)
	if rng.randf() < 0.6:
		_stand("bookshelf", Vector3(-bx * 1.15, 0.0, -_d * 0.5 + 0.3), false)
	_stand(["plant_fern", "plant_flower"][rng.randi() % 2], Vector3(bx * 1.2, 0.0, _d * 0.25))
	if rng.randf() < 0.4:
		_stand("clock", Vector3(bx * 0.4, 0.0, -_d * 0.5 + 0.4), true)
	_things.append({"pos": _to_world(Vector3(bx, 0.0, -_d * 0.5 + 2.4)), "text": "Space: Look around",
		"kind": "look", "data": ["Someone's tidy little home. Best not touch anything.", "It smells of woodsmoke and fresh bread.",
			"A half-finished jigsaw of a lighthouse sits on the table.", "There's a well-thumbed tide table pinned by the door."][rng.randi() % 4]})


func _hut_room() -> void:
	# someone else's hut (online), or your own
	var v: Dictionary = inside.get("visit", {})
	var tier := clampi(int(v.get("tier", world.hut_tier)), 0, 5)
	var style: Dictionary = v.get("style", save.get("hut_style", {}))
	var floor_k := str(style.get("floor", "own"))
	if floor_k == "own" or not FLOORS.has(floor_k):
		floor_k = ["wood", "wood", "dark", "dark", "wood", "dark"][tier]
	var wall_k := str(style.get("wall", "own"))
	if wall_k == "own" or not Furniture.WALLS.has(wall_k):
		wall_k = ["wall_wood", "wall_wood_light", "wall_paper", "wall_paper_green", "wall_wood_light", "wall_paper"][tier]
	_shell(floor_k, "wall_wood", wall_k)
	# fixed: the bed, the trophy board and a window; the rest is yours to arrange
	_bed(Vector3(-_w * 0.3, 0.0, -_d * 0.5 + 1.2), "quilt_red", v.is_empty())
	if v.is_empty():
		_trophy("back", _w * 0.15)
	_wall("window", "back", _w * 0.38, 0.9)
	var placed: Array = v.get("furniture", save.furniture)
	for item in placed:
		if item is Dictionary:
			place_furniture(item)
	if v.is_empty():
		_things.append({"pos": _to_world(Vector3(-0.9, 0.0, _d * 0.5 - 1.0)), "text": "Space: Arrange your furniture (or press B)",
			"kind": "arrange", "data": 0})
	else:
		_things.append({"pos": _to_world(Vector3(-0.9, 0.0, _d * 0.5 - 1.0)), "text": "Space: Look around",
			"kind": "look", "data": "%s has made it cosy in here." % str(v.get("owner", "Your friend"))})
	_keeper_at = Vector3(0.0, 0.0, 0.0)


## Online: step into someone else's hut (their tier, walls, floor and furniture). You walk
## out where you came in.
func visit_hut(data: Dictionary) -> void:
	if _busy or is_inside():
		return
	var anchor := Node3D.new()
	anchor.name = "VisitAnchor"
	add_child(anchor)
	var here := player.global_position
	anchor.global_position = here - player.facing * 0.6
	var b := {"kind": "hut", "role": "", "name": "%s's Hut" % str(data.get("owner", "A friend")), "town": "",
		"door": here, "node": anchor, "size": Vector3(4.0, 2.6, 3.6), "visit": data}
	enter(b)


func visiting() -> bool:
	return is_inside() and inside.has("visit")


## Your home: your wallpaper and floor, your furniture, and the catalogue by the door.
func _home_room() -> void:
	var v: Dictionary = inside.get("visit", {})
	var h: Dictionary = v if not v.is_empty() else Homes.ensure(save)
	_shell(str(h.get("floor", Homes.DEFAULT_FLOOR)), str(h.get("wall", Homes.DEFAULT_WALL)), str(h.get("wall", Homes.DEFAULT_WALL)))
	_wall("window", "back", -_w * 0.3, 0.9)
	_wall("window", "back", _w * 0.3, 0.9)
	for item in h.get("furniture", []):
		if item is Dictionary:
			place_furniture(item)
	if not v.is_empty():
		_things.append({"pos": _to_world(Vector3(0.0, 0.0, _d * 0.5 - 1.0)), "text": "Space: Look around",
			"kind": "look", "data": "%s's home. Make yourself comfortable (but no moving the furniture)." % str(v.get("owner", "A friend"))})
		_keeper_at = Vector3.ZERO
		return
	_things.append({"pos": _to_world(Vector3(-1.4, 0.0, _d * 0.5 - 1.0)), "text": "Space: Arrange your furniture (or press B)",
		"kind": "arrange", "data": 0})
	_things.append({"pos": _to_world(Vector3(1.4, 0.0, _d * 0.5 - 1.0)), "text": "Space: Browse the Home Catalogue",
		"kind": "catalogue", "data": 0})
	_keeper_at = Vector3.ZERO


## Fixed things in your hut that furniture can't overlap: floor rectangles (room-local,
## x/z) and wall spans ({side, from, to}).
func hut_fixed() -> Dictionary:
	var floor_rects: Array[Rect2] = [
		Rect2(-_w * 0.3 - 0.75, -_d * 0.5, 1.5, 2.4),  # the bed
		Rect2(-DOOR_W * 0.5 - 0.2, _d * 0.5 - 1.5, DOOR_W + 0.4, 1.5),  # the way in
	]
	var walls: Array = [
		{"side": "back", "from": _w * 0.15 - 0.75, "to": _w * 0.15 + 0.75},
		{"side": "back", "from": _w * 0.38 - 0.55, "to": _w * 0.38 + 0.55},
	]
	return {"floor": floor_rects, "walls": walls}


## Build one piece of furniture from the save into the room. Floor pieces sit at x/z
## (room-local) turned rot quarter turns; wall pieces hang on side at along.
func place_furniture(item: Dictionary) -> Node3D:
	var id := str(item.get("id", ""))
	var data: Dictionary = Furniture.data(id)
	if data.is_empty():
		return null
	var tex := Furniture.sprite(id)
	var node := Node3D.new()
	node.name = "Furniture"
	_room.add_child(node)
	_target = node
	var kind := str(data.kind)
	if kind == "wall":
		var side := str(item.get("side", "back"))
		var along := float(item.get("along", 0.0))
		var y := float(data.get("y", 1.2))
		if id == "fireplace" or id == "stone_hearth":
			_fireplace(side, along, id)
		else:
			_wall(tex, side, along, y)
	else:
		var rot := int(item.get("rot", 0))
		node.position = Vector3(float(item.get("x", 0.0)), 0.0, float(item.get("z", 0.0)))
		node.rotation.y = -rot * PI * 0.5
		match id:
			"table":
				_table(Vector3.ZERO)
			"bed":
				_bed(Vector3.ZERO, "quilt_blue", false)
				_things.append({"pos": node.global_position + node.basis * Vector3(0.95, 0.0, 0.2), "text": "Space: Sleep until morning",
					"kind": "bed", "data": 0})
			"barrels":
				_barrels(Vector3(0.0, 0.0, -0.4))
			"tank":
				_tank(Vector3.ZERO, Vector3(1.4, 0.9, 0.8), Color(0.25, 0.6, 0.8), _caught_fish(3))
			"rug_red", "rug_blue", "rug_green", "rug_hide":
				var fp := Furniture.footprint(id, 0)
				_rug(id, Vector3.ZERO, fp)
			"bookshelf":
				_stand(id, Vector3(0.0, 0.0, -0.2), false)
			_:
				if kind == "rug":  # catalogue rugs
					_rug(tex, Vector3.ZERO, Furniture.footprint(id, 0))
				else:
					_stand(tex, Vector3.ZERO, true)
				if str(data.get("base", "")) in ["double_bed", "bunk_bed"]:
					_things.append({"pos": node.global_position + node.basis * Vector3(0.0, 0.0, 0.9), "text": "Space: Sleep until morning",
						"kind": "bed", "data": 0})
	_target = null
	furniture_nodes.append({"item": item, "node": node})
	return node


func _caught_fish(n: int) -> Array:
	var out: Array = []
	var book: Dictionary = save.log
	var ids := book.keys()
	ids.shuffle()
	for id in ids:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and e.cat == "fish":
			out.append(id)
			if out.size() >= n:
				break
	return out


func _aquarium() -> void:
	# Tanks along the back wall, stocked with fish from your own Logbook.
	var caught: Array = []
	var book: Dictionary = save.log
	for id in book:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and e.cat == "fish":
			caught.append(id)
	caught.sort()
	var waters := [Color(0.25, 0.6, 0.8), Color(0.2, 0.55, 0.5), Color(0.3, 0.7, 0.75), Color(0.15, 0.3, 0.6)]
	for i in 4:
		var at := Vector3(-_w * 0.32 + i * _w * 0.24, 0.0, -_d * 0.5 + 0.7)
		_tank(at, Vector3(_w * 0.2, 1.5, 1.0), waters[i], caught.slice(i * 3, i * 3 + 3))


## A glass tank on a stand with fish swimming in it (ids from the catalogue).
func _tank(at: Vector3, size: Vector3, water: Color, fish: Array) -> void:
	_box(at, Vector3(size.x + 0.2, 0.7, size.z + 0.2), "timber")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(water.r, water.g, water.b, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = water
	glass.emission_energy_multiplier = 0.6
	glass.roughness = 0.1
	_vis_box(at + Vector3(0.0, 0.7, 0.0), size, glass)
	_light(at + Vector3(0.0, 0.7 + size.y + 0.1, 0.4), 0.6, 3.0, false, water.lightened(0.3))
	for k in fish.size():
		var tex_path := "res://art/fish2/%s.png" % str(fish[k])
		if not ResourceLoader.exists(tex_path):
			continue
		var s := Sprite3D.new()
		s.texture = load(tex_path)
		s.pixel_size = 1.0 / 90.0
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = false
		_into().add_child(s)
		var y := 0.95 + k * size.y * 0.25
		var from := at + Vector3(-size.x * 0.32, y, size.z * 0.25)
		var to := at + Vector3(size.x * 0.32, y, size.z * 0.25)
		s.position = from
		_swimmers.append({"node": s, "from": from, "to": to, "t": randf() * TAU, "speed": randf_range(0.3, 0.6)})
	var front := _into().global_transform * (at + Vector3(0.0, 0.0, size.z * 0.5 + 0.7))
	_things.append({"pos": front, "text": "Space: Look in the tank", "kind": "tank", "data": 0})


# --- furniture and decor ------------------------------------------------------------

func _to_world(local: Vector3) -> Vector3:
	return _origin + local


## A decor sprite flat against a wall: "back", "left" or "right"; along is the position
## along that wall, y the height of its bottom edge.
func _wall(tex: String, side: String, along: float, y: float) -> void:
	var s := _decor(tex)
	if s == null:
		return
	var h := s.texture.get_height() * PX
	if tex == "fire":
		h = 16.0 * PX
	match side:
		"back":
			s.position = Vector3(along, y + h * 0.5, -_d * 0.5 + 0.08)
		"left":
			s.position = Vector3(-_w * 0.5 + 0.08, y + h * 0.5, along)
			s.rotation.y = PI * 0.5
		"right":
			s.position = Vector3(_w * 0.5 - 0.08, y + h * 0.5, along)
			s.rotation.y = -PI * 0.5
	if tex == "window":
		# daylight (or night) behind the panes
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(0.7, 0.85, 1.0)
		_sky_mats.append(glow)
		var q := QuadMesh.new()
		q.size = Vector2(0.82, 0.82)
		q.material = glow
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = s.position + Vector3(0.0, 0.06, 0.0) - s.basis.z * 0.02
		mi.rotation = s.rotation
		_into().add_child(mi)


## A decor sprite standing on the floor. Against a wall it's flat; free-standing ones
## turn (on the vertical axis) to face the camera.
func _stand(tex: String, at: Vector3, turns := true) -> void:
	var s := _decor(tex)
	if s == null:
		return
	var h := s.texture.get_height() * PX
	s.position = at + Vector3(0.0, h * 0.5, 0.0)
	if turns:
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# a collider so you walk round it
	var w := s.texture.get_width() * PX
	_collider(at + Vector3(0.0, 0.0, 0.0), Vector3(w * 0.8, 1.2, 0.5))


func _on_counter(tex: String, at: Vector3) -> void:
	var s := _decor(tex)
	if s == null:
		return
	s.position = at + Vector3(0.0, s.texture.get_height() * PX * 0.5, 0.15)


func _decor(tex: String) -> Sprite3D:
	var path := "res://art/decor/%s.png" % tex
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = PX
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = true
	_into().add_child(s)
	return s


func _fireplace(side: String, along: float, tex := "fireplace") -> void:
	_wall(tex, side, along, 0.0)
	var f := _decor("fire")
	if f:
		f.hframes = 4
		f.shaded = false
		f.pixel_size = PX * 1.4
		var inward := 0.12
		match side:
			"left":
				f.position = Vector3(-_w * 0.5 + inward, 0.3, along)
				f.rotation.y = PI * 0.5
			"right":
				f.position = Vector3(_w * 0.5 - inward, 0.3, along)
				f.rotation.y = -PI * 0.5
			_:
				f.position = Vector3(along, 0.3, -_d * 0.5 + inward)
		_fires.append(f)
		var lp := f.position + (Vector3(0.8, 0.4, 0.0) if side == "left" else Vector3(-0.8, 0.4, 0.0))
		_light(lp, 1.4, 5.0, false, Color(1.0, 0.55, 0.25))
	_collider(Vector3(-_w * 0.5 + 0.4 if side == "left" else _w * 0.5 - 0.4, 0.0, along), Vector3(0.8, 1.2, 1.8))


func _trophy(side: String, along: float) -> void:
	_wall("trophy_board", side, along, 1.3)
	var best_id := ""
	var best_cm := 0.0
	var book: Dictionary = save.log
	for id in book:
		var cm := float(book[id].get("best", 0.0))
		if cm > best_cm:
			best_cm = cm
			best_id = str(id)
	var at := Vector3(along, 1.3 + 13.0 * PX, -_d * 0.5 + 0.1)
	if side == "left":
		at = Vector3(-_w * 0.5 + 0.1, 1.3 + 13.0 * PX, along)
	if best_id != "" and ResourceLoader.exists("res://art/fish2/%s.png" % best_id):
		var s := Sprite3D.new()
		s.texture = load("res://art/fish2/%s.png" % best_id)
		s.pixel_size = 1.0 / 70.0
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.position = at + (Vector3(0.0, 0.0, 0.03) if side != "left" else Vector3(0.03, 0.0, 0.0))
		if side == "left":
			s.rotation.y = PI * 0.5
		_into().add_child(s)
	var stand := at
	stand.y = 0.0
	stand += Vector3(0.0, 0.0, 1.0) if side != "left" else Vector3(1.0, 0.0, 0.0)
	_things.append({"pos": _to_world(stand), "text": "Space: Look at the trophy", "kind": "trophy", "data": best_id})


func _rug(tex: String, at: Vector3, size: Vector2) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/decor/%s.png" % tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness = 1.0
	var q := PlaneMesh.new()
	q.size = size
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = at + Vector3(0.0, 0.012, 0.0)
	_into().add_child(mi)


func _table(at: Vector3) -> void:
	var wood := _tex("timber", 0.5)
	_box(at + Vector3(0.0, 0.72, 0.0), Vector3(1.4, 0.08, 0.9), "", wood)
	for sx in [-0.6, 0.6]:
		for sz in [-0.36, 0.36]:
			_vis_box(at + Vector3(sx, 0.0, sz), Vector3(0.08, 0.72, 0.08), wood)
	_collider(at, Vector3(1.4, 0.8, 0.9))
	for sx in [-1.0, 1.0]:  # stools
		var st := at + Vector3(sx, 0.0, 0.0)
		_vis_box(st + Vector3(0.0, 0.42, 0.0), Vector3(0.42, 0.06, 0.42), wood)
		_vis_box(st, Vector3(0.08, 0.42, 0.08), wood)
	var mug := _flat(Color(0.85, 0.82, 0.75))
	_vis_box(at + Vector3(0.25, 0.76, 0.1), Vector3(0.1, 0.12, 0.1), mug)


func _bed(at: Vector3, quilt: String, own: bool) -> void:
	var wood := _tex("timber", 0.5)
	_box(at, Vector3(1.3, 0.45, 2.1), "", wood)
	_vis_box(at + Vector3(0.0, 0.0, -1.05), Vector3(1.4, 1.0, 0.1), wood)  # headboard
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/decor/%s.png" % quilt)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var top := PlaneMesh.new()
	top.size = Vector2(1.2, 2.0)
	top.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = top
	mi.position = at + Vector3(0.0, 0.47, 0.0)
	_into().add_child(mi)
	if own:
		_things.append({"pos": _to_world(at + Vector3(0.95, 0.0, 0.2)), "text": "Space: Sleep until morning", "kind": "bed", "data": 0})


func _bed_for_hire(key: String) -> void:
	if key == "tavern":
		return
	_bed(Vector3(_w * 0.36, 0.0, -_d * 0.5 + 1.2), "quilt_blue", false)
	_things.append({"pos": _to_world(Vector3(_w * 0.36 - 0.95, 0.0, -_d * 0.5 + 1.4)), "text": "Space: Rent the bed for the night (20 Shells)",
		"kind": "bed", "data": 20})


func _barrels(at: Vector3) -> void:
	for o in [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.8)]:
		_cyl(at + o + Vector3(0.0, 0.45, 0.0), 0.33, 0.9, "timber")


func _counter(at: Vector3, size: Vector3, tex: String) -> void:
	_box(at, size, tex)
	_vis_box(at + Vector3(0.0, size.y, 0.0), Vector3(size.x + 0.1, 0.06, size.z + 0.1), _tex("planks", 0.5))


# --- low-level helpers ---------------------------------------------------------------

func _light(at: Vector3, energy: float, reach: float, shadow: bool, color := Color(1.0, 0.78, 0.52)) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	_into().add_child(l)


## A solid box standing on the floor at `at` (its base), with a collider.
func _box(at: Vector3, size: Vector3, tex: String, mat: Material = null) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat if mat else _tex(tex, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	_into().add_child(body)


## A box you can see but not bump into (trim, legs, panels).
func _vis_box(at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	_into().add_child(mi)


func _collider(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_into().add_child(body)


func _cyl(at: Vector3, radius: float, height: float, tex: String) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.material = _tex(tex, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	_into().add_child(body)


func _tex(tex_name: String, uv: float) -> StandardMaterial3D:
	var key := "%s@%s" % [tex_name, uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var path := "res://art/tex/%s.png" % tex_name
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv, uv, uv)
	m.roughness = 0.9
	_mats[key] = m
	return m


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _rebuild_sky() -> void:
	_update_sky()


## Windows show the time of day outside.
func _update_sky() -> void:
	if _sky_mats.is_empty():
		return
	var h := float(sea.env.hour)
	var day := clampf(smoothstep(5.0, 7.5, h) - smoothstep(17.5, 19.5, h), 0.0, 1.0)
	var c := Color(0.08, 0.1, 0.22).lerp(Color(0.72, 0.86, 1.0), day)
	if h > 16.5 and h < 19.5:
		c = c.lerp(Color(1.0, 0.62, 0.4), 0.5 * (1.0 - absf(h - 18.0) / 1.5))
	for m in _sky_mats:
		m.albedo_color = c


# --- things to do inside --------------------------------------------------------------

func _sleep(cost: int) -> void:
	var h := float(sea.env.hour)
	if h >= 6.0 and h < 17.0:
		hud.toast("It's the middle of the day. Come back after dusk to sleep.")
		return
	if cost > 0:
		if int(save.shells) < cost:
			hud.toast("A night here costs %d Shells." % cost)
			audio.play("error")
			return
		save.shells = int(save.shells) - cost
		hud.set_shells(save.shells)
	var hours := fmod(24.0 - h + 6.0, 24.0)
	player.can_move = false
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(_skip_night.bind(hours))
	tw.tween_interval(0.8)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(_done)
	tw.tween_callback(hud.toast.bind("You sleep soundly and wake at dawn. Good fishing weather?"))


## From the lamp room you can see the whole bay: it fills in on your map.
func _keeper_stone() -> void:
	audio.play("thud", -8.0)
	if mystery and int(mystery.step()) == 0:
		hud.toast("The stone pulls free. Behind it, rolled tight in oilcloth: a page in the old keeper's hand.")
		mystery.advance(1)
	else:
		hud.toast("Just a loose stone, and the hollow behind it.")


func _climb() -> void:
	if _busy or not is_inside():
		return
	_busy = true
	player.can_move = false
	audio.play("step_wood", -4.0)
	audio.play("step_wood", -6.0, 1.1)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE * 1.5)
	tw.tween_callback(_go_up)
	tw.tween_property(_fade, "color:a", 0.0, FADE * 2.5)
	tw.tween_callback(_done)


## Out onto the gallery round the lamp, high over the harbour.
func _go_up() -> void:
	var b := inside
	_lighthouse = b
	for who in _swapped:
		if world.folk.has(who):
			world.folk[who].node = _swapped[who]
	_swapped.clear()
	_clear_room()
	inside = {}
	on_gallery = true
	var tower: Node3D = b.node
	_tower_collision(tower, false)
	var top := tower.global_position + Vector3(0.0, 9.3, 0.0)
	_build_gallery(top)
	var door: Vector3 = b.door
	var out := Vector3(door.x - top.x, 0.0, door.z - top.z).normalized()
	player.global_position = top + out * 1.6 + Vector3(0.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	player.face(out)
	world.set_indoor(false)
	day_night.indoor = false
	cam.indoor = false
	cam.set_yaw(_out_yaw)
	cam.snap()
	audio.play("whoosh", -8.0)
	if map_screen:
		map_screen.reveal(top.x, top.z, 300.0)
		map_screen.mark(top)
	hud.show_area("The lamp gallery", "", false)
	if not (mystery and mystery.restore_light()):
		hud.toast("The whole bay spreads out below, and your map fills in ({map}). Walk round the lamp, and zoom out for the view.")


func _descend() -> void:
	if _busy or not on_gallery:
		return
	_busy = true
	player.can_move = false
	audio.play("step_wood", -4.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE * 1.5)
	tw.tween_callback(_go_down)
	tw.tween_property(_fade, "color:a", 0.0, FADE * 2.0)
	tw.tween_callback(_done)


## Back down the stair into the lighthouse.
func _go_down() -> void:
	on_gallery = false
	if _gallery:
		_gallery.queue_free()
		_gallery = null
	var b := _lighthouse
	_lighthouse = {}
	if b.is_empty():
		return
	_tower_collision(b.node, true)
	_go_in(b)
	if _stair_top != Vector3.INF:
		player.global_position = _origin + Vector3(_stair_top.x - 3.2, 0.05, _stair_top.z + 1.1)
	_settle = 1.0


func _tower_collision(tower: Node, on: bool) -> void:
	for c in tower.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not on


## The walkway round the lamp: a stone floor, a railing all round, and the lamp house.
func _build_gallery(top: Vector3) -> void:
	_gallery = Node3D.new()
	_gallery.name = "LampGallery"
	add_child(_gallery)
	_gallery.global_position = top
	var body := StaticBody3D.new()
	_gallery.add_child(body)
	var floor_col := CollisionShape3D.new()
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = 2.3
	floor_shape.height = 0.3
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.15, 0.0)
	body.add_child(floor_col)
	var lamp_col := CollisionShape3D.new()
	var lamp_shape := CylinderShape3D.new()
	lamp_shape.radius = 1.0
	lamp_shape.height = 3.0
	lamp_col.shape = lamp_shape
	lamp_col.position = Vector3(0.0, 1.5, 0.0)
	body.add_child(lamp_col)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.3
	disc.bottom_radius = 2.1
	disc.height = 0.25
	floor_mesh.mesh = disc
	floor_mesh.material_override = _tex("wall_stone", 0.5)
	floor_mesh.position = Vector3(0.0, -0.13, 0.0)
	_gallery.add_child(floor_mesh)
	var iron := _flat(Color(0.18, 0.17, 0.2))
	var posts := 20
	for i in posts:
		var a := TAU * i / posts
		var p := Vector3(cos(a) * 2.2, 0.0, sin(a) * 2.2)
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.035
		pm.bottom_radius = 0.035
		pm.height = 1.0
		post.mesh = pm
		post.material_override = iron
		post.position = p + Vector3(0.0, 0.5, 0.0)
		_gallery.add_child(post)
		var rc := CollisionShape3D.new()
		var rs := BoxShape3D.new()
		rs.size = Vector3(0.12, 1.6, 2.2 * TAU / posts + 0.1)
		rc.shape = rs
		rc.position = p + Vector3(0.0, 0.8, 0.0)
		rc.rotation.y = -a
		body.add_child(rc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.16
	torus.outer_radius = 2.24
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = iron
	ring.position = Vector3(0.0, 1.0, 0.0)
	_gallery.add_child(ring)


func _skip_night(hours: float) -> void:
	sea.skip_hours(hours)
	save.clock_offset = sea.offset
	SaveGame.write(save)


func _read_board() -> void:
	audio.play("pin", -6.0)
	var lines: Array[String] = []
	var permits: Dictionary = world.permits
	if not permits.has("bridge"):
		lines.append("NOTICE: The estuary bridge is out. Tess the carpenter is gathering timber to mend it.")
	if not permits.has("permit_ranger"):
		lines.append("NOTICE: Highland trails to Mirrorlake closed. Permits from Ranger Hollis, Willowford.")
	if not permits.has("permit_ember"):
		lines.append("NOTICE: Ember Isle is off limits. Entry by Harbourmaster's permit only.")
	lines.append("FOR SALE: Boats of every size at the Boatyard. Ask for Bosun Pell.")
	for l in lines:
		hud.toast(l)


func _look_tank() -> void:
	var book: Dictionary = save.log
	var fish := 0
	for id in book:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and e.cat == "fish":
			fish += 1
	audio.play("plop", -6.0)
	if fish == 0:
		hud.toast("The tanks are empty. Dr. Finch hopes you'll catch something to show.")
	else:
		hud.toast("%d kinds of fish you've caught swim in the tanks. Dr. Finch wants one of everything." % fish)


func _look_trophy() -> void:
	var book: Dictionary = save.log
	var best_id := ""
	var best_cm := 0.0
	for id in book:
		var cm := float(book[id].get("best", 0.0))
		if cm > best_cm:
			best_cm = cm
			best_id = str(id)
	if best_id == "":
		hud.toast("An empty trophy board, waiting for your first big catch.")
		return
	var e: Dictionary = sea.by_id.get(best_id, {})
	hud.toast("Your biggest catch: a %s of %d cm." % [str(e.get("n", best_id)), int(best_cm)])
