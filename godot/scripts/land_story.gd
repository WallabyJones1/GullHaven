extends Node3D
## Harbour Life: a second story that runs beside the Gull's Eye, all on land. Gran didn't
## only fish: she kept the best garden on the coast and ran the Tideday Fair, the spring
## fair the whole coast came to, until she got too frail and it faded away. Farmer Bramble,
## Delve the smith and Ash the hunter help you bring it back: grow, gather, mine, hunt,
## craft and cook your way to the Fair's return. Its next step shows in green under the
## main story's, with a green beam of light where it wants you.
## It also opens the map without fishing: Ash vouches for you with the ranger, and the
## harbourmaster accepts a full Field Notes in place of a full Logbook.

const SaveGame := preload("res://scripts/save_game.gd")
const Furniture := preload("res://scripts/furniture.gd")
const D := preload("res://scripts/land_data.gd")
const Boats := preload("res://scripts/boats.gd")

const BRAMBLE := "Farmer Bramble"
const DELVE := "Delve"
const ASH := "Ash"
const GARDEN := [419.0, 685.0]
const BENCH := [427.0, 683.0]
const POT := [427.5, 687.0]
const POINT := [430.0, 700.0]
const HILLS := [300.0, 205.0]
const HIGH := [225.0, 150.0]
const EMBER := [1066.0, 872.0]
const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]

# Steps: goal (the corner text), t (what finishes it), at (where). Types:
# talk (who, lines, gift), give (who, items, lines, gift), event (ev, what, n),
# have (item, n), flag (land flag), permit (id), visit (place).
const CHAPTERS := [
	{"name": "Gran's Garden", "reward": {"xp": 150, "shells": 120}, "steps": [
		{"goal": "Meet Farmer Bramble by Gran's garden, beside the hut", "t": "talk", "who": BRAMBLE, "at": BRAMBLE,
			"gift": {"tool:hoe": 1, "tool:can": 1, "seed_turnip": 4}, "lines": [
			"Well, I'll be. You've your gran's eyes! I'm Bramble. I kept her garden ticking over after her knees gave out.",
			"She'd want it growing again, and so would I. Here's her hoe, her old watering can and a packet of turnip seeds.",
			"Face a bed and dig it over with {action}. Plant the seeds, then give them a drink. Rain does it for you, if the sky's kind.",
			"Turnips are quick: six minutes of watered growing and they're up. Everything grows faster in that soil of hers."]},
		{"goal": "Dig over one of Gran's garden beds", "t": "event", "ev": "till", "n": 1, "at": GARDEN},
		{"goal": "Plant your turnip seeds", "t": "event", "ev": "plant", "what": "turnip", "n": 1, "at": GARDEN},
		{"goal": "Water the turnips", "t": "event", "ev": "water", "n": 1, "at": GARDEN},
		{"goal": "Tell Farmer Bramble they're in", "t": "talk", "who": BRAMBLE, "at": BRAMBLE, "gift": {"tool:axe": 1}, "lines": [
			"Good. Now, while those grow, let's get you some firewood. Here's Gran's stone axe. Still sharp, if you don't mind the moss.",
			"Any tree will give you a bundle of wood once a day. Trees here grow back quicker than gossip.",
			"And keep your eyes open: blackberries on the brambles, herbs among the ferns, mushrooms in the woods. The coast's a larder."]},
		{"goal": "Chop wood from 3 trees", "t": "event", "ev": "chop", "n": 3},
		{"goal": "Gather 3 wild things: berries, herbs, flowers or mushrooms", "t": "event", "ev": "forage", "n": 3},
		{"goal": "Harvest your turnips when they're ready", "t": "event", "ev": "harvest", "what": "turnip", "n": 1, "at": GARDEN},
		{"goal": "Bring Farmer Bramble 2 turnips", "t": "give", "who": BRAMBLE, "at": BRAMBLE, "items": {"turnip": 2}, "lines": [
			"Would you look at those. Gran's turnips, back again. I could weep. I won't, but I could.",
			"You know, she'd have put these in the Tideday Fair. Every spring the whole coast came to Gullhaven for it.",
			"Produce and pies, Delve's ironwork, Ash's furs, music on the quay till midnight. Your gran ran it for forty years.",
			"When she got too frail, nobody took it on. The stalls rotted. I've still got her box of prize ribbons.",
			"If anyone could bring the Fair back, it's her grandchild. Start with her workbench, out in the yard. It's seen better days."]},
	]},
	{"name": "Gran's Workbench", "reward": {"xp": 250, "shells": 200}, "steps": [
		{"goal": "Pick up 4 stones from the little rocks round the coast", "t": "event", "ev": "gather", "what": "stone", "n": 4},
		{"goal": "Fix Gran's workbench in the yard (6 wood, 4 stone)", "t": "flag", "flag": "bench_fixed", "at": BENCH},
		{"goal": "Make a stone pickaxe at the workbench", "t": "event", "ev": "craft", "what": "pick_stone", "n": 1, "at": BENCH},
		{"goal": "Mine 2 copper ore in the rocks south of the hut", "t": "event", "ev": "mine", "what": "copper_ore", "n": 2, "at": POINT},
		{"goal": "Cook a vegetable stew at the pot in the yard (2 turnips, 1 wild herbs)", "t": "event", "ev": "cook", "what": "veg_stew", "n": 1, "at": POT},
		{"goal": "Show Farmer Bramble what you've made", "t": "talk", "who": BRAMBLE, "at": BRAMBLE, "gift": {"seed_wheat": 4, "seed_carrot": 3}, "lines": [
			"Is that stew? It smells like Gran's kitchen on a Sunday.",
			"Take it to Delve, the smith up in Willowford. Her forge made every lantern and hinge for the Fair, and it's been cold for years.",
			"She hasn't eaten a proper meal since, if you ask me. Which nobody does.",
			"The estuary bridge is still out, mind. Tess the carpenter can mend it with wood and rope. You can twist wheat straw into twine for rope; have some seeds."]},
	]},
	{"name": "Up the River Road", "reward": {"xp": 400, "shells": 300}, "steps": [
		{"goal": "Grow wheat and harvest it", "t": "event", "ev": "harvest", "what": "wheat", "n": 1, "at": GARDEN},
		{"goal": "Twist wheat into twine at the workbench", "t": "event", "ev": "craft", "what": "twine", "n": 1, "at": BENCH},
		{"goal": "Help Tess mend the estuary bridge (wood, rope and Shells; twine makes rope at the workbench)", "t": "permit", "id": "bridge", "at": "Tess"},
		{"goal": "Walk up the river road to Willowford", "t": "visit", "place": "Willowford", "at": [326.0, 240.0]},
		{"goal": "Take a vegetable stew to Delve the smith in Willowford", "t": "give", "who": DELVE, "at": DELVE, "items": {"veg_stew": 1},
			"gift": {"tool:pick": 2}, "lines": [
			"Stew? For me? ...Bramble sent you. Of course he did.",
			"I'm Delve. My grandmother forged the Fair's great bell, and I made every lantern on the quay. Then the Fair stopped, and so did I.",
			"Here: my old copper pickaxe. It'll crack iron veins, which that stone thing of yours won't.",
			"If you want my forge lit again, bring me iron. Coal and iron ore are thick in the hills behind the mill."]},
		{"goal": "Mine 3 coal in the Willowford hills", "t": "event", "ev": "mine", "what": "coal", "n": 3, "at": HILLS},
		{"goal": "Mine 6 iron ore in the Willowford hills", "t": "event", "ev": "mine", "what": "iron_ore", "n": 6, "at": HILLS},
		{"goal": "Smelt 2 iron bars at Gran's workbench (3 iron ore and 1 coal each)", "t": "event", "ev": "craft", "what": "iron_bar", "n": 2, "at": BENCH},
		{"goal": "Bring Delve 2 iron bars", "t": "give", "who": DELVE, "at": DELVE, "items": {"iron_bar": 2}, "lines": [
			"Now that's iron. Listen to it ring.",
			"The forge is lit. I'll start on a new bell for the Fair, a proper one.",
			"Do something for me? Ash, out past the ranger's station, has been grumbling about boar in the fields. Go and see her."]},
	]},
	{"name": "Trouble in the Fields", "reward": {"xp": 600, "shells": 400}, "steps": [
		{"goal": "Find Ash the hunter in Willowford", "t": "talk", "who": ASH, "at": ASH, "gift": {"tool:bow": 1, "arrows": 15}, "lines": [
			"Delve said you'd come. Good. Boar have been rooting up every field from here to the mill, and rabbits are eating Bramble's carrots.",
			"Here's a bow and a quiver. Face what you're after and press {action} to draw.",
			"Then {action} again when the gold line sits in the green. Close in quietly: run at them and they bolt.",
			"Rabbits and pheasants out in the grass, boar in the woods, ducks by the river. The deer stay up in the high country."]},
		{"goal": "Hunt 2 rabbits in the grassland", "t": "event", "ev": "hunt", "what": "rabbit", "n": 2},
		{"goal": "Hunt a wild boar in the woods", "t": "event", "ev": "hunt", "what": "boar", "n": 1},
		{"goal": "Bring Ash 2 hides", "t": "give", "who": ASH, "at": ASH, "items": {"hide": 2}, "flag": "ash_vouched", "lines": [
			"Clean work. I'll tan these for the Fair's stall awnings, like the old days.",
			"You've a good eye and a quiet step. I'll have a word with Hollis at the ranger's station.",
			"She'll let you into the high country on my say-so. The deer up there are worth the climb."]},
		{"goal": "Get the ranger's permit from Ranger Hollis (Ash has vouched for you)", "t": "permit", "id": "permit_ranger", "at": "Ranger Hollis"},
	]},
	{"name": "High Country", "reward": {"xp": 900, "shells": 600}, "steps": [
		{"goal": "Hunt a red deer in the highlands past the ranger's gate", "t": "event", "ev": "hunt", "what": "deer", "n": 1, "at": HIGH},
		{"goal": "Make an iron pickaxe at Gran's workbench (3 iron bars)", "t": "event", "ev": "craft", "what": "pick_iron", "n": 1, "at": BENCH},
		{"goal": "Mine 3 silver ore in the highlands", "t": "event", "ev": "mine", "what": "silver_ore", "n": 3, "at": HIGH},
		{"goal": "Get Ember Isle's landing permit from Harbourmaster Quill (a full Field Notes will do)", "t": "permit", "id": "permit_ember", "at": "Harbourmaster Quill"},
		{"goal": "Mine an ember crystal on Ember Isle (you'll want a Skiff to get there)", "t": "event", "ev": "mine", "what": "ember_crystal", "n": 1, "at": EMBER},
		{"goal": "Make an ember lantern at Gran's workbench", "t": "event", "ev": "craft", "what": "ember_lantern", "n": 1, "at": BENCH},
	]},
	{"name": "The Tideday Fair", "reward": {"xp": 2000, "shells": 3000}, "steps": [
		{"goal": "Grow a prize pumpkin (Bramble sells the seeds)", "t": "have", "item": "pumpkin", "n": 1, "at": GARDEN},
		{"goal": "Bake a blackberry pie at the pot", "t": "have", "item": "berry_pie", "n": 1, "at": POT},
		{"goal": "Cook a roast dinner at the pot", "t": "have", "item": "roast_dinner", "n": 1, "at": POT},
		{"goal": "Bring Farmer Bramble the pumpkin, the pie, the roast and the ember lantern", "t": "give", "who": BRAMBLE, "at": BRAMBLE,
			"items": {"pumpkin": 1, "berry_pie": 1, "roast_dinner": 1, "ember_lantern": 1},
			"gift": {"furniture:rocking_chair": 1, "furniture:pumpkin_lantern": 1}, "lines": [
			"Oh, would you look at all this. A pumpkin like a harvest moon. A pie. A roast. And that lantern, it's like a little sun.",
			"Delve's bell is hung. Ash's awnings are up. Tess built the stalls new. Half the coast already knows.",
			"Here: Gran's rocking chair, and her pumpkin lantern. She'd want them by your fire.",
			"The Tideday Fair is back, and it's yours now, like the hut and the garden. She'd be so proud. I know I am."]},
	]},
]
const END := ["The Tideday Fair is back! Lanterns along the quay, music till midnight, and Gran's ribbons on your stall.",
	"The garden, the forge, the hills and the hunt are all yours to enjoy. Bramble, Delve and Ash will always buy what you bring."]

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var land: Node3D
var dialogue: CanvasLayer
var progress: Node
var interiors: Node3D
var _beacon: Node3D
var _poll := 0.0
var _busy := false


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node, l: Node3D) -> void:
	world = w
	player = p
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	land = l
	_build_beacon()


func start() -> void:
	town.talk_hooks.insert(mini(1, town.talk_hooks.size()), on_talk)  # after the main story's
	land.land_event.connect(_on_event)
	for i in 40:  # older saves: skip what's already done
		var s := current()
		if s.is_empty() or str(s.t) in ["talk", "give", "event"] or not _met(s):
			break
		_complete(true)
	_refresh()


func _st() -> Dictionary:
	return save.land_story


func chapter() -> int:
	return int(_st().get("ch", 0))


func step_i() -> int:
	return int(_st().get("step", 0))


func finished() -> bool:
	return chapter() >= CHAPTERS.size()


func current() -> Dictionary:
	if finished():
		return {}
	var steps: Array = CHAPTERS[chapter()].steps
	return steps[clampi(step_i(), 0, steps.size() - 1)]


func on_talk(who: String) -> bool:
	var s := current()
	if s.is_empty() or str(s.get("who", "")) != who:
		return false
	if str(s.t) == "talk":
		_busy = true
		town.talk(who, s.lines, [], _talked)
		return true
	if str(s.t) == "give":
		var missing: Array[String] = []
		var items: Dictionary = s.items
		for id in items:
			var gap := int(items[id]) - int(land.count(str(id)))
			if gap > 0:
				missing.append("%d %s" % [gap, D.item_name(str(id)).to_lower()])
		if not missing.is_empty():
			hud.toast("%s is waiting on %s more." % [who, " and ".join(missing)])
			return false  # their stall still opens
		for id in items:
			land.take(str(id), int(items[id]))
		if s.has("flag"):
			land.set_flag(str(s.flag))
		_busy = true
		town.talk(who, s.lines, [], _talked)
		return true
	return false


func _talked(_c: int) -> void:
	_busy = false
	_complete()


func _on_event(kind: String, what: String, n: int) -> void:
	var s := current()
	if s.is_empty() or str(s.t) != "event" or str(s.ev) != kind:
		return
	if s.has("what") and str(s.what) != what:
		return
	_st()["count"] = int(_st().get("count", 0)) + n
	if int(_st().count) >= int(s.n):
		_complete()
	else:
		_refresh()


func _met(s: Dictionary) -> bool:
	match str(s.t):
		"have":
			return int(land.count(str(s.item))) >= int(s.n)
		"flag":
			return bool(land.flag(str(s.flag)))
		"permit":
			return (save.permits as Dictionary).has(str(s.id))
		"visit":
			return (save.visited as Dictionary).has(str(s.place))
	return false


func _process(delta: float) -> void:
	_update_beacon()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	if finished() or _busy or dialogue.is_open:
		_refresh()
		return
	var s := current()
	if not s.is_empty() and str(s.t) in ["have", "flag", "permit", "visit"] and _met(s):
		_complete()
	else:
		_refresh()


func _give(gift: Dictionary) -> void:
	for k in gift:
		var key := str(k)
		var n := int(gift[k])
		if key.begins_with("tool:"):
			land.set_tool(key.substr(5), n)
		elif key.begins_with("furniture:"):
			Furniture.give(save, key.substr(10), n)
		elif key == "shells":
			save.shells = int(save.shells) + n
			hud.set_shells(save.shells)
		else:
			land.add_item(key, n)


func _complete(quiet := false) -> void:
	var s := current()
	if s.is_empty():
		return
	if s.has("gift"):
		_give(s.gift)
	if not quiet:
		audio.play("good", -4.0)
		progress.add(20 + 10 * chapter())
	_st()["count"] = 0
	_st()["step"] = step_i() + 1
	var steps: Array = CHAPTERS[chapter()].steps
	if step_i() >= steps.size():
		var done_ch: Dictionary = CHAPTERS[chapter()]
		_st()["ch"] = chapter() + 1
		_st()["step"] = 0
		if not quiet:
			var reward: Dictionary = done_ch.reward
			save.shells = int(save.shells) + int(reward.shells)
			hud.set_shells(save.shells)
			progress.add(int(reward.xp), "Harbour Life: %s" % str(done_ch.name))
			audio.play("fanfare2")
			if finished():
				hud.show_banner("The Tideday Fair returns!", "Harbour Life is complete")
				dialogue.say("The Tideday Fair", END)
			else:
				hud.show_banner("Harbour Life", str(CHAPTERS[chapter()].name))
	SaveGame.write(save)
	_refresh()


func _goal_text(s: Dictionary) -> String:
	var g := str(s.goal)
	match str(s.t):
		"event":
			if int(s.n) > 1:
				g += " (%d/%d)" % [mini(int(_st().get("count", 0)), int(s.n)), int(s.n)]
		"have":
			g += " (%d/%d)" % [mini(int(land.count(str(s.item))), int(s.n)), int(s.n)]
		"give":
			var parts: Array[String] = []
			var items: Dictionary = s.items
			if items.size() > 1:
				for id in items:
					parts.append("%s %d/%d" % [D.item_name(str(id)), mini(int(land.count(str(id))), int(items[id])), int(items[id])])
				g += "\n" + ", ".join(parts)
	return g


func _refresh() -> void:
	if finished():
		hud.set_objective2("", "")
		return
	var s := current()
	var text := _goal_text(s)
	var at := target()
	if at != Vector3.INF and not interiors.is_inside():
		var to := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
		if to.length() > 12.0:
			var i := posmod(int(round(atan2(to.x, -to.y) / (PI * 0.25))), 8)
			text += "\n%d m %s" % [int(to.length()), DIRS[i]]
	hud.set_objective2("Harbour Life: %s" % str(CHAPTERS[chapter()].name), text)


func target() -> Vector3:
	var s := current()
	if s.is_empty() or not s.has("at"):
		return Vector3.INF
	var at: Variant = s.at
	if at is String:
		if not world.folk.has(at):
			return Vector3.INF
		var node: Sprite3D = world.folk[at].node
		return node.global_position
	var arr: Array = at
	var x := float(arr[0])
	var z := float(arr[1])
	return Vector3(x, float(world.height_at(x, z)), z)


func summary() -> String:
	if finished():
		return "The Tideday Fair is back"
	return "Harbour Life: %s" % str(CHAPTERS[chapter()].name)


func journal_lines() -> Array[String]:
	var out: Array[String] = []
	for i in mini(chapter() + 1, CHAPTERS.size()):
		var ch: Dictionary = CHAPTERS[i]
		var done := i < chapter()
		out.append("%s  %s" % ["[color=#8ad08a]Done[/color]" if done else "[color=#ffd24d]Now[/color]", str(ch.name)])
	if finished():
		out.append("[color=#8ad08a]The Tideday Fair is back.[/color]")
	else:
		out.append("Next: " + _goal_text(current()).replace("\n", " "))
	return out


func _build_beacon() -> void:
	_beacon = Node3D.new()
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 30.0
	cyl.radial_segments = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position = Vector3(0.0, 15.0, 0.0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(0.45, 1.0, 0.55, 0.2)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(beam)
	_beacon.visible = false
	add_child(_beacon)


func _update_beacon() -> void:
	var at := target()
	if at == Vector3.INF or interiors.is_inside() or finished():
		_beacon.visible = false
		return
	var d := Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()
	_beacon.visible = d > 3.5
	_beacon.global_position = at
