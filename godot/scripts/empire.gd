extends Node3D
## Your fishing empire. The longer you play, the bigger it gets:
##   - The fleet: buy boats for your fleet (they moor at your own dock, one to a berth).
##   - Crews: hire fishers from the harbour (they sleep in your bunkhouse), put them on a
##     boat and send it out: along the coast (15 minutes), out to the islands (an hour), past
##     the reef (four hours) or an overnight run. Trips run on real time, so they keep
##     fishing while you play, or while the game's closed. Bigger boats, fuller crews and
##     old hands bring back more; crews get better with every trip.
##   - Your harbour: build your dock out (more berths), the bunkhouse (more crew), and a
##     smokehouse (sells the crews' catch for more). Tess still does the hut: it grows to a
##     fishing house and a harbour hall now.
##   - Ranks: Lone fisher, Skipper, Fleet owner, Harbour boss, Fishing baron and Tycoon of
##     the Coast, by what your empire's worth.
## Everything's run from the ledger board at the head of your jetty, by Gran's hut.

const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Boats := preload("res://scripts/boats.gd")
const Billboard := preload("res://scripts/billboard.gd")
const Character := preload("res://scripts/character.gd")
const Models := preload("res://scripts/models.gd")

const SEATS := {"row": 1, "dinghy": 2, "skiff": 2, "sloop": 3, "trawler": 4, "cutter": 5}
const RATE := [0.0, 4.0, 9.0, 18.0, 30.0, 55.0]  # Shells a minute, by boat tier, with a full crew
const TRIPS := [
	{"k": "coast", "n": "Along the coast", "mins": 15, "bonus": 1.0},
	{"k": "islands", "n": "Out to the islands", "mins": 60, "bonus": 1.1},
	{"k": "reef", "n": "Out past the reef", "mins": 240, "bonus": 1.2},
	{"k": "night", "n": "An overnight run", "mins": 480, "bonus": 1.3},
]
const DOCK := [
	{"n": "Gran's jetty", "price": 0, "mats": {}, "berths": 1, "d": "One berth beside your own boat."},
	{"n": "Finger pier", "price": 2500, "mats": {"wood": 40, "rope": 10}, "berths": 2, "d": "A pier off the jetty: two berths."},
	{"n": "Fishing pier", "price": 9000, "mats": {"wood": 90, "rope": 20, "scrap": 10}, "berths": 4, "d": "Two piers and four berths."},
	{"n": "Harbour wharf", "price": 30000, "mats": {"wood": 160, "rope": 40, "scrap": 30}, "berths": 6, "d": "A proper wharf: six berths."},
]
const BUNKS := [
	{"n": "A spare hammock", "price": 0, "mats": {}, "crew": 2, "d": "Room for two crew."},
	{"n": "Bunk shed", "price": 1500, "mats": {"wood": 30}, "crew": 4, "d": "Four bunks."},
	{"n": "Crew bunkhouse", "price": 6000, "mats": {"wood": 70, "rope": 10}, "crew": 8, "d": "Eight bunks and a stove."},
	{"n": "Sailors' lodge", "price": 20000, "mats": {"wood": 120, "rope": 25, "scrap": 20}, "crew": 14, "d": "Fourteen bunks, a mess hall."},
]
const SMOKE := [
	{"n": "No smokehouse", "price": 0, "mats": {}, "bonus": 0.0, "d": "The crews sell their catch straight off the boat."},
	{"n": "Smoke shed", "price": 3000, "mats": {"wood": 40}, "bonus": 0.2, "d": "Smoked fish sells for a fifth more."},
	{"n": "Smokehouse", "price": 12000, "mats": {"wood": 80, "scrap": 15}, "bonus": 0.45, "d": "Nearly half as much again."},
	{"n": "Cannery", "price": 40000, "mats": {"wood": 140, "rope": 30, "scrap": 40}, "bonus": 0.8, "d": "Tins with your name on: 80% more."},
]
const RANKS := [
	{"n": "Lone fisher", "at": 0},
	{"n": "Skipper", "at": 3000},
	{"n": "Fleet owner", "at": 20000},
	{"n": "Harbour boss", "at": 80000},
	{"n": "Fishing baron", "at": 250000},
	{"n": "Tycoon of the Coast", "at": 750000},
]
const HIRE := [
	{"n": "a deckhand", "skill": 1, "price": 200},
	{"n": "a fisher", "skill": 2, "price": 700},
	{"n": "an old hand", "skill": 3, "price": 2000},
	{"n": "a master skipper", "skill": 5, "price": 9000},
]
const FIRST := ["Ada", "Bea", "Cal", "Dot", "Ed", "Fen", "Gus", "Hal", "Ivy", "Jem", "Kit", "Lou", "Mo", "Ned", "Ola", "Pip", "Quin", "Ros",
	"Sam", "Tam", "Ula", "Vic", "Wren", "Yan", "Zed", "Bo", "Cass", "Del", "Flo", "Gil", "Hob", "Isa", "Jo", "Kai", "Lark", "Mae"]
const LAST := ["Brine", "Cockle", "Dunn", "Ferris", "Gale", "Haddock", "Keel", "Ling", "Marsh", "Netley", "Oakes", "Pike", "Reed",
	"Salt", "Tern", "Wade", "Whelk", "Yarrow"]
const BOAT_NAMES := ["Gull's Pride", "Saltwind", "Tideday", "Second Wind", "Dawn Patrol", "Lucky Cockle", "Bright Herring", "Sea Biscuit",
	"Moonraker", "Brine Queen", "Little Gran", "Wavecutter", "Old Faithful", "Silver Darling", "Kelp Runner", "Fair Weather"]
const MATS := ["wood", "rope", "scrap"]

var main: Node
var _root: Node3D  # the built dock, the fleet's boats and the crew
var _dock_entries: Array = []  # what this added to world.docks
var _berths: Array = []  # {pos, heading}
var _boat_nodes := {}  # fleet id -> Node3D
var _crew_nodes: Array = []
var _board_at := Vector3.INF
var _tick := 0.0
var _trip_pick := 1
var _rng := RandomNumberGenerator.new()
var menu: CanvasLayer
var _title: Label
var _list: VBoxContainer
var _msg: Label
var _tab_row: HBoxContainer
var _tab := 0
var _tabs := ["Fleet", "Crew", "Harbour", "Records"]


func setup(m: Node) -> void:
	main = m
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS  # trips come home while the ledger's open too
	E()
	main.town.providers.append(self)
	_build_menu()
	rebuild()


## The empire's save: fleet, crew and buildings.
func E() -> Dictionary:
	var sv: Dictionary = main.save
	if not sv.has("empire") or not (sv.empire is Dictionary):
		sv["empire"] = {}
	var e: Dictionary = sv.empire
	for k in [["fleet", []], ["crew", []], ["dock", 0], ["bunks", 0], ["smoke", 0], ["earned", 0], ["trips", 0], ["next_id", 1],
			["rank", 0], ["log", []], ["spent", 0]]:
		if not e.has(k[0]):
			e[k[0]] = k[1]
	return e


static func now() -> int:
	return int(Time.get_unix_time_from_system())


# --- what it's worth ---------------------------------------------------------------------------

func berths() -> int:
	return mini(int(DOCK[int(E().dock)].berths), maxi(1, _berths.size()))


func bunks() -> int:
	return int(BUNKS[int(E().bunks)].crew)


func value() -> int:
	var e := E()
	var v := int(e.earned) + int(e.spent)
	for b in e.fleet:
		v += int(Boats.boat_info(str(b.kind)).get("price", 0))
	return v


func rank() -> int:
	var v := value()
	var r := 0
	for i in RANKS.size():
		if v >= int(RANKS[i].at):
			r = i
	return r


func rank_name() -> String:
	return str(RANKS[rank()].n)


func _check_rank() -> void:
	var r := rank()
	if r > int(E().rank):
		E()["rank"] = r
		main.audio.play("fanfare2")
		main.hud.show_banner(str(RANKS[r].n), "Your fishing empire grows")
		if main.online and main.online.is_online():
			main.online.announce("is now a %s!" % str(RANKS[r].n).to_lower())


# --- the dock, the boats at their berths and the crew ------------------------------------------

func rebuild() -> void:
	if _root:
		_root.queue_free()
	for d in _dock_entries:
		main.harbour.docks.erase(d)
	_dock_entries.clear()
	_boat_nodes.clear()
	_crew_nodes.clear()
	_root = Node3D.new()
	_root.name = "Empire"
	add_child(_root)
	var w: Node3D = main.harbour
	var j: Dictionary = w.meta.hut.jetty
	var jx := float(j.x)
	var jz := float(j.z)
	var jw := float(j.w)
	var y := float(w.meta.hut.y)
	var level := int(E().dock)
	var before: int = (w.docks as Array).size()
	var builder: RefCounted = w.builder
	# the dock grows out to sea from the end of Gran's jetty: a longer jetty, then a T-head,
	# then a long T with berths all down it
	var end := jx + jw
	var piers: Array = []
	if level >= 1:
		piers.append([end, jz - 1.2, end + 12.0, jz + 1.2])
	if level == 2:
		piers.append([end + 12.0, jz - 6.0, end + 14.4, jz + 6.0])
	if level >= 3:
		piers.append([end + 12.0, jz - 12.0, end + 14.4, jz + 12.0])
	for r in piers:
		builder.dock(_root, {"rect": r}, y)
	for i in range((w.docks as Array).size() - before):
		_dock_entries.append(w.docks[before + i])
	# berths, in the order they open up
	var cands := [[Vector3(end + 3.5, 0, jz - 3.4), PI * 0.5], [Vector3(end + 9.5, 0, jz + 3.4), PI * 0.5],
		[Vector3(end + 9.5, 0, jz - 3.4), PI * 0.5], [Vector3(end + 17.6, 0, jz - 3.0), 0.0], [Vector3(end + 17.6, 0, jz + 3.0), 0.0],
		[Vector3(end + 17.6, 0, jz - 9.0), 0.0], [Vector3(end + 17.6, 0, jz + 9.0), 0.0]]
	_berths.clear()
	for c in cands:
		var p: Vector3 = c[0]
		if w.is_water(p.x, p.z) and float(w.water_depth(p.x, p.z)) > 0.5:
			_berths.append({"pos": Vector3(p.x, float(w.sea_level), p.z), "heading": float(c[1])})
	# the ledger board at the head of the jetty
	var board := Models.make("outdoor", "noticeboard")
	_board_at = Vector3(jx - 1.2, float(w.stand_height(jx - 1.2, jz - 2.0)), jz - 2.0)
	if board:
		_root.add_child(board)
		board.global_position = _board_at
	for k in 3:
		var bol := Models.make("outdoor", "bollard")
		if bol:
			_root.add_child(bol)
			bol.global_position = Vector3(end - 4.5 + k * 2.0, y - 0.1, jz + (1.0 if k != 1 else -1.0))
	_place_boats()
	_place_crew()


func _place_boats() -> void:
	var e := E()
	for id in _boat_nodes:
		(_boat_nodes[id] as Node3D).queue_free()
	_boat_nodes.clear()
	var i := 0
	for b in e.fleet:
		if i >= _berths.size():
			break
		var info: Dictionary = Boats.boat_info(str(b.kind))
		var node: Node3D = main.boats.build_model(info, Color.html(str(b.get("paint", info.hull))), false)
		_root.add_child(node)
		var bt: Dictionary = _berths[i]
		node.global_position = bt.pos
		node.rotation.y = float(bt.heading)
		node.visible = (b.get("trip", {}) as Dictionary).is_empty()
		_boat_nodes[int(b.id)] = node
		b["berth"] = i
		i += 1


func _place_crew() -> void:
	for n in _crew_nodes:
		(n as Node3D).queue_free()
	_crew_nodes.clear()
	var w: Node3D = main.harbour
	var j: Dictionary = w.meta.hut.jetty
	var k := 0
	for c in E().crew:
		if _on_trip(int(c.get("boat", -1))):
			continue
		if k >= 8:
			break
		var tex := Character.texture(_full_look(c.look))
		if tex == null:
			continue
		var s := Billboard.sprite(tex, 1.0 / 26.0, 5, 4, 46.0)
		_root.add_child(s)
		var x := float(j.x) + float(j.w) - 1.0 - k * 1.45 + (0.25 if k % 3 == 1 else 0.0)
		var z: float = float(j.z) + [0.55, -0.5, 0.1][k % 3]
		s.global_position = Vector3(x, float(w.stand_height(x, z)), z)
		s.frame = int([Billboard.DOWN, Billboard.RIGHT, Billboard.DOWN, Billboard.LEFT][k % 4]) * 5
		_crew_nodes.append(s)
		k += 1


func _full_look(look: Variant) -> Dictionary:
	var full := Character.default_look()
	if look is Dictionary:
		full.merge(look, true)
	return full


func _on_trip(boat_id: int) -> bool:
	for b in E().fleet:
		if int(b.id) == boat_id:
			return not (b.get("trip", {}) as Dictionary).is_empty()
	return false


# --- the clock ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var t := now()
	for b in E().fleet:
		var trip: Dictionary = b.get("trip", {})
		if not trip.is_empty() and not bool(trip.get("back", false)) and t >= int(trip.end):
			trip["back"] = true
			if _boat_nodes.has(int(b.id)):
				_sail_in(_boat_nodes[int(b.id)])
			main.hud.toast("The %s is back at your dock with her catch. Unload her at the ledger board." % str(b.name))
			main.audio.play("horn", -8.0)


func _sail_out(node: Node3D) -> void:
	var from := node.global_position
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", from + Vector3(40.0, 0.0, 0.0), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		node.visible = false
		node.global_position = from)


func _sail_in(node: Node3D) -> void:
	var to := node.global_position
	node.global_position = to + Vector3(40.0, 0.0, 0.0)
	node.visible = true
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- the ledger board -------------------------------------------------------------------------

func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	if _board_at == Vector3.INF or main.interiors.is_inside():
		return {}
	var d := Vector2(pos.x - _board_at.x, pos.z - _board_at.z).length()
	if d > 2.4:
		return {}
	var back := 0
	for b in E().fleet:
		if bool((b.get("trip", {}) as Dictionary).get("back", false)):
			back += 1
	var text := "Space: Your fishing empire (the ledger)"
	if back > 0:
		text = "Space: The ledger: %d boat%s back to unload!" % [back, "" if back == 1 else "s"]
	return {"kind": "ledger", "dist": d, "text": text}


func use(_it: Dictionary) -> void:
	open_menu()


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
	panel.custom_minimum_size = Vector2(900.0, 620.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = UI.label("", 30, UI.GOLD, true)
	col.add_child(_title)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	col.add_child(_tab_row)
	for k in _tabs.size():
		var t := UI.button(str(_tabs[k]), 20)
		t.focus_mode = Control.FOCUS_NONE
		t.pressed.connect(_show_tab.bind(k))
		_tab_row.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 400.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_msg = UI.label("", 20, UI.GOOD)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_msg)
	col.add_child(UI.label(Glyphs.plain("{updown} choose   {action} pick   {leftright} change tab   {cancel} close"), 18, UI.DIM))


func open_menu(tab := 0) -> void:
	menu.visible = true
	get_tree().paused = true
	_msg.text = ""
	_show_tab(tab)


func close_menu() -> void:
	menu.visible = false
	get_tree().set_deferred("paused", false)
	main.hud.block_input(0.25)


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
		_show_tab((_tab + _tabs.size() - 1) % _tabs.size())
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_show_tab((_tab + 1) % _tabs.size())


func _row(text: String, cb: Callable, dim := false, off := false, colour := Color(0, 0, 0, 0)) -> Button:
	var b := UI.button(text, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if off:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	else:
		b.pressed.connect(cb)
	if dim:
		b.add_theme_color_override("font_color", UI.DIM)
	elif colour.a > 0.0:
		b.add_theme_color_override("font_color", colour)
	_list.add_child(b)
	return b


func _note(text: String, colour := Color(0, 0, 0, 0), size := 19) -> void:
	var l := UI.label(text, size, colour if colour.a > 0.0 else UI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)


func _say(text: String, good := true) -> void:
	_msg.add_theme_color_override("font_color", UI.GOOD if good else UI.BAD)
	_msg.text = text
	main.audio.play("buy" if good else "error", -4.0)


static func _clock(secs: int) -> String:
	secs = maxi(0, secs)
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	return "%dm %02ds" % [secs / 60, secs % 60]


func _show_tab(k: int, focus := 0) -> void:
	_tab = k
	for c in _list.get_children():
		c.queue_free()
	for t in _tab_row.get_child_count():
		(_tab_row.get_child(t) as Button).add_theme_color_override("font_color", UI.GOLD if t == k else UI.CREAM)
	var e := E()
	_title.text = "Your fishing empire   %s   %d Shells" % [rank_name(), int(main.save.shells)]
	var rows: Array[Button] = []
	match k:
		0:
			var tp: Dictionary = TRIPS[_trip_pick]
			rows.append(_row("Trips: %s (%s)   change" % [tp.n, _clock(int(tp.mins) * 60)], _next_trip, false, false, UI.GOLD))
			var t := now()
			for b in e.fleet:
				var info: Dictionary = Boats.boat_info(str(b.kind))
				var crew := _crew_of(int(b.id))
				var seats := int(SEATS.get(str(b.kind), 1))
				var trip: Dictionary = b.get("trip", {})
				var state := ""
				var cb := Callable()
				if trip.is_empty():
					if crew.is_empty():
						state = "at the dock, no crew   (crew her up)"
						cb = _crew_up.bind(int(b.id))
					else:
						state = "crew %d/%d   send her out: about %d Shells" % [crew.size(), seats, _estimate(b, _trip_pick)]
						cb = _send.bind(int(b.id))
				elif bool(trip.get("back", false)) or t >= int(trip.end):
					state = "BACK! Unload her catch"
					cb = _unload.bind(int(b.id))
				else:
					state = "%s, back in %s" % [str(TRIPS[int(trip.kind)].n).to_lower(), _clock(int(trip.end) - t)]
				var row := _row("%s (%s)   %s" % [b.name, info.n, state], cb, false, not cb.is_valid(),
					UI.GOOD if state.begins_with("BACK") else Color(0, 0, 0, 0))
				rows.append(row)
				if trip.is_empty() and not crew.is_empty() and crew.size() < seats:
					rows.append(_row("    %s: add crew (%d/%d)" % [b.name, crew.size(), seats], _crew_up.bind(int(b.id))))
			if e.fleet.is_empty():
				_note("No fleet yet. Buy a boat below: she'll moor at your dock, and the crews you hire will take her out fishing for you.")
			var free := berths() - (e.fleet as Array).size()
			_note("Berths at your dock: %d of %d used. Build the dock out on the Harbour page for more." % [(e.fleet as Array).size(), berths()])
			for bk in Boats.BOATS:
				var price := int(bk.price)
				rows.append(_row("Buy a %s for the fleet   %d Shells   (%d crew, %d Shells a minute out)" % [str(bk.n).to_lower(), price,
					int(SEATS.get(str(bk.k), 1)), int(RATE[int(bk.tier)])], _buy_boat.bind(str(bk.k)), int(main.save.shells) < price or free <= 0))
		1:
			var crew_n := (e.crew as Array).size()
			_note("Crew: %d of %d bunks. Hire fishers from the harbour; the more they sail, the better they get." % [crew_n, bunks()])
			for c in e.crew:
				var where := "waiting on the jetty"
				for b in e.fleet:
					if int(b.id) == int(c.get("boat", -1)):
						where = ("out on the %s" if _on_trip(int(b.id)) else "crewing the %s") % str(b.name)
				var stars := "*".repeat(int(c.skill)) + ".".repeat(maxi(0, 5 - int(c.skill)))
				var train := int(c.skill) < 5
				rows.append(_row("%s   %s   %s%s" % [c.name, stars, where, ("   (train: %d Shells)" % (int(c.skill) * 600)) if train else ""],
					_train.bind(int(c.id)), train and int(main.save.shells) < int(c.skill) * 600, not train))
			for h in HIRE:
				rows.append(_row("Hire %s (skill %d)   %d Shells" % [h.n, int(h.skill), int(h.price)], _hire.bind(int(h.skill), int(h.price)),
					int(main.save.shells) < int(h.price) or crew_n >= bunks()))
		2:
			for part in [["dock", DOCK, "Your dock"], ["bunks", BUNKS, "Crew bunks"], ["smoke", SMOKE, "Smokehouse"]]:
				var key := str(part[0])
				var table: Array = part[1]
				var lvl := int(e[key])
				_note("%s: %s. %s" % [part[2], table[lvl].n, table[lvl].d], UI.CREAM)
				if lvl + 1 < table.size():
					var nx: Dictionary = table[lvl + 1]
					var short := _short(int(nx.price), nx.mats)
					rows.append(_row("    Build: %s   %s   (%s)" % [nx.n, _cost(int(nx.price), nx.mats), nx.d], _build.bind(key, lvl + 1), short != ""))
			_note("Your hut: Tess the carpenter, in the harbour, builds it bigger: all the way to a fishing house and a harbour hall.", UI.CREAM)
		3:
			_note("Rank: %s" % rank_name(), UI.GOLD, 24)
			var r := rank()
			if r + 1 < RANKS.size():
				_note("Next: %s at %d Shells of empire (you're at %d)." % [RANKS[r + 1].n, int(RANKS[r + 1].at), value()])
			_note("Earned by your crews: %d Shells over %d trips." % [int(e.earned), int(e.trips)], UI.CREAM)
			_note("Fleet: %d boats.  Crew: %d.  Dock: %s.  Smokehouse: %s." % [(e.fleet as Array).size(), (e.crew as Array).size(),
				DOCK[int(e.dock)].n, SMOKE[int(e.smoke)].n], UI.CREAM)
			for line in e.log:
				_note(str(line))
			rows.append(_row("Close the ledger", close_menu))
	if not rows.is_empty():
		var f: Array[Button] = []
		for b in rows:
			if b.focus_mode != Control.FOCUS_NONE:
				f.append(b)
		if not f.is_empty():
			UI.focus_soon(f[clampi(focus, 0, f.size() - 1)])


func _next_trip() -> void:
	_trip_pick = (_trip_pick + 1) % TRIPS.size()
	_show_tab(0)


func _crew_of(boat_id: int) -> Array:
	var out: Array = []
	for c in E().crew:
		if int(c.get("boat", -1)) == boat_id:
			out.append(c)
	return out


func _idle_crew() -> Array:
	var out: Array = []
	for c in E().crew:
		if int(c.get("boat", -1)) < 0:
			out.append(c)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.skill) > int(b.skill))
	return out


## What a trip should bring home (before the smokehouse and luck).
func _estimate(b: Dictionary, trip_i: int) -> int:
	var crew := _crew_of(int(b.id))
	if crew.is_empty():
		return 0
	var info: Dictionary = Boats.boat_info(str(b.kind))
	var seats := int(SEATS.get(str(b.kind), 1))
	var skill := 0.0
	for c in crew:
		skill += float(c.skill)
	skill /= crew.size()
	var tp: Dictionary = TRIPS[trip_i]
	var full := 0.55 + 0.45 * float(crew.size()) / seats
	var k := full * (1.0 + 0.15 * (skill - 1.0)) * float(tp.bonus) * (1.0 + float(SMOKE[int(E().smoke)].bonus))
	return int(RATE[int(info.tier)] * float(tp.mins) * k)


func _crew_up(boat_id: int) -> void:
	var b := _boat(boat_id)
	var seats := int(SEATS.get(str(b.kind), 1))
	var have := _crew_of(boat_id).size()
	var idle := _idle_crew()
	if idle.is_empty():
		_say("Nobody's free. Hire more crew on the Crew page.", false)
		return
	var n := 0
	for c in idle:
		if have + n >= seats:
			break
		c["boat"] = boat_id
		n += 1
	_say("%d aboard the %s." % [n, b.name])
	_place_crew()
	SaveGame.write(main.save)
	_show_tab(0)


func _boat(boat_id: int) -> Dictionary:
	for b in E().fleet:
		if int(b.id) == boat_id:
			return b
	return {}


func _send(boat_id: int) -> void:
	var b := _boat(boat_id)
	var tp: Dictionary = TRIPS[_trip_pick]
	b["trip"] = {"kind": _trip_pick, "start": now(), "end": now() + int(tp.mins) * 60, "est": _estimate(b, _trip_pick)}
	if _boat_nodes.has(boat_id):
		_sail_out(_boat_nodes[boat_id])
	main.audio.play("horn", -6.0)
	_say("The %s is away, %s. Back in %s." % [b.name, str(tp.n).to_lower(), _clock(int(tp.mins) * 60)])
	_place_crew()
	SaveGame.write(main.save)
	_show_tab(0)


func _unload(boat_id: int) -> void:
	var b := _boat(boat_id)
	var trip: Dictionary = b.get("trip", {})
	if trip.is_empty():
		return
	var e := E()
	var shells := int(float(trip.get("est", 0)) * _rng.randf_range(0.85, 1.25))
	var mins := (int(trip.end) - int(trip.start)) / 60
	var bits: Array[String] = ["%d Shells" % shells]
	var mats := {}
	for i in maxi(1, mins / 30):
		if _rng.randf() < 0.6:
			var mk: String = MATS[_rng.randi() % MATS.size()]
			mats[mk] = int(mats.get(mk, 0)) + _rng.randi_range(1, 3)
	if not mats.is_empty():
		main.town.add_materials(mats)
		for mk in mats:
			bits.append("%d %s" % [int(mats[mk]), mk])
	if _rng.randf() < 0.04 * maxf(1.0, mins / 60.0) and main.get("treasure"):
		main.treasure.give_map("the %s's crew" % str(b.name))
		bits.append("a treasure map")
	main.save.shells = int(main.save.shells) + shells
	main.hud.set_shells(main.save.shells)
	e["earned"] = int(e.earned) + shells
	e["trips"] = int(e.trips) + 1
	var levelled: Array[String] = []
	for c in _crew_of(boat_id):
		c["xp"] = int(c.get("xp", 0)) + mins
		if int(c.skill) < 5 and int(c.xp) >= int(c.skill) * 120:
			c["xp"] = 0
			c["skill"] = int(c.skill) + 1
			levelled.append(str(c.name))
	b["trip"] = {}
	var line := "The %s came home with %s." % [b.name, ", ".join(bits)]
	(e.log as Array).push_front(line)
	while (e.log as Array).size() > 12:
		(e.log as Array).pop_back()
	main.audio.play("coin", -2.0)
	main.audio.play("jackpot", -6.0)
	_say(line + ("  %s got better at the job!" % " and ".join(levelled) if not levelled.is_empty() else ""))
	if _boat_nodes.has(boat_id):
		(_boat_nodes[boat_id] as Node3D).visible = true
	_place_crew()
	_check_rank()
	SaveGame.write(main.save)
	_show_tab(0)


func _buy_boat(kind: String) -> void:
	var e := E()
	var info: Dictionary = Boats.boat_info(kind)
	if (e.fleet as Array).size() >= berths():
		_say("No free berth. Build your dock out on the Harbour page.", false)
		return
	if int(main.save.shells) < int(info.price):
		_say("You need %d more Shells." % (int(info.price) - int(main.save.shells)), false)
		return
	main.save.shells = int(main.save.shells) - int(info.price)
	main.hud.set_shells(main.save.shells)
	var used: Array = []
	for b in e.fleet:
		used.append(str(b.name))
	var nm := ""
	for n in BOAT_NAMES:
		if not used.has(n):
			nm = n
			break
	if nm == "":
		nm = "Boat %d" % int(e.next_id)
	var paints: Array = Boats.PAINT
	(e.fleet as Array).append({"id": int(e.next_id), "kind": kind, "name": nm, "paint": paints[_rng.randi() % paints.size()], "trip": {}})
	e["next_id"] = int(e.next_id) + 1
	_place_boats()
	_check_rank()
	SaveGame.write(main.save)
	_say("The %s (a %s) is yours, moored at your dock. Hire a crew and send her out!" % [nm, str(info.n).to_lower()])
	_show_tab(0)


func _hire(skill: int, price: int) -> void:
	var e := E()
	if (e.crew as Array).size() >= bunks():
		_say("No bunks free. Build a bigger bunkhouse on the Harbour page.", false)
		return
	if int(main.save.shells) < price:
		_say("You need %d more Shells." % (price - int(main.save.shells)), false)
		return
	main.save.shells = int(main.save.shells) - price
	main.hud.set_shells(main.save.shells)
	e["spent"] = int(e.spent) + price / 2
	var c := {"id": int(e.next_id), "name": "%s %s" % [FIRST[_rng.randi() % FIRST.size()], LAST[_rng.randi() % LAST.size()]],
		"skill": skill, "xp": 0, "boat": -1, "look": _random_look()}
	e["next_id"] = int(e.next_id) + 1
	(e.crew as Array).append(c)
	_place_crew()
	_check_rank()
	SaveGame.write(main.save)
	_say("%s signs on. They're waiting on your jetty." % str(c.name))
	_show_tab(1)


func _train(crew_id: int) -> void:
	for c in E().crew:
		if int(c.id) == crew_id:
			var cost := int(c.skill) * 600
			if int(main.save.shells) < cost:
				_say("You need %d more Shells." % (cost - int(main.save.shells)), false)
				return
			main.save.shells = int(main.save.shells) - cost
			main.hud.set_shells(main.save.shells)
			c["skill"] = int(c.skill) + 1
			E()["spent"] = int(E().spent) + cost / 2
			_say("%s's had a season with old Marlo. Skill %d now." % [c.name, int(c.skill)])
			SaveGame.write(main.save)
			_show_tab(1)
			return


func _random_look() -> Dictionary:
	var hats := ["", "beanie", "cap", "bucket", "straw", "bandana", "captain"]
	var styles := ["short", "bob", "long", "ponytail", "bun", "spiky", "bald"]
	var tops := ["tee", "coat", "vest", "overalls", "apron"]
	var colours := ["#c84a3a", "#3a6ab0", "#e8b23a", "#5f8f5a", "#8a5ac8", "#2f8a8a", "#e8e2d0", "#3a3a40", "#d8783a"]
	var hairs := ["#2a1a10", "#6a4028", "#c8a060", "#e8d8b0", "#8a3a20", "#3a3a3a", "#d0d0d0"]
	return {"skin": Character.SKIN_ORDER[_rng.randi() % Character.SKIN_ORDER.size()], "hair": hairs[_rng.randi() % hairs.size()],
		"style": styles[_rng.randi() % styles.size()], "hat": hats[_rng.randi() % hats.size()],
		"hatc": colours[_rng.randi() % colours.size()], "shirt": colours[_rng.randi() % colours.size()],
		"top": tops[_rng.randi() % tops.size()], "garment": colours[_rng.randi() % colours.size()],
		"pants": ["#2e3f6e", "#3a3a40", "#5a4a3a", "#4a5a3a"][_rng.randi() % 4]}


func _cost(price: int, mats: Dictionary) -> String:
	var parts: Array[String] = []
	if price > 0:
		parts.append("%d Shells" % price)
	for k in mats:
		parts.append("%d %s" % [int(mats[k]), k])
	return ", ".join(parts) if not parts.is_empty() else "Free"


func _short(price: int, mats: Dictionary) -> String:
	var need: Array[String] = []
	if int(main.save.shells) < price:
		need.append("%d Shells" % (price - int(main.save.shells)))
	var have: Dictionary = main.save.get("materials", {})
	for k in mats:
		var gap := int(mats[k]) - int(have.get(k, 0))
		if gap > 0:
			need.append("%d %s" % [gap, k])
	return "" if need.is_empty() else "You need %s more." % " and ".join(need)


func _build(key: String, lvl: int) -> void:
	var table: Array = {"dock": DOCK, "bunks": BUNKS, "smoke": SMOKE}[key]
	var nx: Dictionary = table[lvl]
	var short := _short(int(nx.price), nx.mats)
	if short != "":
		_say(short, false)
		return
	main.save.shells = int(main.save.shells) - int(nx.price)
	var have: Dictionary = main.save.materials
	for k in nx.mats:
		have[k] = int(have.get(k, 0)) - int(nx.mats[k])
	main.hud.set_shells(main.save.shells)
	if main.hud.has_method("set_materials"):
		main.hud.set_materials(have)
	E()[key] = lvl
	E()["spent"] = int(E().spent) + int(nx.price)
	if key == "dock":
		rebuild()
	_check_rank()
	SaveGame.write(main.save)
	main.audio.play("fanfare1", -4.0)
	_say("Built: %s! %s" % [nx.n, nx.d])
	_show_tab(2)


func journal_lines() -> Array[String]:
	var e := E()
	var out: Array[String] = ["%s: %d boats, %d crew, %d Shells earned by your crews." % [rank_name(), (e.fleet as Array).size(),
		(e.crew as Array).size(), int(e.earned)]]
	var t := now()
	for b in e.fleet:
		var trip: Dictionary = b.get("trip", {})
		if not trip.is_empty():
			out.append("The %s: %s" % [b.name, "back, waiting to unload" if t >= int(trip.end) else "back in " + _clock(int(trip.end) - t)])
	if e.fleet.is_empty():
		out.append("The ledger board on your jetty, by Gran's hut, starts a fleet of your own.")
	return out
