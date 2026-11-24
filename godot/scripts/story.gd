extends Node3D
## The main story: a prologue and five chapters that walk you round the whole coast,
## following the Gull's Eye mystery. Old Marlo on the docks is your guide: he teaches you
## to fish, then sends notes by gull as each chapter opens and each new kind of fishing
## unlocks. The current step shows in the top-right corner with how far away it is, a
## beam of light marks the spot in the world, and a gold pin marks it on the map.

const SaveGame := preload("res://scripts/save_game.gd")
const Boats := preload("res://scripts/boats.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const MARLO := "Old Marlo"
const NOTE_FROM := "Old Marlo (a note, by gull)"
const LIGHTHOUSE := [510.0, 543.5]
const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]

# Each step: goal (the corner text), t (what finishes it), at (where: [x, z] or someone's
# name), and maybe lines (a conversation), done (lines when it's finished), gift.
const CHAPTERS := [
	{"title": "Prologue", "name": "Gran's Hut", "reward": {"xp": 100, "shells": 0}, "steps": [
		{"goal": "Find Old Marlo on the docks", "t": "talk", "who": MARLO, "at": MARLO, "lines": [
			"Well, look who it is. You've got your gran's chin. And her rod, I see.",
			"She asked me to keep an eye on you. So here's your first lesson: a fisher fishes.",
			"Stand at the edge of the dock, face the water and hold {action}. Let go near the top of the swing for a long cast.",
			"When the float dips and the \"!\" pops up, strike with {action}. Then hold {action} to reel, and ease off if the line gets tight.",
			"Bring me three fish. Any three. I'm not fussy, unlike the fish."]},
		{"goal": "Catch 3 fish off the docks", "t": "catch", "n": 3, "at": [462.0, 577.0]},
		{"goal": "Show Old Marlo your catch", "t": "talk", "who": MARLO, "at": MARLO, "gift": {"shells": 60}, "lines": [
			"Three! Your gran took a week to land three. Don't tell her I said that.",
			"Every fish pays you Shells and teaches you a thing or two. That's your fisher level, top left. The harder the fish, the more you learn.",
			"Bread dough's fine for tiddlers, but proper bait brings proper fish. Hale's Tackle is just up the quay. Get yourself some worms.",
			"Here, sixty Shells to get you started. Don't spend it all on sinkers."]},
		{"goal": "Buy some bait at Hale's Tackle", "t": "bait", "at": "Hale"},
		{"goal": "Put your new bait on with {bait}, then catch a fish with it", "t": "baitcatch", "at": [462.0, 577.0]},
		{"goal": "Tell Old Marlo how it went", "t": "talk", "who": MARLO, "at": MARLO, "lines": [
			"See? Different bait, different fish. Worms for whiting and bream, prawns and pilchards for the bigger mouths.",
			"Your Logbook ({logbook}) shows what bites where, and when. Townsfolk want fish too: their requests are up in the corner.",
			"And if Gran's old jacket isn't you, Odette at Threads & Tides, behind the tavern, sells clothes and hats.",
			"Now. Your gran's hut is out on the point, south of town past the beach. It's yours. Go and have a look."]},
		{"goal": "Go inside Gran's hut on the point", "t": "hut", "at": [420.0, 676.0], "gift": {"pot": 1},
			"done_who": "Gran's hut", "done": [
			"It smells of salt and pipe smoke. Gran's tide charts still cover one wall.",
			"On the table, a note in her hand: \"Make it your own. Press {build} in here to move things about; Tess the carpenter sells furniture.\"",
			"\"My old crab pot's by the door. Drop it in the water with {tool} and haul it up a few hours later. And ask Marlo about the lighthouse. He'll pretend he doesn't want to tell you.\""]},
		{"goal": "Drop Gran's crab pot in the water with {tool}", "t": "pot"},
		{"goal": "Ask Old Marlo about the lighthouse", "t": "talk", "who": MARLO, "at": MARLO, "lines": [
			"She sent you about the lighthouse, did she. Course she did.",
			"Fifty years back that light had a lens like nothing else: the Gull's Eye. Crystal out of the fire mountain. You could see it from the islands.",
			"Then one storm night the lamp went dark, and the keeper, Elias Marrow, was gone. So was the Eye.",
			"Folk say he stole it. I knew Elias. He'd sooner have stolen the sea.",
			"The old lighthouse is out on the breakwater. Nobody goes in there now. Nobody but nosy fishers, I expect."]},
	]},
	{"title": "Chapter 1", "name": "The Keeper's Light", "reward": {"xp": 300, "shells": 200}, "note": [], "steps": [
		{"goal": "Search the old lighthouse on the breakwater", "t": "mystery", "n": 1, "at": LIGHTHOUSE},
		{"goal": "Find the keeper's mark by the estuary bridge, and dig at its foot at low tide", "t": "mystery", "n": 2,
			"at": [460.0, 368.5]},
		{"goal": "Mend the estuary bridge: Tess the carpenter needs driftwood, rope and Shells", "t": "permit", "id": "bridge",
			"at": "Tess", "start": [
			"Heard you found one of Elias's marks. The next one will be up the river, I'd bet my boots.",
			"The bridge washed out in the spring storm. Tess can mend it if you bring her timber and rope.",
			"Driftwood piles up on the beaches. The junk you reel in comes apart for rope and scrap."]},
	]},
	{"title": "Chapter 2", "name": "Up the River", "reward": {"xp": 500, "shells": 300}, "note": [
		"The bridge is mended! Willowford's a pretty walk up the river road.",
		"Miller Ottie's dad was Elias's friend. The mill's where I'd look.",
		"You'll want a boat before long, too. Bosun Pell at the Boatyard will sort you out."], "steps": [
		{"goal": "Walk up the river to Willowford", "t": "visit", "place": "Willowford", "at": [326.0, 240.0]},
		{"goal": "Ring the Willowford mill's four bells in the keeper's lullaby", "t": "mystery", "n": 3, "at": [297.4, 233.4]},
		{"goal": "Buy a boat from Bosun Pell at the Boatyard (a Rowboat is 600 Shells)", "t": "boat", "tier": 1, "at": "Bosun Pell"},
		{"goal": "Row out to Gull Rock and turn its three stones", "t": "mystery", "n": 4, "at": [571.0, 477.0]},
	]},
	{"title": "Chapter 3", "name": "Fog and Lanterns", "reward": {"xp": 800, "shells": 500}, "note": [
		"Kelpwood! Now that's proper sailing. A rowboat won't get you past Gull Rock in that swell; you'll want a Dinghy.",
		"While you're saving up, look at Hale's Kit tab as your level grows: cast nets, trolling lines, even a speargun.",
		"And mind the fog round Kelpwood. A deck lamp from the Boatyard helps."], "steps": [
		{"goal": "Get a Dinghy (or bigger) from Bosun Pell", "t": "boat", "tier": 2, "at": "Bosun Pell"},
		{"goal": "Sail to Kelpwood and light its four lanterns in the sun's order", "t": "mystery", "n": 5, "at": [759.6, 637.6]},
		{"goal": "Get the ranger's permit from Ranger Hollis in Willowford", "t": "permit", "id": "permit_ranger", "at": "Ranger Hollis"},
		{"goal": "Catch Silverjaw on Mirrorlake at dawn, in calm weather", "t": "mystery", "n": 6, "at": [186.0, 104.0]},
	]},
	{"title": "Chapter 4", "name": "The Keeper's Chest", "reward": {"xp": 1200, "shells": 800}, "note": [
		"A key in a pike! Elias always did have a sense of humour.",
		"Lantern Key's a long way out, past the kelp. You'll need a Skiff for that crossing.",
		"Count carefully when you get there. Elias liked his riddles the way he liked his tea: stewed."], "steps": [
		{"goal": "Get a Skiff (or bigger) from Bosun Pell", "t": "boat", "tier": 3, "at": "Bosun Pell"},
		{"goal": "Open the keeper's chest on Lantern Key (it wants three numbers)", "t": "mystery", "n": 7, "at": [970.7, 554.7]},
		{"goal": "Get the Ember Isle landing permit from Harbourmaster Quill", "t": "permit", "id": "permit_ember", "at": "Harbourmaster Quill"},
		{"goal": "Find the warm cave behind the village on Ember Isle", "t": "mystery", "n": 8, "at": [1067.0, 872.4]},
	]},
	{"title": "Chapter 5", "name": "The Light Returns", "reward": {"xp": 3000, "shells": 2000}, "note": [
		"You found it. Elias, you stubborn old fool, you kept it safe all this time.",
		"Bring it home, fisher. Half the town's already waiting on the quay."], "steps": [
		{"goal": "Set the Gull's Eye in the lighthouse lamp", "t": "mystery", "n": 9, "at": LIGHTHOUSE},
		{"goal": "Get a Deep-sea Cutter, the only boat for the Deep", "t": "boat", "tier": 5, "at": "Bosun Pell", "start": [
			"Did you see it, when the light came on? Out past the shelf. Something rolled over in the dark.",
			"Elias wrote about it: the Warden. While the Eye burns it keeps its distance. Now it's awake.",
			"Only the best boat on the coast will take you out there. Save up, fisher."]},
		{"goal": "Catch the Warden in the Deep, at night", "t": "caught", "id": "the_warden", "at": [1210.0, 520.0]},
	]},
]
const END := ["The Warden, landed. Elias would have bought you a drink for a month.",
	"That's the story done, fisher. But the sea's not done with you: there's a Logbook to fill, legends still out there, and a hut to make your own.",
	"Come and see me on the docks. I'll want to hear it all again."]
# notes when each new kind of fishing opens up
const LEVEL_NOTES := {
	2: ["Hale's got crab pots in now (the Kit tab). Your gran swore by them. Drop one wherever crabs crawl and come back later."],
	4: ["You're getting good. Hale sells a cast net now: throw it over a bait school and pull when it's sunk. Live bait for days."],
	5: ["Got a boat? Try Hale's trolling rig: lines out behind you, keep her moving, and hang on when something big hits."],
	6: ["Hale's selling snorkels and spearguns now. Stop the boat over clear water, the reef or the kelp, and dive. Hold your breath!"],
	10: ["Level ten! Your gran didn't get to ten till she was forty. The tougher fish will fight you on the reel bar: keep them in the green."],
}

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var town: Node
var fishing: Node
var interiors: Node3D
var dialogue: CanvasLayer
var progress: Node
var map_screen: CanvasLayer
var mystery: Node3D
var _beacon: Node3D
var _poll_t := 0.0
var _busy := false  # a story conversation is on screen


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, s: Node, sv: Dictionary, t: Node) -> void:
	world = w
	player = p
	hud = h
	audio = a
	sea = s
	save = sv
	town = t
	_build_beacon()


## Call once everything's wired up.
func start() -> void:
	town.talk_hooks.insert(0, on_talk)
	fishing.catch_hooks.append(on_catch)
	progress.levelled.connect(_on_level)
	_catch_up()
	_refresh()


func _st() -> Dictionary:
	return save.story


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


## A brand-new game: Gran's letter.
func intro() -> void:
	if chapter() != 0 or step_i() != 0:
		return
	_busy = true
	dialogue.say("A letter from Gran", [
		"My dear, if you're reading this, the hut on the point is yours now, and so is my old rod.",
		"Gullhaven's a good town. The fish are honest, and the people mostly are too.",
		"Find Old Marlo down on the docks. He taught me to fish, a hundred years ago. He'll show you the ropes.",
		"Look after the cats. And keep an eye on that lighthouse.   Love, Gran"], null, [], _intro_done)


func _intro_done(_c: int) -> void:
	_busy = false
	hud.banner("Prologue", "Gran's Hut")
	_refresh()


# --- what finishes a step ------------------------------------------------------------------

func on_talk(who: String) -> bool:
	var s := current()
	if s.is_empty() or str(s.t) != "talk" or str(s.who) != who:
		return false
	_busy = true
	town.talk(who, s.lines, [], _talked)
	return true


func _talked(_c: int) -> void:
	_busy = false
	_complete()


func on_catch(id: String, _cm: float, _variant: String) -> void:
	var s := current()
	if s.is_empty():
		return
	var e: Dictionary = sea.by_id.get(id, {})
	var is_fish := str(e.get("cat", "")) in ["fish", "legend"]
	match str(s.t):
		"catch":
			if is_fish:
				_st()["count"] = int(_st().get("count", 0)) + 1
				if int(_st().count) >= int(s.n):
					call_deferred("_complete")
				else:
					_refresh()
		"baitcatch":
			if is_fish and str(fishing.cast_bait) != "dough" and str(fishing.cast_bait) != "":
				call_deferred("_complete")
		"caught":
			if id == str(s.id):
				call_deferred("_complete")


func _met(s: Dictionary) -> bool:
	match str(s.t):
		"bait":
			for k in save.bait:
				if str(k) != "dough" and int(save.bait[k]) > 0:
					return true
			return false
		"hut":
			return interiors.is_inside() and interiors.in_hut()
		"pot":
			return not (save.pots as Array).is_empty()
		"mystery":
			return int(save.mystery.get("step", 0)) >= int(s.n) or (int(s.n) >= 9 and bool(save.mystery.get("restored", false)))
		"permit":
			return (save.permits as Dictionary).has(str(s.id))
		"visit":
			return (save.visited as Dictionary).has(str(s.place))
		"boat":
			return _best_boat() >= int(s.tier)
		"caught":
			return (save.log as Dictionary).has(str(s.id))
	return false


func _best_boat() -> int:
	var best := 0
	for k in save.boats:
		best = maxi(best, int(Boats.boat_info(str(k)).get("tier", 0)))
	return best


func _process(delta: float) -> void:
	_update_beacon()
	_poll_t -= delta
	if _poll_t > 0.0:
		return
	_poll_t = 0.4
	if finished() or _busy or dialogue.is_open:
		_refresh_distance()
		return
	var s := current()
	if not s.is_empty() and str(s.t) not in ["talk", "catch", "baitcatch"] and _met(s):
		_complete()
	else:
		_refresh_distance()


# --- moving the story on ----------------------------------------------------------------------

func _complete(quiet := false) -> void:
	var s := current()
	if s.is_empty():
		return
	var gift: Dictionary = s.get("gift", {})
	if gift.has("shells"):
		save.shells = int(save.shells) + int(gift.shells)
		hud.set_shells(save.shells)
	if gift.has("pot"):
		var kit: Dictionary = save.kit
		kit["pot"] = maxi(int(kit.get("pot", 0)), int(gift.pot))
	if not quiet:
		audio.play("good", -4.0)
		progress.add(20 + 10 * chapter())
	_st()["count"] = 0
	_st()["step"] = step_i() + 1
	var steps: Array = CHAPTERS[chapter()].steps
	var finished_chapter := step_i() >= steps.size()
	if not quiet and s.has("done"):
		_busy = true
		dialogue.say(str(s.get("done_who", "")), s.done, null, [], _done_said.bind(finished_chapter))
	elif finished_chapter:
		_next_chapter(quiet)
	else:
		_step_started(quiet)
	SaveGame.write(save)
	_refresh()


func _done_said(_c: int, finished_chapter: bool) -> void:
	_busy = false
	if finished_chapter:
		_next_chapter(false)
	else:
		_step_started(false)
	_refresh()


func _next_chapter(quiet: bool) -> void:
	var done_ch: Dictionary = CHAPTERS[chapter()]
	_st()["ch"] = chapter() + 1
	_st()["step"] = 0
	if not quiet:
		var reward: Dictionary = done_ch.reward
		if int(reward.shells) > 0:
			save.shells = int(save.shells) + int(reward.shells)
			hud.set_shells(save.shells)
		progress.add(int(reward.xp), "%s complete" % str(done_ch.title))
		audio.play("fanfare2")
	SaveGame.write(save)
	if finished():
		if not quiet:
			hud.banner("The story is told", "...but the sea isn't finished with you")
			_note(END)
		return
	var ch: Dictionary = CHAPTERS[chapter()]
	if not quiet:
		hud.banner(str(ch.title), str(ch.name))
		var note: Array = ch.get("note", [])
		if not note.is_empty():
			_note(note)
		_step_started(false)


func _step_started(quiet: bool) -> void:
	var s := current()
	if quiet or s.is_empty():
		return
	if s.has("start"):
		_note(s.start)


## A note from Marlo, delivered by a gull wherever you are.
func _note(lines: Array) -> void:
	audio.play("gull", -4.0)
	var tex: Texture2D = null
	if world.folk.has(MARLO):
		var node: Sprite3D = world.folk[MARLO].node
		tex = node.texture
	var all: Array = ["A gull lands beside you with a note tied to its leg."]
	all.append_array(lines)
	dialogue.say(NOTE_FROM, all, tex)


func _on_level(lv: int) -> void:
	if LEVEL_NOTES.has(lv):
		_note(LEVEL_NOTES[lv])


## Older saves: skip what's already been done.
func _catch_up() -> void:
	var st := _st()
	if chapter() == 0 and (int(save.stats.get("catches", 0)) >= 8 or int(save.mystery.get("step", 0)) >= 1 or (save.permits as Dictionary).has("bridge")):
		st["ch"] = 1
		st["step"] = 0
	for i in 40:
		var s := current()
		if s.is_empty() or str(s.t) in ["talk", "catch", "baitcatch"] or not _met(s):
			break
		_complete(true)


# --- the corner, the beam of light and the map pin ----------------------------------------------

func _refresh() -> void:
	if finished():
		hud.set_objective("", "")
		map_screen.story_pin = Vector2.INF
		return
	_refresh_distance()


func _goal_text(s: Dictionary) -> String:
	var g := str(s.goal)
	match str(s.t):
		"catch":
			g += " (%d/%d)" % [int(_st().get("count", 0)), int(s.n)]
		"permit":
			if str(s.id) == "bridge":
				var m: Dictionary = save.materials
				g = "Mend the estuary bridge: bring Tess the carpenter 30 driftwood (%d), 8 rope (%d) and 400 Shells" % [int(m.get("wood", 0)), int(m.get("rope", 0))]
	return g


func _refresh_distance() -> void:
	var s := current()
	if s.is_empty():
		return
	var ch: Dictionary = CHAPTERS[chapter()]
	var heading := "%s: %s" % [str(ch.title), str(ch.name)]
	var text := _goal_text(s)
	var at := target()
	if at != Vector3.INF and not interiors.is_inside():
		var to := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
		if to.length() > 12.0:
			var i := posmod(int(round(atan2(to.x, -to.y) / (PI * 0.25))), 8)
			text += "\n%d m %s" % [int(to.length()), DIRS[i]]
	hud.set_objective(heading, text)
	map_screen.story_pin = Vector2(at.x, at.z) if at != Vector3.INF else Vector2.INF


## Where the current step wants you (Vector3.INF if nowhere in particular).
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


func _build_beacon() -> void:
	_beacon = Node3D.new()
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 40.0
	cyl.radial_segments = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position = Vector3(0.0, 20.0, 0.0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(1.0, 0.8, 0.35, 0.22)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(beam)
	var gem := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.32
	sph.height = 0.8
	sph.radial_segments = 4
	sph.rings = 2
	gem.mesh = sph
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.82, 0.3)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.7, 0.2)
	gm.emission_energy_multiplier = 2.0
	gem.material_override = gm
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gem.name = "Gem"
	_beacon.add_child(gem)
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
	var gem := _beacon.get_node("Gem") as MeshInstance3D
	var t := Time.get_ticks_msec() * 0.001
	gem.position = Vector3(0.0, 3.0 + sin(t * 2.0) * 0.25, 0.0)
	gem.rotation.y = t * 1.5


## For the Journal: the story so far.
func journal_lines() -> Array[String]:
	var out: Array[String] = []
	for i in mini(chapter() + 1, CHAPTERS.size()):
		var ch: Dictionary = CHAPTERS[i]
		var done := i < chapter()
		out.append("%s  %s: %s" % ["[color=#8ad08a]Done[/color]" if done else "[color=#ffd24d]Now[/color]", str(ch.title), str(ch.name)])
	if finished():
		out.append("[color=#8ad08a]The story is told. Free fishing, forever.[/color]")
	else:
		out.append("Next: " + Glyphs.plain(_goal_text(current())))
	return out
