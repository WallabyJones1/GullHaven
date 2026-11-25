extends Node
## A quick tour of the whole game with no one at the controls, for checking a build on
## GitHub's computers (run with: godot --headless --path godot -- --smoke).
## It skips the opening, uses the main menu, makes a fisher, plays the story's opening
## lines, lands fish of every kind, levels up, opens every menu and shop, uses every
## piece of kit, dives, fights on the reel bar, and runs the story to the end. Each step
## prints "SMOKE <step>"; Godot prints any script error it hits along the way. It never
## writes your save (the run uses its own user folder on the build machine).

const Character := preload("res://scripts/character.gd")
const Sea := preload("res://scripts/sea.gd")
const LandData := preload("res://scripts/land_data.gd")

var main: Node
var _steps: Array = []
var _i := 0
var _wait := 0


var _quick := false  # the short browser check: into the game, look around, stop


func setup(m: Node, quick := false) -> void:
	main = m
	_quick = quick
	process_mode = Node.PROCESS_MODE_ALWAYS
	_steps = [
		["let the opening play", _noop, 90],
		["skip the opening", _skip_opening, 20],
		["main menu pages", _menu_pages, 10],
		["back to the menu", _show_title, 10],
		["the Harbour economy switch", _harbour_switch, 5],
		["start a new game", _start, 15],
		["make a fisher", _make_fisher, 10],
		["finish the creator", _finish_creator, 10],
		["read Gran's letter", _skip_talk, 5],
		["talk to Marlo", _talk_marlo, 5],
		["finish the talk", _skip_talk, 5],
		["land one of everything", _land_things, 10],
		["level up", _level_up, 10],
		["skip the notes", _skip_talk, 5],
		["the game menu", _game_menu, 10],
		["the bag", _open_bag, 10],
		["close the bag", _close_screen.bind("bag"), 10],
		["the logbook", _open_screen.bind("logbook"), 10],
		["close the logbook", _close_screen.bind("logbook"), 10],
		["the journal", _open_screen.bind("journal"), 10],
		["close the journal", _close_screen.bind("journal"), 10],
		["the map", _open_screen.bind("map_screen"), 10],
		["close the map", _close_screen.bind("map_screen"), 10],
		["the Harbour Exchange (test build)", _harbour, 10],
		["leave the game menu", _close_pause, 10],
		["go home (a plot, test build)", _home_go, 60],
		["decorate it from the catalogue", _home_decorate, 20],
		["check the home", _home_check, 5],
		["leave home", _home_leave, 60],
		["check we're back outside", _home_out, 5],
		["Hale's Tackle, every tab", _shop, 10],
		["close the shop", _close_shop, 10],
		["Threads & Tides", _outfitter, 10],
		["leave Threads & Tides", _leave_outfitter, 10],
		["drop a crab pot", _drop_pot, 10],
		["check it early", _check_pot, 5],
		["skip that", _skip_talk, 5],
		["haul it up", _haul_pot, 10],
		["back to fishing", _idle, 5],
		["throw the net", _net, 10],
		["back to fishing", _idle, 5],
		["a trolling strike on the reel bar", _troll, 120],
		["land it", _land_fight, 10],
		["back to fishing", _idle, 5],
		["dive with the speargun", _dive, 90],
		["surface", _surface, 10],
		["back to fishing", _idle, 5],
		["dress up a dozen fishers", _looks, 5],
		["dialogue with choices", _choices, 5],
		["answer", _skip_talk, 5],
		["run the story to the end", _story_to_end, 10],
		["skip the story notes", _skip_talk, 5],
		["summaries", _summaries, 5],
		["Harbour Life: meet Farmer Bramble", _land_meet, 5],
		["finish the talk", _skip_talk, 5],
		["dig, plant and water a bed", _land_garden, 5],
		["grow and harvest", _land_harvest, 5],
		["chop, forage and mine", _land_gather, 10],
		["fix Gran's workbench and craft", _land_craft, 10],
		["close the bench", _land_close_menu, 5],
		["cook at the pot", _land_cook, 10],
		["close the pot", _land_close_menu, 5],
		["Bramble's stall", _land_shop, 10],
		["close the stall", _land_close_menu, 5],
		["Tess decorates the hut", _decorate, 10],
		["close the carpenter", _close_trade, 5],
		["spot a rabbit", _land_hunt, 10],
		["loose an arrow", _land_shoot, 10],
		["visit a friend's hut", _visit_hut, 40],
		["look round it", _visit_check, 5],
		["leave the friend's hut", _leave_visit, 40],
		["claim a plot on Driftwood Lane", _plot_claim, 10],
		["finish the talk", _skip_talk, 5],
		["do up the house and buy for the garden", _plot_build, 10],
		["put a gnome in the garden", _plot_place, 10],
		["check the garden", _plot_place_check, 10],
		["into your own home", _plot_enter, 40],
		["leave your home", _plot_leave, 40],
		["sail the Corsair Sloop into open water", _sea_out, 30],
		["a sea serpent surfaces", _monster_up, 30],
		["harpoon it", _monster_fight, 10],
		["check it fled", _monster_check, 60],
		["Pip's treasure map", _treasure_pip, 5],
		["take the map", _skip_talk, 10],
		["dig up the treasure", _treasure_dig, 10],
		["check the chest", _treasure_check, 10],
		["Harbour Life so far", _land_check, 5],
		["zoom with the wheel, a trackpad and keys", _zoom, 30],
		["check the zoom", _zoom_check, 5],
		["into the lighthouse", _into_lighthouse, 45],
		["walk up the stairs", _stairs, 240],
		["check we reached the gallery", _stairs_check, 60],
		["walk round the gallery", _gallery_walk, 120],
		["check we're still up there", _gallery_check, 5],
		["climb back down", _climb_down, 50],
		["check we're back inside", _down_check, 5],
		["leave the lighthouse", _leave, 50],
		["build a low step and a tall crate", _build_steps, 5],
		["walk up the step", _walk_step, 30],
		["check we're on the step", _step_check, 5],
		["walk into the crate", _walk_crate, 90],
		["check we didn't climb it", _crate_check, 5],
		["go to the estuary bridge, mended", _bridge_start, 20],
		["walk across it", _bridge_walk, 780],
		["check we got over", _bridge_check, 5],
		["sail a rowboat", _boat, 20],
		["steer it", _steer, 300],
		["check it moved", _steer_check, 5],
		["fall in the water", _fall_in, 30],
		["swim back to shore", _swim, 600],
		["check we climbed out", _swim_check, 5],
		["plan a walk onto every dock", _plan_docks, 2],
		["plan a tour of every building", _plan_tour, 5],
		["watch the opening again", _replay, 60],
		["skip it", _skip_opening, 10],
		["start again", _start, 10],
	]


func _process(_delta: float) -> void:
	if _i == 0 and not _quick:
		for a in OS.get_cmdline_user_args():
			if str(a).begins_with("--online="):
				var at := 0
				for k in _steps.size():
					if str(_steps[k][0]) == "Harbour Life so far":
						at = k + 1
				_steps.insert(at, ["join the shared town", _online_join, 120])
				_steps.insert(at + 1, ["see who's here, chat, visit", _online_check, 90])
				_steps.insert(at + 2, ["check the visit", _online_visit_check, 40])
				break
	if _wait > 0:
		_wait -= 1
		return
	if _quick and _i == 0 and _steps.size() > 9:
		# opening, menus, a new game, the fisher creator and Gran's letter; then look about
		_steps = _steps.slice(0, 8)
		_steps.append(["look around the harbour", _look_around, 360])
		_steps.append(["how it ran", _look_report, 5])
	if _i >= _steps.size():
		print("SMOKE DONE, %d checks failed" % _fails)
		set_process(false)
		if not _quick:
			get_tree().quit()
		return
	var s: Array = _steps[_i]
	_i += 1
	print("SMOKE ", str(s[0]))
	(s[1] as Callable).call()
	_wait = int(s[2])


func _look_around() -> void:
	_check(main.player.can_move, "standing in the harbour, free to move")
	Input.action_press("rotate_right", 0.4)


func _look_report() -> void:
	Input.action_release("rotate_right")
	print("  renderer %s, %s, %.0f fps, %d draw calls" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func _noop() -> void:
	pass


# --- Harbour Life and the shared town ---------------------------------------------------------

func _land_meet() -> void:
	var b: Dictionary = main.harbour.folk.get("Farmer Bramble", {})
	_check(not b.is_empty(), "Farmer Bramble is in the world")
	main.player.global_position = Vector3(423.5, 1.3, 690.0)
	main.land_story.on_talk("Farmer Bramble")


func _land_garden() -> void:
	var land: Node = main.land
	_check(int(land.tool_tier("hoe")) > 0 and int(land.tool_tier("can")) > 0, "Bramble gave us Gran's hoe and watering can")
	land.use({"kind": "bed", "i": 0})
	land._planted(0, 0, ["seed_turnip"])
	land.use({"kind": "bed", "i": 0})
	var bed: Dictionary = main.save.land.beds[0]
	_check(str(bed.s) == "crop" and float(bed.wet) > float(main.sea.now()), "a bed dug, planted with turnips and watered")
	_check(int(main.save.land_story.ch) == 0 and int(main.save.land_story.step) >= 4, "the Harbour Life story moved on (step %d)" % int(main.save.land_story.step))


func _land_harvest() -> void:
	var land: Node = main.land
	var bed: Dictionary = main.save.land.beds[0]
	bed["grow"] = 99999.0
	land._refresh_garden()
	land.use({"kind": "bed", "i": 0})
	_check(int(land.count("turnip")) >= 2, "harvested turnips (%d)" % int(land.count("turnip")))


func _land_gather() -> void:
	var land: Node = main.land
	land.set_tool("axe", 1)
	land.set_tool("pick", 1)
	var wood := int(land.count("mat:wood"))
	for what in ["tree", "bush", "fern", "flowers", "stones", "boulder"]:
		land._use_veg({"what": what, "plant": "oak0", "key": "smoke:" + what, "at": Vector3(411.0, 1.2, 675.0)})
	_check(int(land.count("mat:wood")) > wood and int(land.count("stone")) > 0 and int(land.count("berries")) > 0, "chopped wood, picked berries, gathered stone")
	var per := {}
	for rec in land._rocks:
		per[str(rec.quarry)] = int(per.get(str(rec.quarry), 0)) + 1
	print("  rocks per quarry: ", per)
	_check(land._rocks.size() >= 20, "%d rocks to mine round the coast" % land._rocks.size())
	for rec in land._rocks:
		if str(rec.kind) in ["stone", "copper", "coal"] and (rec.node as Node3D).visible:
			var at: Vector3 = rec.pos
			main.player.global_position = at + Vector3(1.2, 0.3, 0.0)
			var it: Dictionary = land._find_near(main.player.global_position, Vector3(-1.0, 0.0, 0.0))
			_check(str(it.get("kind", "")) == "rock", "standing at a %s rock, it's the thing to use" % str(rec.kind))
			land._mine(rec)
			_check(not (rec.node as Node3D).visible, "mined it; rubble until tomorrow")
			break
	# the trees and boulders of the world are found by facing them
	main.player.global_position = Vector3(411.0, 1.3, 676.2)
	var t: Dictionary = land._veg_near(main.player.global_position, Vector3(0.0, 0.0, -1.0))
	_check(str(t.get("kind", "")) == "veg", "facing a tree by the hut, there's something to gather (%s)" % str(t.get("what", "nothing")))


func _land_craft() -> void:
	var land: Node = main.land
	land.add_item("mat:wood", 20)
	land.add_item("stone", 10)
	land._use_bench()
	_check(bool(land.flag("bench_fixed")), "fixed Gran's workbench")
	land.add_item("copper_bar", 3)
	land.add_item("hide", 2)
	land.add_xp("crafting", 60)
	main.land_menu.open_craft("bench")
	for t in (main.land_menu._tabs_list as Array).size():
		main.land_menu._show_tab(t)
	var recipes: Dictionary = {}
	for r: Dictionary in LandData.RECIPES:
		recipes[str(r.id)] = r
	main.land_menu._make(recipes["axe_copper"], 0)
	main.land_menu._make(recipes["chair"], 0)
	main.land_menu._make(recipes["arrows"], 0)
	_check(int(land.tool_tier("axe")) >= 2, "made a copper axe")
	_check(int((main.save.furniture_inv as Dictionary).get("chair", 0)) > 0, "made a chair for the hut")


func _land_close_menu() -> void:
	if bool(main.land_menu.is_open):
		main.land_menu.close()
	get_tree().paused = false


func _land_cook() -> void:
	var land: Node = main.land
	land.add_item("herbs", 2)
	land.add_item("turnip", 2)
	main.land_menu.open_craft("pot")
	main.land_menu._show_tab(0)
	for r: Dictionary in LandData.RECIPES:
		if str(r.id) == "veg_stew":
			main.land_menu._make(r, 0)
	_check(int(land.count("veg_stew")) > 0, "cooked a vegetable stew")


func _land_shop() -> void:
	var land: Node = main.land
	main.land_menu.open_shop("bramble", "Farmer Bramble")
	for t in (main.land_menu._tabs_list as Array).size():
		main.land_menu._show_tab(t)
	var shells := int(main.save.shells)
	main.land_menu._buy_item("seed_carrot", 14, 1)
	main.land_menu._sell("berries", true)
	_check(int(land.count("seed_carrot")) > 0 and int(land.count("berries")) == 0, "bought carrot seeds and sold the berries")
	var beds := int(land.bed_count())
	main.land_menu._buy_bed()
	_check(int(land.bed_count()) == mini(beds + 1, 12), "Bramble dug another garden bed")
	print("  shells %d -> %d" % [shells, int(main.save.shells)])


func _decorate() -> void:
	main.trade.open("Tess", "Carpenter", "carpenter")
	for t in (main.trade.TABS["carpenter"] as Array).size():
		main.trade._show_tab(t)
	main.trade._set_style("wall", "wall_stone")
	main.trade._set_style("floor", "tile")
	_check(str(main.save.hut_style.wall) == "wall_stone" and str(main.save.hut_style.floor) == "tile", "Tess put up stone walls and a tiled floor")


func _close_trade() -> void:
	if bool(main.trade.is_open):
		main.trade.close()
	get_tree().paused = false


func _land_hunt() -> void:
	var land: Node = main.land
	land.set_tool("bow", 1)
	land.add_item("arrows", 5)
	main.player.global_position = Vector3(330.0, 6.0, 300.0)
	var p: Vector3 = main.player.global_position
	land._spawn_animal("rabbit", p.x, p.z - 6.0)
	var a: Dictionary = land._animals.back()
	main.player.face(Vector3(0.0, 0.0, -1.0))
	var seen: Dictionary = land._animal_in_sight(main.player.global_position, Vector3(0.0, 0.0, -1.0))
	_check(str(seen.get("kind", "")) == "animal", "a rabbit in sight, ready to aim at")
	land._start_aim(a)
	_check(bool(land._aim_layer.visible) and bool(main.hud.modal), "drew the bow: the aim bar is up")


func _land_shoot() -> void:
	var land: Node = main.land
	var meat := int(land.count("meat"))
	if not (land._aim as Dictionary).is_empty():
		var a: Dictionary = land._aim.a
		land._bagged(a)
		land._end_aim()
	_check(int(land.count("meat")) > meat and not bool(main.hud.modal), "got the rabbit; the bow's lowered")


func _visit_hut() -> void:
	main.player.global_position = Vector3(421.0, 1.3, 682.0)
	main.interiors.visit_hut({"owner": "Robin", "tier": 2, "style": {"wall": "wall_paper_blue", "floor": "stone"},
		"furniture": [{"id": "rocking_chair", "x": 1.0, "z": 0.0, "rot": 0}, {"id": "antler_mount", "side": "back", "along": -1.0},
		{"id": "rug_hide", "x": 0.0, "z": 1.0, "rot": 0}, {"id": "stone_hearth", "side": "left", "along": 0.0}]})


func _visit_check() -> void:
	_check(bool(main.interiors.visiting()) and not bool(main.interiors.in_hut()), "inside Robin's hut, as a visitor (can't rearrange it)")
	_check(int((main.interiors.furniture_nodes as Array).size()) == 4, "Robin's furniture is all there")


func _leave_visit() -> void:
	main.interiors.leave()


var _plot_n := 0


func _plot_claim() -> void:
	var pl: Node = main.plots
	_check(int(pl.my_slot()) < 0, "no plot yet")
	var sign: Vector3 = pl._signs.get(0, Vector3.INF)
	_check(sign != Vector3.INF, "plot 1 has a for-sale sign")
	main.player.global_position = sign + Vector3(0.0, 0.3, 1.2)
	var it: Dictionary = pl.near(main.player.global_position, Vector3.FORWARD)
	_check(str(it.get("kind", "")) == "claim", "standing at the sign offers the plot (%s)" % str(it.get("text", "nothing")))
	pl._claim(0)
	_check(int(pl.my_slot()) == 0, "plot 1 is ours")


func _plot_build() -> void:
	var pl: Node = main.plots
	main.save.shells = int(main.save.shells) + 20000
	main.land.add_item("mat:wood", 40)
	main.land.add_item("stone", 30)
	pl._set_house("wall", "stone")
	pl._set_house("tint", "#b8d8f0")
	pl._set_fence("hedge")
	pl._upgrade(1)
	_check(int(main.save.plot.house.size) == 1, "upgraded to a family house")
	pl._buy("gnome")
	pl._buy("veg_patch")
	_check(int(main.save.plot.inv.get("gnome", 0)) == 1, "bought a garden gnome")
	pl.close_menu()
	_plot_n = (main.save.plot.items as Array).size()


func _plot_place() -> void:
	var r: Rect2 = main.plots.slot_rect(0)
	main.player.global_position = Vector3(r.position.x + 2.0, float(main.harbour.height_at(r.position.x + 2.0, r.position.y + 8.4)) + 0.3, r.position.y + 8.4)
	main.player.facing = Vector3(0.0, 0.0, 1.0)
	main.plots.start_placing("gnome")
	var ev := InputEventAction.new()
	ev.action = "action"
	ev.pressed = true
	Input.parse_input_event(ev)


func _plot_place_check() -> void:
	var ev := InputEventAction.new()
	ev.action = "action"
	ev.pressed = false
	Input.parse_input_event(ev)
	if main.plots._placing != "":
		main.plots._stop_placing()
	_check((main.save.plot.items as Array).size() == _plot_n + 1, "the gnome's in the garden (%d things)" % (main.save.plot.items as Array).size())
	var share: Dictionary = main.plots.share_data()
	_check(int(share.slot) == 0 and str(share.house.wall) == "stone" and share.has("home"), "the plot's ready to share with the town")


func _plot_enter() -> void:
	main.plots._enter(0)


func _plot_leave() -> void:
	_check(bool(main.interiors.is_inside()), "inside our own home on Driftwood Lane")
	main.interiors.leave()


func _sea_out() -> void:
	_check(not bool(main.interiors.is_inside()), "back out on the lane")
	var w: Node3D = main.harbour
	var at := Vector3.INF
	for r in range(40, 400, 12):
		for k in 16:
			var a := k * TAU / 16.0
			var x := 566.0 + cos(a) * r
			var z := 826.0 + sin(a) * r
			if at == Vector3.INF and w.is_water(x, z) and float(w.water_depth(x, z)) > 6.0:
				var ok := true
				for j in 8:
					var b := j * TAU / 8.0
					if not w.is_water(x + cos(b) * 34.0, z + sin(b) * 34.0):
						ok = false
				if ok:
					at = Vector3(x, 0.0, z)
	_check(at != Vector3.INF, "found open water")
	if at == Vector3.INF:
		return
	(main.save.boats as Array).append("sloop")
	main.save.boat = "sloop"
	main.boats.spawn(at, 0.0)
	main.boats.board()
	_check(bool(main.boats.aboard) and str(main.boats.info.get("n", "")) == "Corsair Sloop", "aboard the Corsair Sloop")


func _monster_up() -> void:
	_check(bool(main.monsters.force("serpent")), "a sea serpent surfaced")


func _monster_fight() -> void:
	var m: Node = main.monsters
	_check(bool(m.active()), "the serpent is still about")
	if not bool(m.active()):
		return
	var p: Vector3 = main.player.global_position
	var mp: Vector3 = m._m.pos
	var away := Vector3(mp.x - p.x, 0.0, mp.z - p.z).normalized()
	m._m.pos = p + away * 14.0
	m._m.up = 1.0
	m._m.dive = 8.0
	main.land.add_item("harpoon", 12)
	var it: Dictionary = m.near(p, Vector3.FORWARD)
	_check(str(it.get("kind", "")) == "harpoon", "close enough to throw (%s)" % str(it.get("text", "nothing")))
	var tries := 0
	while m.active() and not bool(m._m.gone) and tries < 10:
		m.use({})
		m._throw(true)
		tries += 1
	_mark_f = float(main.land.count("harpoon"))


func _monster_check() -> void:
	_check(int(main.save.monsters.get("serpent", 0)) == 1, "drove off the serpent")
	_check(int(main.land.count("serpent_scale")) >= 1, "it left serpent scales")
	_check(not bool(main.monsters.active()), "it's gone back to the deep")
	_check((main.treasure.maps() as Array).size() >= 1, "and a treasure map washed up")
	main.boats.aboard = false
	main.player.riding = false
	main.player.can_move = true
	main.save.boat = "row"
	main.boats.spawn_at_dock(Vector3(436.0, 0.0, 566.0))
	main.player.global_position = Vector3(438.0, float(main.harbour.height_at(438.0, 700.0)) + 0.5, 700.0)


func _treasure_pip() -> void:
	_plot_n = (main.treasure.maps() as Array).size()
	_check(bool(main.treasure._on_talk("Pip")), "Pip has today's map")
	_check(not bool(main.treasure._on_talk("Pip")), "only one a day")


func _treasure_dig() -> void:
	var maps: Array = main.treasure.maps()
	_check(maps.size() == _plot_n + 1, "Pip's map is ours (%d maps)" % maps.size())
	_check((main.map_screen.treasure_pins as Array).size() == maps.size(), "every map is pinned on the world map")
	var mp: Dictionary = maps[maps.size() - 1]
	var again: Dictionary = main.treasure.give_map("a test", int(main.treasure._today()) * 7907 + 31, true)
	_check(Vector2(float(again.x), float(again.z)).distance_to(Vector2(float(mp.x), float(mp.z))) < 0.01, "the daily map is the same for everyone")
	maps.erase(again)
	main.treasure._refresh_pins()
	main.player.global_position = Vector3(float(mp.x), float(main.harbour.height_at(float(mp.x), float(mp.z))) + 0.4, float(mp.z))
	var it: Dictionary = main.treasure.near(main.player.global_position, Vector3.FORWARD)
	_check(str(it.get("kind", "")) == "dig", "standing on the X (%s, %s)" % [str(mp.where), str(it.get("text", "nothing"))])
	_mark_f = float(main.save.shells)
	if not it.is_empty():
		main.treasure.use(it)


func _treasure_check() -> void:
	_check(int(main.save.treasure.dug) == 1, "dug up a chest")
	_check(float(main.save.shells) > _mark_f, "full of Shells")
	_check(str(main.hud.treasure_label.text).begins_with("Treasure map") or (main.treasure.maps() as Array).is_empty(), "the corner shows the next map")


func _land_check() -> void:
	_check(not bool(main.interiors.is_inside()), "back outside after the visit")
	print("  ", str(main.land.skills_text()).replace("\n", "  "))
	print("  ", str(main.land_story.summary()), "   notes ", int(main.land.notes_count()))
	_check(str(main.land.bag_text()).length() > 40, "the bag lists what we've gathered")


func _online_join() -> void:
	var url := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--online="):
			url = str(a).substr(9)
	main.online.connect_to(url, "Smoke")


func _online_check() -> void:
	var o: Node = main.online
	_check(bool(o.is_online()), "joined the shared town (%s)" % str(o.status_text()))
	_check((o.remotes as Dictionary).size() >= 1, "someone else is here: %s" % str(o.players_list()))
	o._send({"t": "chat", "text": "hello from the smoke test"})
	o.request_visit(int((o.players_list() as Array)[0].id) if not (o.players_list() as Array).is_empty() else -1)


func _online_visit_check() -> void:
	_check(bool(main.interiors.visiting()), "visiting the other player's hut over the network")
	main.interiors.leave()
	main.online.leave()


func _skip_opening() -> void:
	main.opening.skip()
	if str(main.menus.mode) != "title":
		main.menus.show_title()


func _menu_pages() -> void:
	main.menus._settings_page("title")
	main.menus._controls_page("title")
	main.menus._credits_page()


## The Harbour economy (test build), from the title: switch it on and off again.
func _harbour_switch() -> void:
	var m: Node = main.menus
	m._toggle_harbour()
	_check(bool(m.settings.harbour), "the Harbour economy switches on at the title")
	m._toggle_harbour()
	_check(not bool(m.settings.harbour), "...and off again")


## The Harbour economy (test build) in the game menu: sell, send out and bring home a Fisher.
## Everything else in the game is unchanged with it off.
func _harbour() -> void:
	var m: Node = main.menus
	m.settings.harbour = true
	m.open_pause()
	main.save["shells"] = 500
	m._harbour_page()
	_check(int(main.save.token.fishers) >= 1 and bool(main.save.token.starter), "the starter Fisher is given")
	var gull_before := float(main.save.token.gull)
	m._harbour_sell(100)
	_check(is_equal_approx(float(main.save.token.gull) - gull_before, 10.0) and int(main.save.shells) == 400, "100 Shells sell for 10 $GULL")
	m._harbour_send()
	_check((main.save.token.sea as Array).size() == 1, "the Fisher goes out to sea")
	m._harbour_home()
	_check((main.save.token.sea as Array).is_empty() and int(main.save.shells) >= 400, "the crew comes home with the catch")
	var fishers_before := int(main.save.token.fishers)
	main.save.token.gull = 10.0
	m._harbour_buy()
	_check(int(main.save.token.fishers) == fishers_before, "a Fisher costs more $GULL than this, so none is bought")
	if str(main.save.get("home", {}).get("plot", "")) == "":
		main.save.token.gull = float(main.save.token.gull) + 2000.0
		m._plots_page()
		m._harbour_buy_plot("hillside")
	_check(str(main.save.home.plot).begins_with("L-"), "a Hillside plot is bought with $GULL (%s)" % str(main.save.home.plot))
	m.settings.harbour = false
	m._pause_page()


## Homes (test build): go home from the menu, buy a sofa and wallpaper from the Home
## Catalogue, put the sofa down with the arranger, and walk back out.
func _home_go() -> void:
	_check(bool(main.interiors.visit_home()), "go home from the game menu")


func _home_decorate() -> void:
	var it: Node = main.interiors
	_check(bool(it.in_home()), "inside your home (%s)" % str(it.inside.get("name", "")))
	var cat: Node = main.catalogue
	main.save["shells"] = int(main.save.shells) + 2000
	cat.open(0)
	cat._buy_item("sofa@red", "sofa")
	cat.show_tab(cat.walls_tab())
	cat._use_style("home/wall_stripes_blue", "stripes")
	cat.close()
	_check(int(main.save.furniture_inv.get("sofa@red", 0)) >= 1, "bought a red sofa from the catalogue")
	_check(str(main.save.home.wall) == "home/wall_stripes_blue", "blue striped wallpaper is up")
	(main.save.home.furniture as Array).clear()  # a clear floor, whatever an earlier run left here
	it.refresh()
	var hb: Node = main.hut_build
	hb.begin()
	hb._sel = (hb._owned() as Array).find("sofa@red")
	hb._cursor = Vector2(0.0, -1.5)
	hb._rot = 0
	hb._act()
	hb.finish()


func _home_check() -> void:
	var placed: Array = main.save.home.furniture
	_check(placed.size() >= 1 and str(placed[-1].id) == "sofa@red", "the sofa is placed in the home")
	var built := false
	var seen: Array = []
	for f in main.interiors.furniture_nodes:
		var n: Node3D = f.node
		seen.append("%s:%d:%s" % [str(f.item.id), n.get_child_count() if is_instance_valid(n) else -1, str(is_instance_valid(n) and n.is_inside_tree())])
		if str(f.item.id) == "sofa@red" and is_instance_valid(n) and n.get_child_count() > 0:
			built = true
	_check(built, "and it's built in the room (%s)" % ", ".join(seen))


func _home_leave() -> void:
	main.interiors.leave()


func _home_out() -> void:
	_check(not bool(main.interiors.is_inside()), "back outside where we were")


func _show_title() -> void:
	main.menus.show_title()


func _start() -> void:
	main.menus._start()


func _make_fisher() -> void:
	var w: Node = main.wardrobe
	if not bool(w.is_open):
		w.open_create(null)
	for i in int((w._rows as Array).size()) - 1:
		w._sel = i
		w._change(1)
		w._change(-1)
		w._change(1)


func _finish_creator() -> void:
	main.wardrobe._finish()


func _skip_talk() -> void:
	var d: Node = main.dialogue
	for i in 60:
		if not bool(d.is_open):
			return
		d._finish(0)


func _talk_marlo() -> void:
	main.town.talk_hooks[0].call("Old Marlo")


func _land_things() -> void:
	var seen := {}
	for e: Dictionary in main.sea.items:
		var cat := str(e.cat)
		if seen.has(cat) and cat != "fish":
			continue
		if cat == "fish" and int(seen.get("fish", 0)) > 12:
			continue
		seen[cat] = int(seen.get(cat, 0)) + 1
		var cm := Sea.roll_size(e, randf())
		main.fishing.award(e, cm, "", "Great", "runner", "smoke test")
	main.fishing._set_state(0)


func _level_up() -> void:
	main.progress.add(20000, "smoke test")
	for k in main.progress.SKILL_ORDER:
		main.progress.spend(k)


func _game_menu() -> void:
	var m: Node = main.menus
	m.open_pause()
	m._fisher_page()
	m._controls_page("pause")
	m._settings_page("pause")
	m._pause_page()


func _open_bag() -> void:
	main.menus._open_screen("bag")


func _open_screen(which: String) -> void:
	main.menus._open_screen(which)


func _close_screen(which: String) -> void:
	var s: Node = main.get(which)
	if bool(s.get("is_open")):
		s.close()


func _close_pause() -> void:
	if str(main.menus.mode) == "pause":
		main.menus.close_pause()
	get_tree().paused = false


func _shop() -> void:
	main.save.shells = 99999
	var s: Node = main.shop
	s.open("Hale", "Hale's Tackle", "tackle")
	for t in (s._tabs_here as Array).size():
		s._show_tab(t, 0)
	s._buy_kit("pot")
	s._buy_kit("pot")
	s._buy_kit("net")
	s._buy_kit("troll")
	s._buy_kit("spear")
	s._buy_gear("rod", 1)


func _close_shop() -> void:
	if bool(main.shop.is_open):
		main.shop.close()
	get_tree().paused = false


func _outfitter() -> void:
	var w: Node = main.wardrobe
	w.open_shop("Odette", "Threads & Tides", "outfitter")
	w._sel = 5
	w._change(3)  # a hat that costs something
	w._finish()


func _leave_outfitter() -> void:
	if bool(main.wardrobe.is_open):
		main.wardrobe._close()
	get_tree().paused = false


func _water_near() -> Vector3:
	var p: Vector3 = main.player.global_position
	for r in range(4, 120, 4):
		for k in 16:
			var a := TAU * k / 16.0
			var q := p + Vector3(cos(a), 0.0, sin(a)) * r
			if bool(main.harbour.is_water(q.x, q.z)) and str(main.harbour.zone_at(q.x, q.z)) in ["harbour", "shallows"]:
				return q
	return p + Vector3(20.0, 0.0, 0.0)


func _drop_pot() -> void:
	main.kit._drop_pot(_water_near())


func _check_pot() -> void:
	main.kit.use({"i": 0})


func _haul_pot() -> void:
	var pots: Array = main.save.pots
	if pots.is_empty():
		push_error("SMOKE: no pot to haul")
		return
	pots[0]["t"] = float(pots[0].t) - 9999.0
	main.kit.use({"i": 0})


func _idle() -> void:
	main.fishing._set_state(0)
	main.hud.hide_catch()


func _net() -> void:
	main.kit._throw_net(_water_near())
	main.kit._finish_net(0.85)


func _troll() -> void:
	var tough: Dictionary = {}
	for e: Dictionary in main.sea.items:
		if Sea.difficulty(e) >= 5 and str(e.cat) == "fish":
			tough = e
			break
	main.fishing.troll_strike(tough, _water_near())


func _land_fight() -> void:
	main.fishing._end_fight()
	main.fishing._land()


func _dive() -> void:
	main.spear.start("reef")


func _surface() -> void:
	if bool(main.spear.is_open):
		main.spear._surface()


func _looks() -> void:
	var meta: Dictionary = Character.meta()
	for i in 12:
		var look := Character.default_look()
		look["style"] = (meta.hair as Array).pick_random()
		look["hat"] = ([""] + (meta.hats as Array)).pick_random()
		look["beard"] = ([""] + (meta.beards as Array)).pick_random()
		look["top"] = (meta.tops as Array).pick_random()
		look["pattern"] = (meta.patterns as Array).pick_random()
		look["legs"] = (meta.legs as Array).pick_random()
		look["glasses"] = randf() < 0.5
		look["skin"] = Character.SKIN_ORDER.pick_random()
		var tex := Character.texture(look)
		if tex == null:
			push_error("SMOKE: no character texture")


func _choices() -> void:
	main.dialogue.say("Smoke", ["One?", "Two?"], null, ["Yes", "No"], _answered)


func _answered(_c: int) -> void:
	pass


func _story_to_end() -> void:
	var st: Node = main.story
	for i in 60:
		if bool(st.finished()):
			break
		st._complete()
		_skip_talk()


func _summaries() -> void:
	print("  ", main.save_summary())
	print("  ", main.status_line())
	print("  ", str(main.fisher_text()).length(), " characters on the Fisher page")
	print("  music: ", main.music.pick())
	print("  journal: ", main.story.journal_lines().size(), " story lines")


func _replay() -> void:
	main.menus.show_title()
	main.menus._replay_opening()


# --- moving about (these check that you can actually get places) ------------------------

var _mark := Vector3.ZERO
var _mark_f := 0.0
var _fails := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("SMOKE CHECK ok: ", what)
	else:
		_fails += 1
		print("SMOKE CHECK FAIL: ", what)


func _release_all() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "zoom_in", "zoom_out"]:
		Input.action_release(a)


func _zoom() -> void:
	var cam: Node = main.cam
	_mark_f = float(cam._dist_goal)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	Input.parse_input_event(wheel)
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.3
	Input.parse_input_event(pinch)


func _zoom_check() -> void:
	var cam: Node = main.cam
	var after := float(cam._dist_goal)
	_check(after < _mark_f, "the wheel and a pinch zoom in (%.1f -> %.1f m)" % [_mark_f, after])
	cam.zoom_by(3.0)
	_check(float(cam._dist_goal) > after, "zooming out works")


func _building(kind: String) -> Dictionary:
	for b: Dictionary in main.harbour.buildings:
		if str(b.get("role", "")) == kind or str(b.get("kind", "")) == kind:
			return b
	return {}


func _into_lighthouse() -> void:
	_release_all()
	main.fishing._set_state(0)
	var b := _building("lighthouse")
	_check(not b.is_empty(), "there's a lighthouse")
	if not b.is_empty():
		main.interiors.enter(b)


func _stairs() -> void:
	var it: Node = main.interiors
	_check(bool(it.is_inside()), "inside the lighthouse")
	var top: Vector3 = it._stair_top
	_check(top != Vector3.INF, "the lighthouse has a stair")
	if top == Vector3.INF:
		return
	var origin: Vector3 = it.origin()
	main.player.global_position = origin + Vector3(-1.3, 0.1, top.z)
	main.player.velocity = Vector3.ZERO
	Input.action_press("move_right")


func _stairs_check() -> void:
	_release_all()
	_check(bool(main.interiors.on_gallery), "walking up the lighthouse stair reaches the lamp gallery")


func _gallery_walk() -> void:
	_mark = main.player.global_position
	Input.action_press("move_left")
	Input.action_press("move_up")


func _gallery_check() -> void:
	_release_all()
	var p: Vector3 = main.player.global_position
	_check(p.y > _mark.y - 0.6, "still on the gallery after walking round (%.1f m up)" % p.y)
	_check(p.distance_to(_mark) > 0.3, "you can walk on the gallery (moved %.1f m)" % p.distance_to(_mark))


func _climb_down() -> void:
	main.interiors.use({"kind": "descend"})


func _down_check() -> void:
	_check(bool(main.interiors.is_inside()) and not bool(main.interiors.on_gallery), "climbing down puts you back inside")


func _leave() -> void:
	_release_all()
	if bool(main.interiors.is_inside()):
		main.interiors.leave()


var _props: Array[Node] = []
var _step_base := 0.0
var _home := Vector3.ZERO
const TEST_Y := 400.0  # a test floor high above everything, so nothing else is in the way


## A flat test floor in the sky over dry land, with a 0.25 m step on one side and a 1.2 m
## crate on the other, all plain colliders.
func _build_steps() -> void:
	_home = main.player.global_position
	var w: Node = main.harbour
	var c := Vector3(_home.x, TEST_Y, _home.z)
	for ring: float in [0.0, 6.0, 12.0, 20.0, 30.0, 45.0]:
		var found := false
		for i in 12:
			var a := TAU * float(i) / 12.0
			var x: float = _home.x + cos(a) * ring
			var z: float = _home.z + sin(a) * ring
			if bool(w.walkable(x, z)) and bool(w.walkable(x + 3.5, z)) and bool(w.walkable(x - 3.5, z)):
				c = Vector3(x, TEST_Y, z)
				found = true
				break
		if found:
			break
	for spec: Array in [[Vector3(0.0, -0.25, 0.0), Vector3(14.0, 0.5, 6.0)], [Vector3(2.4, 0.125, 0.0), Vector3(2.0, 0.25, 3.0)], [Vector3(-2.4, 0.6, 0.0), Vector3(1.0, 1.2, 3.0)]]:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		col.shape = box
		body.add_child(col)
		main.add_child(body)
		body.global_position = c + (spec[0] as Vector3)
		_props.append(body)
	main.player.global_position = c + Vector3(0.0, 0.05, 0.0)
	main.player.velocity = Vector3.ZERO
	_mark = c
	_step_base = c.y


func _walk_step() -> void:
	_press_toward(_mark + Vector3(2.6, 0.0, 0.0))


func _step_check() -> void:
	_release_all()
	var p: Vector3 = main.player.global_position
	_check(p.x > _mark.x + 1.5 and p.y > _step_base + 0.18, "walked up a low step (%.2f m up, %.1f m along)" % [p.y - _step_base, p.x - _mark.x])
	main.player.global_position = _mark + Vector3(0.0, 0.05, 0.0)
	main.player.velocity = Vector3.ZERO


func _walk_crate() -> void:
	_press_toward(_mark + Vector3(-3.0, 0.0, 0.0))


func _crate_check() -> void:
	_release_all()
	var p: Vector3 = main.player.global_position
	_check(p.y < _step_base + 0.4 and p.x > _mark.x - 2.0, "a tall crate still blocks you (%.2f m up)" % (p.y - _step_base))
	for n in _props:
		n.queue_free()
	_props.clear()
	main.player.global_position = _home
	main.player.velocity = Vector3.ZERO


var _bridge_end := 0.0


## The estuary bridge, mended: start on the north bank and walk south over the river.
func _bridge_start() -> void:
	var w: Node = main.harbour
	var b: Dictionary = w.meta.bridge
	if not (w.permits as Dictionary).has("bridge"):
		w.permits["bridge"] = true
		w.rebuild_bridge()
	var x := float(b.x)
	var half := float(b.length) * 0.5
	var z0: float = float(b.z) - half - 8.0
	_bridge_end = float(b.z) + half + 3.0
	main.player.global_position = Vector3(x, float(w.height_at(x, z0)) + 0.2, z0)
	main.player.velocity = Vector3.ZERO
	_mark = main.player.global_position


func _bridge_walk() -> void:
	_press_toward(_mark + Vector3(0.0, 0.0, 100.0))


func _bridge_check() -> void:
	_release_all()
	var p: Vector3 = main.player.global_position
	_check(p.z > _bridge_end and not bool(main.player.swimming), "walked over the mended bridge (got to z %.1f of %.1f, %s)" % [p.z, _bridge_end, "swimming" if bool(main.player.swimming) else "dry"])
	main.player.global_position = _home
	main.player.velocity = Vector3.ZERO


## Hold the move keys toward a point, whichever way the camera faces.
func _press_toward(to: Vector3) -> void:
	var f: Vector3 = to - main.player.global_position
	f.y = 0.0
	f = f.normalized()
	var right: Vector3 = main.cam.global_transform.basis.x
	var fwd: Vector3 = -main.cam.global_transform.basis.z
	right.y = 0.0
	fwd.y = 0.0
	var x: float = f.dot(right.normalized())
	var y: float = f.dot(fwd.normalized())
	if x > 0.05:
		Input.action_press("move_right", x)
	elif x < -0.05:
		Input.action_press("move_left", -x)
	if y > 0.05:
		Input.action_press("move_up", y)
	elif y < -0.05:
		Input.action_press("move_down", -y)


func _boat() -> void:
	_check(not bool(main.interiors.is_inside()), "back outside")
	(main.save.boats as Array).append("row")
	main.save.boat = "row"
	main.boats.spawn_at_dock(main.player.global_position)
	main.boats.board()
	_mark = main.boats.boat.global_position


## Push the stick the way the bow points (out to sea from the dock), whichever way the camera faces.
func _steer() -> void:
	var f: Vector3 = main.boats.forward()
	var right: Vector3 = main.boats.cam.ground_right()
	var fwd: Vector3 = main.boats.cam.ground_forward()
	var x: float = f.dot(right)
	var y: float = f.dot(fwd)
	if x > 0.05:
		Input.action_press("move_right", x)
	elif x < -0.05:
		Input.action_press("move_left", -x)
	if y > 0.05:
		Input.action_press("move_up", y)
	elif y < -0.05:
		Input.action_press("move_down", -y)


func _steer_check() -> void:
	_release_all()
	var moved: float = (main.boats.boat.global_position as Vector3).distance_to(_mark)
	_check(moved > 3.0, "the rowboat moves when you steer (%.1f m, speed %.1f)" % [moved, float(main.boats.speed)])
	if bool(main.boats.can_land()):
		main.boats.go_ashore()
	else:
		main.boats.aboard = false
		main.player.riding = false
		main.player.global_position = Vector3(436.0, float(main.harbour.height_at(436.0, 566.0)) + 0.5, 566.0)
	main.player.can_move = true


## Every dock and jetty: stand on the ground just past its landward end and walk on.
func _plan_docks() -> void:
	# (with every permit, as you'd have by the time you sail to the far islands)
	for k: String in ["permit_ranger", "permit_ember", "bridge"]:
		main.harbour.permits[k] = true
	var at := _i
	var n := 0
	for d: Dictionary in main.harbour.docks:
		n += 1
		_steps.insert(at, ["go to dock %d" % n, _dock_start.bind(d), 20])
		_steps.insert(at + 1, ["walk onto dock %d" % n, _dock_walk.bind(d, n), 50])
		_steps.insert(at + 2, ["check dock %d" % n, _dock_check.bind(d, n), 3])
		at += 3


var _dock_skip := false


## The two points a metre past each end of a dock, along its length.
func _dock_ends(d: Dictionary) -> Array[Vector3]:
	var r: Rect2 = d.rect
	var c := r.get_center()
	var long_x := r.size.x >= r.size.y
	var half := (r.size.x if long_x else r.size.y) * 0.5 + 1.0
	var axis := Vector2(1.0, 0.0) if long_x else Vector2(0.0, 1.0)
	var a := c + axis * half
	var b := c - axis * half
	return [Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y)]


func _dock_start(d: Dictionary) -> void:
	_release_all()
	var ends := _dock_ends(d)
	var e: Vector3 = ends[0]
	main.player.global_position = Vector3(e.x, float(main.harbour.stand_height(e.x, e.z)) + 0.5, e.z)
	main.player.velocity = Vector3.ZERO
	main.player.can_move = true


## The top of whatever's solid at (x, z): ground, a quay, a deck. -INF over nothing.
func _top_at(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -30.0, z), 1)
	q.exclude = [main.player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -INF
	var at: Vector3 = hit.position
	return at.y


func _dock_walk(d: Dictionary, n: int) -> void:
	var w: Node = main.harbour
	var best := Vector3.INF
	var best_y := -INF
	for e: Vector3 in _dock_ends(d):
		var top := _top_at(e.x, e.z)
		var wl := float(w.water_level_at(e.x, e.z))
		if top > wl - 0.3 and top < float(d.y) + 1.0 and top > best_y:  # (not a roof)
			best_y = top
			best = Vector3(e.x, top, e.z)
	_dock_skip = best == Vector3.INF
	if _dock_skip:
		print("  dock %d (%s): open water at both ends, reached by boat" % [n, str(d.rect)])
		return
	main.player.global_position = best + Vector3(0.0, 0.1, 0.0)
	main.player.velocity = Vector3.ZERO
	var r: Rect2 = d.rect
	var c := r.get_center()
	_press_toward(Vector3(c.x, best.y, c.y))


func _dock_check(d: Dictionary, n: int) -> void:
	_release_all()
	if _dock_skip:
		return
	var r: Rect2 = d.rect
	var p: Vector3 = main.player.global_position
	var on: bool = r.grow(0.3).has_point(Vector2(p.x, p.z)) and p.y > float(d.y) - 0.25
	_check(on, "walked onto dock %d at %s from the shore (at %.1f, %.1f, %.1f; deck %.2f)" % [n, str(r.position.round()), p.x, p.y, p.z, float(d.y)])


## Go into every building, walk into the room, and come back out.
func _plan_tour() -> void:
	var at := _i
	for b: Dictionary in main.harbour.buildings:
		var name := str(b.get("name", "?"))
		_steps.insert(at, ["enter " + name, _tour_enter.bind(b), 45])
		_steps.insert(at + 1, ["walk about in " + name, _tour_walk, 45])
		_steps.insert(at + 2, ["leave " + name, _tour_leave.bind(name), 45])
		_steps.insert(at + 3, ["check outside " + name, _tour_out.bind(name), 3])
		at += 4


func _tour_enter(b: Dictionary) -> void:
	_release_all()
	main.player.can_move = true
	main.interiors.enter(b)


func _tour_walk() -> void:
	_check(bool(main.interiors.is_inside()), "went inside")
	_mark = main.player.global_position
	Input.action_press("move_up")


func _tour_leave(name: String) -> void:
	_release_all()
	var moved: float = (main.player.global_position as Vector3).distance_to(_mark)
	var pl: Node = main.player
	var pp: Vector3 = pl.global_position
	_check(moved > 0.4, "can walk about inside %s (%.1f m; can_move %s, swimming %s, riding %s, floor %s, hud blocked %s, paused %s, walkable %s, y %.2f)" % [
		name, moved, pl.can_move, pl.swimming, pl.riding, pl.is_on_floor(), main.hud.input_blocked(), get_tree().paused,
		main.harbour.walkable(pp.x, pp.z), pp.y - float(main.interiors.origin().y)])
	main.interiors.leave()


func _tour_out(name: String) -> void:
	var p: Vector3 = main.player.global_position
	var ground := maxf(float(main.harbour.height_at(p.x, p.z)), float(main.harbour.stand_height(p.x, p.z)))
	_check(not bool(main.interiors.is_inside()), "came back out of " + name)
	_check(p.y > ground - 1.0 and p.y < ground + 3.0, "standing on the ground outside %s (y %.1f, ground %.1f)" % [name, p.y, ground])


var _shore_dir := Vector3.ZERO


## Drop into the harbour a few metres off the beach, then swim for the nearest dry land.
func _fall_in() -> void:
	_release_all()
	var w: Node = main.harbour
	var best := Vector3.INF
	var best_land := Vector3.INF
	for r in range(6, 160, 3):
		for k in 24:
			var a := TAU * k / 24.0
			var q: Vector3 = main.player.global_position + Vector3(cos(a), 0.0, sin(a)) * r
			if not bool(w.is_water(q.x, q.z)) or float(w.water_depth(q.x, q.z)) < 1.6:
				continue  # dry, or shallow enough to wade
			# land within 8 m of this water spot?
			for k2 in 16:
				var a2 := TAU * k2 / 16.0
				for d: float in [4.0, 6.0, 8.0]:
					var l := q + Vector3(cos(a2), 0.0, sin(a2)) * d
					if not bool(w.is_water(l.x, l.z)) and float(w.height_at(l.x, l.z)) < float(w.sea_level) + 2.5:
						best = q
						best_land = l
						break
				if best != Vector3.INF:
					break
			if best != Vector3.INF:
				break
		if best != Vector3.INF:
			break
	_check(best != Vector3.INF, "found a stretch of water by a beach")
	if best == Vector3.INF:
		return
	_shore_dir = (best_land - best).normalized()
	main.player.global_position = Vector3(best.x, float(w.sea_level) + 0.2, best.z)
	main.player.velocity = Vector3.ZERO
	main.player.can_move = true


func _swim() -> void:
	_check(bool(main.player.swimming), "swimming after falling in")
	# hold the stick toward the shore, as seen from the camera
	var right: Vector3 = main.cam.ground_right()
	var fwd: Vector3 = main.cam.ground_forward()
	var x := _shore_dir.dot(right)
	var y := -_shore_dir.dot(fwd)
	if x > 0.2:
		Input.action_press("move_right", minf(1.0, x * 1.5))
	elif x < -0.2:
		Input.action_press("move_left", minf(1.0, -x * 1.5))
	if y < -0.2:
		Input.action_press("move_up", minf(1.0, -y * 1.5))
	elif y > 0.2:
		Input.action_press("move_down", minf(1.0, y * 1.5))


func _swim_check() -> void:
	_release_all()
	var p: Vector3 = main.player.global_position
	_check(not bool(main.player.swimming), "climbed out of the water onto the shore (at %.0f, %.0f)" % [p.x, p.z])
