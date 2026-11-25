extends Node3D
## Treasure hunts. Treasure maps come from Pip on the beach by Gran's hut (one a day: the
## daily map, the same for everyone in the shared town), and from driving off sea monsters.
## A map marks a red ring on the world map somewhere round the coast or out on the islands;
## the corner says how far and which way, then warmer, warmer, hot. Stand on the spot and
## dig with your hoe for a chest: Shells, gems, gold, something for your garden or your home.

const SaveGame := preload("res://scripts/save_game.gd")
const Homes := preload("res://scripts/token/homes.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Plots := preload("res://scripts/plots.gd")
const Models := preload("res://scripts/models.gd")
const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
const PLACES := [
	{"n": "the beach south of Gran's hut", "x": 438.0, "z": 705.0, "r": 26.0},
	{"n": "the dunes north of Gullhaven", "x": 455.0, "z": 470.0, "r": 30.0},
	{"n": "the mangrove estuary", "x": 470.0, "z": 385.0, "r": 26.0},
	{"n": "the woods round Willowford", "x": 330.0, "z": 275.0, "r": 30.0},
	{"n": "Tideglass Cay", "isle": "tideglass"},
	{"n": "Gull Rock", "isle": "gullrock"},
	{"n": "Mossbank", "isle": "mossbank"},
	{"n": "Kelpwood", "isle": "kelpwood"},
	{"n": "Lantern Key", "isle": "lantern"},
	{"n": "Wrecker's Cove", "isle": "cove"},
	{"n": "Ember Isle", "isle": "ember", "needs": "permit_ember"},
	{"n": "Mirrorlake's shore", "x": 160.0, "z": 165.0, "r": 26.0, "needs": "permit_ranger"},
]
const GARDEN_LOOT := ["well", "umbrella", "gnome", "anchor", "lamppost", "birdbath", "palm"]

var main: Node
var _chest: Node3D
var _chest_t := 0.0
var _hud_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(m: Node) -> void:
	main = m
	_rng.randomize()
	if not main.save.has("treasure") or not (main.save.treasure is Dictionary):
		main.save["treasure"] = {}
	var t: Dictionary = main.save.treasure
	for k in [["maps", []], ["dug", 0], ["daily", -1]]:
		if not t.has(k[0]):
			t[k[0]] = k[1]
	main.town.talk_hooks.insert(0, _on_talk)
	main.town.providers.append(self)
	_refresh_pins()


func _T() -> Dictionary:
	return main.save.treasure


func maps() -> Array:
	return _T().maps


## A new map, from somewhere round the coast (seed: the same map for everyone that day).
func give_map(source: String, seed := -1, daily := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var world: Node3D = main.harbour
	var options: Array = []
	for pl: Dictionary in PLACES:
		if pl.has("needs") and not (main.save.permits as Dictionary).has(str(pl.needs)):
			continue
		options.append(pl)
	for attempt in 40:
		var pl: Dictionary = options[rng.randi() % options.size()]
		var cx := float(pl.get("x", 0.0))
		var cz := float(pl.get("z", 0.0))
		var r := float(pl.get("r", 20.0))
		if pl.has("isle"):
			for i in world.meta.islands:
				if str(i.id) == str(pl.isle):
					cx = float(i.x)
					cz = float(i.z)
					r = float(i.get("r", 20)) if i.get("r") != null else 20.0
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		if world.is_water(x, z) or float(world.height_at(x, z)) < float(world.sea_level) + 0.35:
			continue
		if not world.walkable(x, z) or world.flags_at(x, z) & int(world.F.town):
			continue
		var ring := 18.0
		var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.0, ring * 0.6)
		var mp := {"x": x, "z": z, "cx": x + off.x, "cz": z + off.y, "r": ring, "where": str(pl.n), "from": source, "daily": daily}
		(_T().maps as Array).append(mp)
		_refresh_pins()
		main.audio.play("pin", -2.0)
		main.hud.toast("A treasure map! X marks a spot on %s. It's on your map (%s)." % [str(pl.n), Glyphs.key("map")])
		SaveGame.write(main.save)
		return mp
	return {}


func _today() -> int:
	return int(floor(main.sea.now() / 1440.0))


## Pip finds a map in a bottle every day.
func _on_talk(who: String) -> bool:
	if who != "Pip" or int(_T().daily) == _today():
		return false
	_T()["daily"] = _today()
	main.town.talk(who, ["Look what washed up in a bottle! A treasure map!", "It's today's map. Everyone in town's after it. Go on, you dig it up!"], [], _daily)
	return true


func _daily(_c: int) -> void:
	give_map("Pip's bottle", _today() * 7907 + 31, true)


func _refresh_pins() -> void:
	var pins: Array = []
	for mp in maps():
		pins.append({"x": float(mp.cx), "z": float(mp.cz), "r": float(mp.r)})
	if main.map_screen:
		main.map_screen.treasure_pins = pins


func _nearest() -> Dictionary:
	var p: Vector3 = main.player.global_position
	var best := {}
	var best_d := INF
	for mp in maps():
		var d := Vector2(float(mp.x) - p.x, float(mp.z) - p.z).length()
		if d < best_d:
			best_d = d
			best = mp
	return best


func _process(delta: float) -> void:
	if _chest:
		_chest_t -= delta
		if _chest_t <= 0.0:
			_chest.queue_free()
			_chest = null
	_hud_t -= delta
	if _hud_t > 0.0:
		return
	_hud_t = 0.5
	var mp := _nearest()
	if mp.is_empty() or main.interiors.is_inside():
		main.hud.set_treasure("")
		return
	var p: Vector3 = main.player.global_position
	var to := Vector2(float(mp.x) - p.x, float(mp.z) - p.z)
	var d := to.length()
	var text := ""
	if d > 40.0:
		var i := posmod(int(round(atan2(to.x, -to.y) / (PI * 0.25))), 8)
		text = "%s, about %d m %s" % [str(mp.where).capitalize(), int(round(d / 10.0) * 10.0), DIRS[i]]
	elif d > 18.0:
		text = "Warm... it's somewhere round here"
	elif d > 7.0:
		text = "Warmer! Very close now"
	elif d > 2.4:
		text = "Hot! You're almost standing on it"
	else:
		text = "Right here! Dig with %s" % Glyphs.key("action")
	main.hud.set_treasure("Treasure map (%d)   %s" % [maps().size(), text])


func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	var mp := _nearest()
	if mp.is_empty():
		return {}
	var d := Vector2(float(mp.x) - pos.x, float(mp.z) - pos.z).length()
	if d > 2.4:
		return {}
	var text := "Space: Dig for treasure" if int(main.land.tool_tier("hoe")) > 0 else "Treasure's buried here (dig with a hoe from Farmer Bramble)"
	return {"kind": "dig", "map": mp, "dist": d, "text": text}


func use(it: Dictionary) -> void:
	if int(main.land.tool_tier("hoe")) <= 0:
		main.hud.toast("You need something to dig with. Farmer Bramble sells hoes, by Gran's hut.")
		main.audio.play("error", -6.0)
		return
	var mp: Dictionary = it.map
	maps().erase(mp)
	_T()["dug"] = int(_T().dug) + 1
	_refresh_pins()
	main.audio.play("step_sand", 0.0, 0.8)
	main.audio.play("jackpot", -4.0)
	var at := Vector3(float(mp.x), float(main.harbour.height_at(float(mp.x), float(mp.z))), float(mp.z))
	if _chest:
		_chest.queue_free()
	_chest = Models.make("sea", "chest_open")
	add_child(_chest)
	_chest.global_position = at + Vector3(0.0, -0.05, 0.0)
	_chest.scale = Vector3.ONE * 1.2
	_chest_t = 8.0
	var parts: Array[String] = []
	var shells := _rng.randi_range(300, 1500) * (2 if bool(mp.get("daily", false)) else 1)
	main.save.shells = int(main.save.shells) + shells
	main.hud.set_shells(main.save.shells)
	parts.append("%d Shells" % shells)
	var roll := _rng.randf()
	if roll < 0.3:
		var gem: String = ["quartz", "amethyst", "ember_crystal", "gold_bar"][_rng.randi() % 4]
		parts.append(str(main.land.add_item(gem, 1)).trim_prefix("+"))
	elif roll < 0.65:
		var g: String = GARDEN_LOOT[_rng.randi() % GARDEN_LOOT.size()]
		var inv: Dictionary = main.save.plot.get("inv", {})
		inv[g] = int(inv.get(g, 0)) + 1
		main.save.plot["inv"] = inv
		parts.append("a %s for your garden" % str(Plots.OUTDOOR[g].n).to_lower())
	else:
		var ids: Array = Homes.all_ids()
		if not ids.is_empty():
			var id := str(ids[_rng.randi() % ids.size()])
			var fi: Dictionary = main.save.furniture_inv
			fi[id] = int(fi.get(id, 0)) + 1
			parts.append("a %s for your home" % str(Homes.data(id).get("n", "piece of furniture")).to_lower())
	main.progress.add(80, "treasure")
	main.hud.show_banner("Treasure!", ", ".join(parts))
	if bool(mp.get("daily", false)) and main.online and main.online.is_online():
		main.online.announce("dug up today's treasure on %s!" % str(mp.where))
	SaveGame.write(main.save)


func journal_lines() -> Array[String]:
	var out: Array[String] = []
	out.append("Treasure chests dug up: %d" % int(_T().dug))
	for mp in maps():
		out.append("A map (from %s): X marks a spot on %s" % [str(mp.from), str(mp.where)])
	if int(_T().daily) != _today():
		out.append("Pip, on the beach by Gran's hut, has today's treasure map.")
	return out
