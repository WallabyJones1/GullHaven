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
