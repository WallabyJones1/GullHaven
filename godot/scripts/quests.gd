extends Node
## The unlocks that open up the map:
## - The estuary bridge: Tess the carpenter mends it once you bring the timber and rope
##   (her "Projects" tab), joining Gullhaven to Willowford on foot.
## - The ranger's permit: Ranger Hollis in Willowford opens the gate to the highlands and
##   Mirrorlake once you've shown you know the river (four kinds of estuary fish).
## - The Ember Isle permit: Harbourmaster Quill lets seasoned fishers (30 kinds of fish and a
##   Skiff or bigger) land on the volcano.

const SaveGame := preload("res://scripts/save_game.gd")
const Furniture := preload("res://scripts/furniture.gd")
const Boats := preload("res://scripts/boats.gd")

const BRIDGE := {"price": 400, "mats": {"wood": 30, "rope": 8}}
const RANGER := {"price": 200, "fish": 4, "zone": "estuary"}
const EMBER := {"price": 1500, "species": 30, "tier": 3}

var world: Node3D
var town: Node
var progress: Node  # fisher XP
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary


func setup(w: Node3D, t: Node, h: CanvasLayer, a: Node, s: Node, sv: Dictionary) -> void:
	world = w
	town = t
	hud = h
	audio = a
	sea = s
	save = sv
	town.register_service("ranger", _ranger)
	town.register_service("harbourmaster", _harbourmaster)


func has(permit: String) -> bool:
	var permits: Dictionary = save.permits
	return permits.has(permit)


func grant(permit: String) -> void:
	var permits: Dictionary = save.permits
	permits[permit] = true
	SaveGame.write(save)
	audio.play("fanfare2")
	match permit:
		"bridge":
			world.rebuild_bridge()
		_:
			world.rebuild_gates()


# --- the bridge (offered through the carpenter's Projects tab) -----------------------

func bridge_status() -> String:
	if has("bridge"):
		return "Done"
	return Furniture.cost_text(int(BRIDGE.price), BRIDGE.mats)


func mend_bridge() -> String:
	if has("bridge"):
		return ""
	var short := Furniture.short_of(save, int(BRIDGE.price), BRIDGE.mats)
	if short != "":
		return short
	Furniture.pay(save, int(BRIDGE.price), BRIDGE.mats)
	grant("bridge")
	hud.set_materials(save.materials)
	hud.toast("The estuary bridge is mended! You can walk north to Willowford now.")
	return ""


# --- the ranger ---------------------------------------------------------------------

func _count_zone(zone: String) -> int:
	var n := 0
	var book: Dictionary = save.log
	for id in book:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and (e.cat == "fish" or e.cat == "legend") and e.z == zone:
			n += 1
	return n


func _species() -> int:
	var n := 0
	var book: Dictionary = save.log
	for id in book:
		var e: Dictionary = sea.by_id.get(id, {})
		if not e.is_empty() and (e.cat == "fish" or e.cat == "legend"):
			n += 1
	return n


func _ranger(keeper: String, _title: String, _kind: String) -> void:
	if has("permit_ranger"):
		town.say(keeper, "The gate's open for you. Mirrorlake's up the north road past the falls. Mind the cliffs.")
		return
	var got := _count_zone(str(RANGER.zone))
	var need := int(RANGER.fish)
	if got < need:
		town.say(keeper, "The highlands are fragile country. Show me you know the river first: catch %d kinds of estuary fish (you've %d). Then the permit's yours for %d Shells." % [need, got, int(RANGER.price)])
		audio.play("pin", -6.0)
		return
	if int(save.shells) < int(RANGER.price):
		town.say(keeper, "You know your river fish, I'll give you that. The permit's %d Shells, though." % int(RANGER.price))
		return
	save.shells = int(save.shells) - int(RANGER.price)
	if progress:
		progress.add(100)
	hud.set_shells(save.shells)
	grant("permit_ranger")
	town.say(keeper, "Here's your permit. The gate up the north road is open. Mirrorlake's fish have never seen a hook!")
	hud.toast("Ranger's permit: the highlands and Mirrorlake are open.")


# --- the harbourmaster ------------------------------------------------------------------

func _harbourmaster(keeper: String, _title: String, _kind: String) -> void:
	if has("permit_ember"):
		town.say(keeper, "Ember Isle's yours to land on. The waters round it run warm; strange things bite there.")
		return
	var got := _species()
	var need := int(EMBER.species)
	var best_tier := 0
	var owned: Array = save.boats
	for k in owned:
		best_tier = maxi(best_tier, int(Boats.boat_info(str(k)).get("tier", 0)))
	if got < need or best_tier < int(EMBER.tier):
		var wants: Array[String] = []
		if got < need:
			wants.append("%d kinds of fish in your Logbook (you've %d)" % [need, got])
		if best_tier < int(EMBER.tier):
			wants.append("a Skiff or bigger to get you there")
		town.say(keeper, "Ember Isle's a live volcano. I only give permits to seasoned fishers: %s. And %d Shells for the paperwork." % [" and ".join(wants), int(EMBER.price)])
		audio.play("pin", -6.0)
		return
	if int(save.shells) < int(EMBER.price):
		town.say(keeper, "You've earned it. The permit's %d Shells." % int(EMBER.price))
		return
	save.shells = int(save.shells) - int(EMBER.price)
	if progress:
		progress.add(100)
	hud.set_shells(save.shells)
	grant("permit_ember")
	town.say(keeper, "Signed and stamped. You may land on Ember Isle. Bring back something remarkable.")
	hud.toast("Ember Isle permit: you can land on the volcano now.")
