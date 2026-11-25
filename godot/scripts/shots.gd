extends Node
## Screenshots of the new things for checking by eye (run with a display:
## godot --path godot --rendering-method gl_compatibility -- --shots=/tmp/shots).
## Grows the garden, stands by the yard, the quarry and some animals, opens the land menus,
## visits a hut and fakes another player in town, saving a PNG of each.

const LandData := preload("res://scripts/land_data.gd")

var main: Node
var out := "user://shots"
var _steps: Array = []
var _i := 0
var _wait := 0


func setup(m: Node, dir: String) -> void:
	main = m
	if dir != "":
		out = dir
	DirAccess.make_dir_recursive_absolute(out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dir.ends_with("_quick"):
		_steps = [[_noop, 60], [_into_game, 30], [_yard, 60], [_shot.bind("yard"), 5], [_online, 60], [_shot.bind("online"), 5], [_quit, 5]]
		return
	_steps = [
		[_noop, 60], [_into_game, 30], [_garden, 90], [_shot.bind("garden"), 5],
		[_yard, 60], [_shot.bind("yard"), 5],
		[_quarry, 90], [_shot.bind("quarry"), 5],
		[_animals, 120], [_shot.bind("animals"), 5],
		[_aim, 20], [_shot.bind("aim"), 5], [_end_aim, 10],
		[_bench_menu, 20], [_shot.bind("bench_menu"), 5], [_close_menu, 10],
		[_shop_menu, 20], [_shot.bind("shop_menu"), 5], [_close_menu, 10],
		[_visit, 60], [_shot.bind("visit_hut"), 5], [_leave, 60],
		[_online, 60], [_shot.bind("online"), 5],
		[_quit, 5],
	]


func _process(_d: float) -> void:
	if _wait > 0:
		_wait -= 1
		return
	if _i >= _steps.size():
		return
	var s: Array = _steps[_i]
	_i += 1
	(s[0] as Callable).call()
	_wait = int(s[1])


func _noop() -> void:
	pass


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _into_game() -> void:
	main.opening.skip()
	main.menus._start()
	if bool(main.wardrobe.is_open):
		main.wardrobe._finish()
	_steps.insert(_i, [_skip_talk, 10])


func _skip_talk() -> void:
	for i in 60:
		if not bool(main.dialogue.is_open):
			break
		main.dialogue._finish(0)
	main.save.shells = 5000


func _stand(at: Vector3, face: Vector3) -> void:
	main.player.global_position = at
	main.player.face(face)
	main.cam.snap()


func _garden() -> void:
	var land: Node = main.land
	var crops := ["turnip", "carrot", "wheat", "potato", "strawberry", "pumpkin", "turnip", "carrot", "wheat", "strawberry", "pumpkin", "potato"]
	main.save.land["bed_count"] = 12
	var beds: Array = main.save.land.beds
	for i in 12:
		var info: Dictionary = LandData.CROPS[crops[i]]
		var k: float = [0.0, 0.2, 0.6, 1.2][i % 4]
		beds[i] = {"s": "crop", "crop": crops[i], "grow": float(info.grow) * k, "wet": float(main.sea.now()) + (500.0 if i % 3 else 0.0)}
	beds[11] = {"s": "tilled"}
	land._refresh_garden()
	_stand(Vector3(419.0, 1.3, 693.0), Vector3(0.0, 0.0, -1.0))


func _yard() -> void:
	var hour := float(main.sea.env.get("hour", 12.0))
	main.sea.skip_hours(fposmod(12.0 - hour, 24.0))
	main.land.set_flag("bench_fixed")
	main.land._bench.modulate = Color.WHITE
	main.land._bench.rotation.z = 0.0
	main.cam.set_yaw(0.0)
	_stand(Vector3(427.0, 1.3, 691.5), Vector3(0.0, 0.0, -1.0))


func _quarry() -> void:
	for rec in main.land._rocks:
		if str(rec.quarry) == "willow":
			var p: Vector3 = rec.pos
			_stand(p + Vector3(0.0, 0.5, 5.0), Vector3(0.0, 0.0, -1.0))
			return


func _animals() -> void:
	var land: Node = main.land
	_stand(Vector3(330.0, 6.0, 300.0), Vector3(0.0, 0.0, -1.0))
	var p: Vector3 = main.player.global_position
	land._spawn_animal("rabbit", p.x - 2.0, p.z - 5.0)
	land._spawn_animal("deer", p.x + 2.5, p.z - 7.0)
	land._spawn_animal("boar", p.x - 4.0, p.z - 8.0)
	land._spawn_animal("pheasant", p.x + 4.0, p.z - 4.5)


func _aim() -> void:
	var land: Node = main.land
	land.set_tool("bow", 1)
	land.add_item("arrows", 10)
	for a in land._animals:
		if str(a.kind) == "deer":
			land._start_aim(a)
			return


func _end_aim() -> void:
	main.land._end_aim()


func _bench_menu() -> void:
	main.land.add_item("mat:wood", 30)
	main.land.add_item("stone", 12)
	main.land.add_item("wheat", 8)
	main.land_menu.open_craft("bench")
	main.land_menu._show_tab(3)


func _shop_menu() -> void:
	main.land.add_item("turnip", 6)
	main.land.add_item("berries", 9)
	main.land.add_item("pumpkin", 1)
	main.land_menu.open_shop("bramble", "Farmer Bramble")
	main.land_menu._show_tab(1)


func _close_menu() -> void:
	if bool(main.land_menu.is_open):
		main.land_menu.close()
	get_tree().paused = false


func _visit() -> void:
	_stand(Vector3(421.0, 1.3, 684.0), Vector3(0.0, 0.0, 1.0))
	main.interiors.visit_hut({"owner": "Robin", "tier": 2, "style": {"wall": "wall_paper_blue", "floor": "tile"},
		"furniture": [{"id": "rocking_chair", "x": 1.6, "z": -0.4, "rot": 0}, {"id": "antler_mount", "side": "back", "along": -1.2},
		{"id": "rug_hide", "x": 0.2, "z": 0.6, "rot": 0}, {"id": "stone_hearth", "side": "left", "along": 0.0},
		{"id": "planter", "x": -1.0, "z": -2.0, "rot": 0}, {"id": "crystal_lamp", "x": 3.0, "z": -2.5, "rot": 0},
		{"id": "pumpkin_lantern", "x": 2.4, "z": 1.0, "rot": 0}, {"id": "copper_pots", "side": "right", "along": -1.0},
		{"id": "ore_shelf", "x": 0.6, "z": -3.3, "rot": 0}, {"id": "scarecrow", "x": -3.2, "z": 1.5, "rot": 0}]})


func _leave() -> void:
	main.interiors.leave()


func _online() -> void:
	var o: Node = main.online
	o.state = "online"
	o.my_name = "You"
	var p: Vector3 = main.player.global_position
	o._add({"id": 7, "name": "Robin", "look": {"skin": "brown", "hair": "#c84a6a", "style": "bob", "hat": "straw", "shirt": "#7ab0e8"},
		"x": p.x + 1.5, "y": p.y, "z": p.z - 1.0})
	o._on_message({"t": "chat", "id": 7, "name": "Robin", "text": "Come and see my new rocking chair!"})
	o._say_system("Robin arrived in Gullhaven.")
	main.player.face(Vector3(0.0, 0.0, -1.0))


func _quit() -> void:
	get_tree().quit()
