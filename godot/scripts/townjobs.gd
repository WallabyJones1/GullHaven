extends Node3D
## Jobs for the townsfolk of Gullhaven (side quests about town). A gold "!" over someone means they've a job
## for you; a "?" means you've done it and they'd like to know. Jobs: find things (a lost cat,
## the crier's bell, a runaway goat), take things to people, catch particular fish, bring
## what you've gathered or cooked, and help a seal caught in a net. Listed in the Journal.

const SaveGame := preload("res://scripts/save_game.gd")
const Models := preload("res://scripts/models.gd")

# Each quest: giver, title, what to do (type and details), the words, and the reward.
#   find: go to `at`, press Space on the thing there (`thing`: model group/name or a cat), bring news back
#   deliver: carry something to `to` (a townsperson or a shopkeeper)
#   catch: land `n` fish matching `rule` (any, rare, big:<cm>, night)
#   bring: hand over `n` of `item` (a material or a land item)
const QUESTS := [
	{"id": "lost_cat2", "giver": "Mrs Pemberton", "title": "Marmalade Has Wandered Off", "type": "find", "at": [446.0, 616.0], "thing": "cat",
		"find": "Marmalade! There you are, puss.", "ask": ["Oh, have you seen Marmalade? My ginger tom.", "He wanders down to the south beach after the fish scraps. Would you look for him?"],
		"wait": ["No sign of Marmalade? Try the south beach, by the rowboats."], "done": ["Marmalade! You found him! Oh, you naughty thing.", "Here, for your trouble. And come by for tea."],
		"shells": 400, "xp": 120},
	{"id": "dock_supper", "giver": "@fisher0", "title": "Supper for the Dock Lads", "type": "catch", "rule": "any", "n": 3,
		"ask": ["Not a nibble all morning, and the lads want their supper.", "Catch three fish for us? Any fish'll do."],
		"wait": ["Three fish, that's all we need. Any kind."], "done": ["Three beauties! The lads'll eat well tonight.", "Take this: I owe you."],
		"shells": 350, "xp": 100},
	{"id": "bread_run", "giver": "Teddy Crumb", "title": "Bread for Old Marlo", "type": "deliver", "to": "Old Marlo",
		"ask": ["Old Marlo's bread order! He's out on the end of the middle dock.", "Could you run it down? My legs aren't what they were. Well, they're eleven."],
		"wait": ["Old Marlo's on the docks. Mind you don't eat any on the way!"], "deliver": ["Marlo's bread? Bless that boy. Tell him thanks."],
		"done": ["He got it? Brilliant! Here, have the copper and a warm bun."], "shells": 200, "xp": 80},
	{"id": "crier_bell", "giver": "Crier Bartholomew", "title": "The Crier's Bell", "type": "find", "at": [454.0, 541.0], "thing": "bell",
		"find": "A brass hand bell, half buried in the sand.", "ask": ["A crier without his bell! I put it down on the north beach to rest my arm.", "And then a gull... well. Would you look?"],
		"wait": ["Up on the north beach, by the drying racks. It glints!"], "done": ["MY BELL! Hear ye, hear ye: this fisher is a hero!", "Payment, as promised."],
		"shells": 300, "xp": 90},
	{"id": "net_rope", "giver": "Old Netty", "title": "Rope for the Nets", "type": "bring", "item": "rope", "n": 5,
		"ask": ["Forty years mending nets, and never so many holes.", "Five lengths of rope would see me right. You'll find it washed up, or in crates out at sea."],
		"wait": ["Five rope, dear. Beachcombing turns it up."], "done": ["Lovely rope! Here, and take this net-mender's knot: it's lucky."],
		"shells": 600, "xp": 140},
	{"id": "chapel_fish", "giver": "Sister Maren", "title": "A Fish for the Blessing", "type": "catch", "rule": "rare", "n": 1,
		"ask": ["At the blessing of the boats we lay a rare fish on the altar.", "Ours swam off. Could you catch something rare? Blue on the card or better."],
		"wait": ["Something rare, from deeper or stranger waters."], "done": ["It's perfect. The boats will be blessed. Thank you, child of the tide."],
		"shells": 800, "xp": 200},
	{"id": "wildflowers", "giver": "Wren", "title": "Flowers for Mum", "type": "bring", "item": "wildflowers", "n": 3,
		"ask": ["It's Mum's birthday and I've got no Shells.", "Could you pick three bunches of wildflowers? They grow in the meadows past the town."],
		"wait": ["Three bunches! Please please please."], "done": ["They're SO pretty! Mum's going to cry. Here, I found this on the beach!"],
		"shells": 150, "xp": 80, "gift": "quartz"},
	{"id": "seal_net", "giver": "Bart Mackerel", "title": "A Seal in a Tangle", "type": "find", "at": [432.0, 628.0], "thing": "seal",
		"find": "You ease the old net off the seal. It barks, and flops off into the sea.", "ask": ["There's a seal tangled in an old net on the south beach.", "I can't leave the stall. Go free the poor thing?"],
		"wait": ["South beach, past the rowboats. Gently now."], "done": ["Freed it? You're a good sort. Here: a seal friend's worth more than this, mind."],
		"shells": 500, "xp": 150},
	{"id": "warehouse_crate", "giver": "Dockhand Sid", "title": "Crate for the Market", "type": "deliver", "to": "Ada Turnbull",
		"ask": ["Ada's crate of seed potatoes came in on the morning boat.", "She's at the veg stall in the square. Take it to her?"],
		"wait": ["The veg stall, top of the square. Ada Turnbull."], "deliver": ["My potatoes! Took their time. Ta, love."],
		"done": ["Delivered? You're quicker than the last lad. Here."], "shells": 250, "xp": 80},
	{"id": "museum_big", "giver": "Ollie", "title": "A Monster for the Museum", "type": "catch", "rule": "big:60", "n": 1,
		"ask": ["Dr. Finch wants a really big fish for the new tank.", "Sixty centimetres or more. Think you can?"],
		"wait": ["Sixty centimetres! Try deeper water, and a stronger rod."], "done": ["Look at the size of it! Dr. Finch will be thrilled. Here's your fee."],
		"shells": 900, "xp": 220},
	{"id": "goat_loose", "giver": "Hilda", "title": "Goat on the Loose", "type": "find", "at": [396.0, 612.0], "thing": "goat",
		"find": "The goat bleats, eats a bit of your sleeve, and trots off home.", "ask": ["Clementine's got out again! My nanny goat.", "Last I saw she was heading for the south side of town. Find her?"],
		"wait": ["South of town, near the clothes shop. Follow the bleating."], "done": ["She's back! Eating my washing again, but back. Thank you!"],
		"shells": 300, "xp": 90},
	{"id": "night_song", "giver": "Fiddler Finn", "title": "A Song of the Night Sea", "type": "catch", "rule": "night", "n": 1,
		"ask": ["I'm writing a song about the night sea, but I've never fished at night.", "Catch me something after dark? Then I'll know what to sing."],
		"wait": ["After sundown, before dawn. The night fish are different."], "done": ["Oh, it's glorious! I'll call the song after you. Take this, with my thanks."],
		"shells": 500, "xp": 140},
	{"id": "inn_stew", "giver": "Innkeeper Hob", "title": "Stew for the Salty Pillow", "type": "bring", "item": "veg_stew", "n": 1,
		"ask": ["My cook's run off to sea and the guests want stew!", "Could you cook a vegetable stew? Gran's cook pot will do it."],
		"wait": ["One vegetable stew. Veg from Gran's garden, cooked in the yard."], "done": ["Smells like home. You've saved the Salty Pillow!", "And a room's yours any night you like."],
		"shells": 450, "xp": 130},
]
# extra quest-givers (the rest are townsfolk who're already about)
const GIVERS := [["Mrs Pemberton", 374.5, 566.5], ["Old Netty", 455.5, 545.8], ["Sister Maren", 356.0, 553.6], ["Dockhand Sid", 426.0, 534.6],
	["Ollie", 407.0, 598.0], ["Hilda", 348.0, 568.0], ["Innkeeper Hob", 375.0, 620.6]]

var main: Node
var bustle: Node
var _marks := {}  # person name -> Label3D
var _things := {}  # quest id -> Node3D
var _tick := 0.0


func setup(m: Node, b: Node) -> void:
	main = m
	bustle = b
	if not main.save.has("jobs") or not (main.save.jobs is Dictionary):
		main.save["jobs"] = {}
	for g in GIVERS:
		var p: Dictionary = bustle._person(str(g[0]), Vector3(float(g[1]), 0.0, float(g[2])), "giver")
		if not p.is_empty():
			p.facing = Vector3.BACK
	bustle.quest_hook = _hook
	main.town.talk_hooks.insert(0, _on_folk_talk)
	main.town.providers.append(self)
	main.fishing.catch_hooks.append(_on_catch)
	for q in QUESTS:
		var mark := Label3D.new()
		mark.font = load("res://art/fonts/pixelify_sans_bold.woff2")
		mark.font_size = 46
		mark.outline_size = 12
		mark.pixel_size = 0.0011
		mark.fixed_size = true  # easy to spot across the square
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.outline_modulate = Color(0.12, 0.06, 0.02)
		mark.position = Vector3(0.0, 2.6, 0.0)
		var p := _giver(q)
		if p.is_empty():
			continue
		(p.node as Node3D).add_child(mark)
		_marks[str(q.id)] = mark
	_refresh()


func _S() -> Dictionary:
	return main.save.jobs


func _state(id: String) -> Dictionary:
	return _S().get(id, {})


func _giver(q: Dictionary) -> Dictionary:
	var g := str(q.giver)
	if g.begins_with("@fisher"):
		var i := int(g.trim_prefix("@fisher"))
		return bustle._fishers[i] if i < bustle._fishers.size() else {}
	return bustle.person(g)


func _quest_of(p: Dictionary) -> Dictionary:
	for q in QUESTS:
		var g := _giver(q)
		if not g.is_empty() and g.node == p.node:
			return q
	return {}


func _ready_to_hand_in(q: Dictionary) -> bool:
	var st := _state(str(q.id))
	if str(st.get("stage", "")) != "active":
		return false
	match str(q.type):
		"find", "deliver":
			return bool(st.get("got", false))
		"catch":
			return int(st.get("n", 0)) >= int(q.n)
		"bring":
			return _have(str(q.item)) >= int(q.n)
	return false


func _have(item: String) -> int:
	if item in ["rope", "wood", "scrap", "stone"]:
		return int((main.save.materials as Dictionary).get(item, 0))
	return int(main.land.count(item))


func _take(item: String, n: int) -> void:
	if item in ["rope", "wood", "scrap", "stone"]:
		main.save.materials[item] = int(main.save.materials.get(item, 0)) - n
		if main.hud.has_method("set_materials"):
			main.hud.set_materials(main.save.materials)
	else:
		main.land.take(item, n)


func _refresh() -> void:
	for q in QUESTS:
		var id := str(q.id)
		if not _marks.has(id):
			continue
		var m: Label3D = _marks[id]
		var stage := str(_state(id).get("stage", ""))
		if stage == "":
			m.text = "!"
			m.modulate = Color(1.0, 0.82, 0.25)
			m.visible = true
		elif stage == "active":
			m.text = "?" if _ready_to_hand_in(q) else "..."
			m.modulate = Color(0.55, 1.0, 0.6) if _ready_to_hand_in(q) else Color(0.75, 0.75, 0.8)
			m.visible = true
		else:
			m.visible = false
		# the thing to find, while you're looking
		if str(q.type) == "find":
			var want := stage == "active" and not bool(_state(id).get("got", false))
			if want and not _things.has(id):
				_spawn_thing(q)
			elif not want and _things.has(id):
				(_things[id] as Node3D).queue_free()
				_things.erase(id)


func _spawn_thing(q: Dictionary) -> void:
	var at: Array = q.at
	var x := float(at[0])
	var z := float(at[1])
	var w: Node3D = main.harbour
	var y := float(w.stand_height(x, z))
	var n: Node3D
	match str(q.thing):
		"cat":
			var Billboard := load("res://scripts/billboard.gd")
			var s: Sprite3D = Billboard.sprite(load("res://art/cats2/ginger.png"), 1.0 / 40.0, 5, 4, 29.0)
			n = s
		"bell":
			var bm := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.06
			cone.bottom_radius = 0.16
			cone.height = 0.24
			bm.mesh = cone
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.75, 0.25)
			mat.metallic = 0.6
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.3, 0.05)
			bm.material_override = mat
			n = bm
			y += 0.1
		"seal":
			n = Models.make("animals", "seal")
			if n:
				var netm := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(1.0, 0.25, 0.6)
				netm.mesh = box
				var nm := StandardMaterial3D.new()
				nm.albedo_color = Color(0.3, 0.45, 0.4, 0.8)
				nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				netm.material_override = nm
				netm.position = Vector3(0.1, 0.25, 0.0)
				n.add_child(netm)
		"goat":
			n = Models.make("animals", "goat")
	if n == null:
		return
	add_child(n)
	n.global_position = Vector3(x, y, z)
	_things[str(q.id)] = n


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	for q in QUESTS:
		var id := str(q.id)
		if _things.has(id) and str(q.thing) == "goat":
			var g: Node3D = _things[id]
			g.rotation.y += 0.3  # wandering about, nibbling


# --- talking ---------------------------------------------------------------------------------------

## bustle asks: is this person's talk a quest? prompt_only: just the prompt text.
func _hook(p: Dictionary, prompt_only: bool) -> Dictionary:
	var q := _quest_of(p)
	if q.is_empty():
		# a delivery to a townsperson?
		for dq in QUESTS:
			if str(dq.type) == "deliver" and str(dq.to) == str(p.name) and str(_state(str(dq.id)).get("stage", "")) == "active" \
					and not bool(_state(str(dq.id)).get("got", false)):
				if prompt_only:
					return {"prompt": "Space: Give %s the delivery" % p.name}
				_deliver(dq, str(p.name), (p.node as Sprite3D).texture)
				return {"handled": true}
		return {}
	var id := str(q.id)
	var stage := str(_state(id).get("stage", ""))
	if stage == "done":
		return {}
	if prompt_only:
		if stage == "":
			return {"prompt": "Space: Talk to %s (a job!)" % p.name}
		if _ready_to_hand_in(q):
			return {"prompt": "Space: Tell %s it's done" % p.name}
		return {}
	var tex: Texture2D = (p.node as Sprite3D).texture
	if stage == "":
		main.dialogue.say(str(p.name), q.ask, tex, ["I'll do it", "Not right now"], func(c: int) -> void:
			if c == 0:
				_S()[id] = {"stage": "active", "n": 0, "got": false}
				main.hud.toast("New job: %s" % str(q.title))
				main.audio.play("pin", -2.0)
				_refresh()
				SaveGame.write(main.save))
	elif _ready_to_hand_in(q):
		main.dialogue.say(str(p.name), q.done, tex, [], func(_c: int) -> void: _complete(q))
	else:
		main.dialogue.say(str(p.name), q.wait, tex)
	return {"handled": true}


func _deliver(q: Dictionary, who: String, tex: Texture2D) -> void:
	_state(str(q.id))["got"] = true
	main.audio.play("coin", -6.0)
	main.dialogue.say(who, q.deliver, tex)
	main.hud.toast("Delivered! Go back to %s." % str(q.giver))
	_refresh()
	SaveGame.write(main.save)


## Deliveries to the shopkeepers and Marlo go through the town's talk.
func _on_folk_talk(who: String) -> bool:
	for q in QUESTS:
		if str(q.type) == "deliver" and str(q.to) == who and str(_state(str(q.id)).get("stage", "")) == "active" \
				and not bool(_state(str(q.id)).get("got", false)):
			_state(str(q.id))["got"] = true
			main.town.talk(who, q.deliver)
			main.hud.toast("Delivered! Go back to %s." % str(q.giver))
			_refresh()
			SaveGame.write(main.save)
			return true
	return false


func _complete(q: Dictionary) -> void:
	var id := str(q.id)
	if str(q.type) == "bring":
		_take(str(q.item), int(q.n))
	_S()[id]["stage"] = "done"
	main.save.shells = int(main.save.shells) + int(q.shells)
	main.hud.set_shells(main.save.shells)
	if main.progress:
		main.progress.add(int(q.xp), str(q.title))
	var extra := ""
	if q.has("gift"):
		extra = ", " + str(main.land.add_item(str(q.gift), 1)).trim_prefix("+")
	main.audio.play("fanfare1")
	main.hud.show_banner("Job done: %s" % str(q.title), "+%d Shells%s" % [int(q.shells), extra])
	_refresh()
	SaveGame.write(main.save)


# --- finding things --------------------------------------------------------------------------------

func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	for id in _things:
		var n: Node3D = _things[id]
		var d := Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
		if d < 1.8:
			var q := _by_id(id)
			var verb := {"cat": "Pick up Marmalade", "bell": "Pick up the bell", "seal": "Free the seal from the net", "goat": "Shoo the goat home"}
			return {"kind": "sidequest", "id": id, "dist": d * 0.5, "text": "Space: %s" % str(verb.get(str(q.thing), "Look"))}
	return {}


func use(it: Dictionary) -> void:
	var id := str(it.id)
	var q := _by_id(id)
	_state(id)["got"] = true
	main.audio.play("good", -2.0)
	main.hud.toast("%s Tell %s." % [str(q.find), str(q.giver)])
	_refresh()
	SaveGame.write(main.save)


func _by_id(id: String) -> Dictionary:
	for q in QUESTS:
		if str(q.id) == id:
			return q
	return {}


# --- catches -------------------------------------------------------------------------------------------

func _on_catch(id: String, cm: float, _variant: String) -> void:
	var e: Dictionary = main.sea.by_id.get(id, {})
	if e.is_empty() or not (str(e.get("cat", "")) in ["fish", "legend"]):
		return
	var hour := float(main.sea.env.get("hour", 12.0))
	var changed := false
	for q in QUESTS:
		if str(q.type) != "catch" or str(_state(str(q.id)).get("stage", "")) != "active":
			continue
		var rule := str(q.rule)
		var ok := rule == "any"
		if rule == "rare":
			ok = int(e.get("r", 0)) >= 2
		elif rule == "night":
			ok = hour >= 20.0 or hour < 5.0
		elif rule.begins_with("big:"):
			ok = cm >= float(rule.trim_prefix("big:"))
		if ok:
			var st := _state(str(q.id))
			st["n"] = int(st.get("n", 0)) + 1
			changed = true
			if int(st.n) >= int(q.n):
				main.hud.toast("That's the job done: tell %s!" % str(q.giver).replace("@fisher0", "the fisher on the dock"))
	if changed:
		_refresh()


func journal_lines() -> Array[String]:
	var out: Array[String] = []
	var done := 0
	for q in QUESTS:
		var st := _state(str(q.id))
		var stage := str(st.get("stage", ""))
		var giver := str(q.giver).replace("@fisher0", "the fisher on the first dock")
		if stage == "done":
			done += 1
		elif stage == "active":
			var prog := ""
			if str(q.type) == "catch":
				prog = " (%d/%d)" % [int(st.get("n", 0)), int(q.n)]
			elif str(q.type) == "bring":
				prog = " (%d/%d)" % [mini(_have(str(q.item)), int(q.n)), int(q.n)]
			var status := "ready: go back to %s" % giver if _ready_to_hand_in(q) else str(q.wait[0])
			out.append("%s%s: %s" % [q.title, prog, status])
	out.append("Jobs done for the townsfolk: %d of %d. Look for a gold ! over someone's head." % [done, QUESTS.size()])
	return out
