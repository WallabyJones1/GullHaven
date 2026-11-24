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

var main: Node
var _steps: Array = []
var _i := 0
var _wait := 0


func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	_steps = [
		["let the opening play", _noop, 90],
		["skip the opening", _skip_opening, 20],
		["main menu pages", _menu_pages, 10],
		["back to the menu", _show_title, 10],
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
		["leave the game menu", _close_pause, 10],
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
		["sail a rowboat", _boat, 20],
		["steer it", _steer, 150],
		["check it moved", _steer_check, 5],
		["plan a tour of every building", _plan_tour, 5],
		["watch the opening again", _replay, 60],
		["skip it", _skip_opening, 10],
		["start again", _start, 10],
	]


func _process(_delta: float) -> void:
	if _wait > 0:
		_wait -= 1
		return
	if _i >= _steps.size():
		print("SMOKE DONE, %d checks failed" % _fails)
		get_tree().quit()
		set_process(false)
		return
	var s: Array = _steps[_i]
	_i += 1
	print("SMOKE ", str(s[0]))
	(s[1] as Callable).call()
	_wait = int(s[2])


func _noop() -> void:
	pass


func _skip_opening() -> void:
	main.opening.skip()
	if str(main.menus.mode) != "title":
		main.menus.show_title()


func _menu_pages() -> void:
	main.menus._settings_page("title")
	main.menus._controls_page("title")
	main.menus._credits_page()


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
	main.player.global_position = origin + Vector3(-0.9, 0.1, top.z)
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


func _boat() -> void:
	_check(not bool(main.interiors.is_inside()), "back outside")
	(main.save.boats as Array).append("row")
	main.save.boat = "row"
	main.boats.spawn_at_dock(main.player.global_position)
	main.boats.board()
	_mark = main.boats.boat.global_position


func _steer() -> void:
	Input.action_press("move_up")


func _steer_check() -> void:
	_release_all()
	var moved: float = (main.boats.boat.global_position as Vector3).distance_to(_mark)
	_check(moved > 1.0, "the rowboat moves when you steer (%.1f m)" % moved)
	if bool(main.boats.can_land()):
		main.boats.go_ashore()
	else:
		main.boats.aboard = false
		main.player.riding = false
		main.player.global_position = Vector3(436.0, float(main.harbour.height_at(436.0, 566.0)) + 0.5, 566.0)
	main.player.can_move = true


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
	_check(moved > 0.4, "can walk about inside %s (%.1f m)" % [name, moved])
	main.interiors.leave()


func _tour_out(name: String) -> void:
	var p: Vector3 = main.player.global_position
	var ground := maxf(float(main.harbour.height_at(p.x, p.z)), float(main.harbour.stand_height(p.x, p.z)))
	_check(not bool(main.interiors.is_inside()), "came back out of " + name)
	_check(p.y > ground - 1.0 and p.y < ground + 3.0, "standing on the ground outside %s (y %.1f, ground %.1f)" % [name, p.y, ground])
