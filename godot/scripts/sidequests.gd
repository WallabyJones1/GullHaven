extends Node3D
## Side quests around the coast:
## - Granny Wick's cats: Biscuit, Pepper and Mochi have wandered off. Find them (the
##   lighthouse arm, Willowford, Tideglass Cay) and Granny will be very grateful.
## - The mill sails: Miller Ottie needs driftwood and rope to mend Willowford's mill.
## - Bottle post: twelve letters drift about the sea in bottles (or come up on a hook).
##   Find them all and the harbourmaster pays a finder's fee.
## The mini-games (stone skipping, the bay race, darts) report their records here too.

const SaveGame := preload("res://scripts/save_game.gd")
const Billboard := preload("res://scripts/billboard.gd")
const Furniture := preload("res://scripts/furniture.gd")

const LOST_CATS := {
	"Biscuit": {"at": Vector2(490.0, 543.5), "coat": "ginger", "where": "out on the lighthouse arm"},
	"Pepper": {"at": Vector2(320.0, 252.0), "coat": "black", "where": "up in Willowford, by the square"},
	"Mochi": {"at": Vector2(565.8, 824.4), "coat": "cream", "where": "over on Tideglass Cay"},
}
const MILL := {"wood": 15, "rope": 4}
const LETTER_IDS := ["letter_1", "letter_2", "letter_3", "letter_4", "letter_5", "letter_6", "letter_7", "letter_8",
	"letter_9", "letter_10", "letter_11", "letter_12"]

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var save: Dictionary
var town: Node
var progress: Node  # fisher XP
var _cats := {}  # name -> Sprite3D


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, sv: Dictionary, t: Node) -> void:
	world = w
	player = p
	hud = h
	audio = a
	save = sv
	town = t
	town.talk_hooks.append(_talk)
	world.mill_fixed = state("mill") == "done"
	if state("cats") == "active":
		_spawn_cats()


func state(id: String) -> String:
	var q: Dictionary = save.quests
	return str(q.get(id, {}).get("state", ""))


func data(id: String) -> Dictionary:
	var q: Dictionary = save.quests
	if not q.has(id):
		q[id] = {"state": ""}
	return q[id]


func _mark(id: String, st: String) -> void:
	data(id)["state"] = st
	SaveGame.write(save)


# --- talking -------------------------------------------------------------------------

func _talk(who: String) -> bool:
	match who:
		"Granny Wick":
			return _granny()
		"Miller Ottie":
			return _miller()
		"Harbourmaster Quill":
			return _bottle_fee()
	return false


func _granny() -> bool:
	match state("cats"):
		"":
			_mark("cats", "active")
			data("cats")["found"] = []
			_spawn_cats()
			town.say("Granny Wick", "Oh, dear, would you help an old woman? My Biscuit, Pepper and Mochi have gone wandering again. Biscuit loves the lighthouse, Pepper always heads for Willowford, and Mochi... Mochi once stowed away to Tideglass Cay.")
			hud.toast("New quest: Granny Wick's cats. Your Journal (J) keeps track.")
			audio.play("cardflip", -4.0)
			return true
		"active":
			var found: Array = data("cats").get("found", [])
			if found.size() >= LOST_CATS.size():
				_mark("cats", "done")
				save.shells = int(save.shells) + 600
				if progress:
					progress.add(150)
				hud.set_shells(save.shells)
				Furniture.give(save, "plant_flower")
				SaveGame.write(save)
				audio.play("fanfare2")
				town.say("Granny Wick", "All three, home safe! You're a treasure. Here's 600 Shells, and a flowering plant from my window for your hut.")
				return true
			var left: Array[String] = []
			for n in LOST_CATS:
				if not found.has(n):
					left.append("%s (%s)" % [n, LOST_CATS[n].where])
			town.say("Granny Wick", "Still missing: %s." % ", ".join(left))
			return true
	return false


func _miller() -> bool:
	match state("mill"):
		"":
			_mark("mill", "active")
			town.say("Miller Ottie", "The storm cracked my sails and the wheel's stood still a month. Bring me %d driftwood and %d rope and I'll have her turning again." % [MILL.wood, MILL.rope])
			hud.toast("New quest: the mill sails.")
			audio.play("cardflip", -4.0)
			return true
		"active":
			var short := Furniture.short_of(save, 0, MILL)
			if short != "":
				town.say("Miller Ottie", "Still need timber and rope for those sails. %s" % short)
				return true
			Furniture.pay(save, 0, MILL)
			hud.set_materials(save.materials)
			_mark("mill", "done")
			world.mill_fixed = true
			save.shells = int(save.shells) + 400
			if progress:
				progress.add(150)
			hud.set_shells(save.shells)
			SaveGame.write(save)
			audio.play("fanfare2")
			town.say("Miller Ottie", "Look at her go! Here's 400 Shells for your trouble. The old keeper was a friend of my father's, you know. Dad always said the bells by the door had a story.")
			return true
	return false


func letters_found() -> int:
	var book: Dictionary = save.log
	var n := 0
	for id in LETTER_IDS:
		if book.has(id):
			n += 1
	return n


func _bottle_fee() -> bool:
	if state("bottles") == "done" or letters_found() < LETTER_IDS.size():
		return false
	_mark("bottles", "done")
	save.shells = int(save.shells) + 1000
	if progress:
		progress.add(150)
	hud.set_shells(save.shells)
	SaveGame.write(save)
	audio.play("fanfare2")
	town.say("Harbourmaster Quill", "All twelve bottle letters? That's fifty years of the harbour's history. The finder's fee is 1000 Shells, and well earned.")
	return true


# --- the lost cats ---------------------------------------------------------------------

func _spawn_cats() -> void:
	var found: Array = data("cats").get("found", [])
	for n in LOST_CATS:
		if found.has(n) or _cats.has(n):
			continue
		var c: Dictionary = LOST_CATS[n]
		var at: Vector2 = c.at
		var s := Billboard.sprite(load("res://art/cats2/%s.png" % c.coat), 1.0 / 40.0, 5, 4, 29.0)
		s.frame = 3  # sitting, facing you
		add_child(s)
		s.global_position = Vector3(at.x, world.stand_height(at.x, at.y), at.y)
		_cats[n] = s


func near(pos: Vector3, facing: Vector3) -> Dictionary:
	var best := {}
	var best_d := 1.6
	for n in _cats:
		var s: Sprite3D = _cats[n]
		var to := Vector2(s.global_position.x - pos.x, s.global_position.z - pos.z)
		var d := to.length()
		if d > best_d or absf(s.global_position.y - pos.y) > 2.0:
			continue
		if d > 0.8 and Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.25:
			continue
		best_d = d
		best = {"kind": "lostcat", "who": n, "dist": d, "text": "Space: Pick up %s" % n}
	return best


func use(it: Dictionary) -> void:
	var n := str(it.get("who", ""))
	if not _cats.has(n):
		return
	var s: Sprite3D = _cats[n]
	s.queue_free()
	_cats.erase(n)
	var found: Array = data("cats").get("found", [])
	found.append(n)
	data("cats")["found"] = found
	SaveGame.write(save)
	audio.play("purr", -2.0)
	if found.size() >= LOST_CATS.size():
		hud.toast("%s purrs in your arms and trots off home. That's all three: go and tell Granny Wick!" % n)
	else:
		hud.toast("%s purrs in your arms and trots off home to Granny Wick. %d to go." % [n, LOST_CATS.size() - found.size()])


## For the Journal.
func journal_lines() -> Array[String]:
	var out: Array[String] = []
	match state("cats"):
		"":
			out.append("[color=#9aa4b4]Granny Wick in Gullhaven looks worried about something.[/color]")
		"active":
			var found: Array = data("cats").get("found", [])
			var left: Array[String] = []
			for n in LOST_CATS:
				if not found.has(n):
					left.append("%s, %s" % [n, LOST_CATS[n].where])
			if left.is_empty():
				out.append("[b]Granny Wick's cats[/b]: all found. Go and tell Granny Wick.")
			else:
				out.append("[b]Granny Wick's cats[/b] (%d of 3 found). Still missing: %s." % [found.size(), "; ".join(left)])
		"done":
			out.append("[color=#8ad08a][b]Granny Wick's cats[/b]: done.[/color]")
	match state("mill"):
		"":
			out.append("[color=#9aa4b4]Willowford's mill sails have stopped turning. Miller Ottie might want a hand.[/color]")
		"active":
			out.append("[b]The mill sails[/b]: bring Miller Ottie %d driftwood and %d rope." % [MILL.wood, MILL.rope])
		"done":
			out.append("[color=#8ad08a][b]The mill sails[/b]: done. The mill turns again.[/color]")
	var n := letters_found()
	if state("bottles") == "done":
		out.append("[color=#8ad08a][b]Bottle post[/b]: all twelve letters found.[/color]")
	elif n >= LETTER_IDS.size():
		out.append("[b]Bottle post[/b]: all twelve letters found! Show Harbourmaster Quill.")
	else:
		out.append("[b]Bottle post[/b]: %d of 12 letters found. Bottles float about the sea, and some come up on a hook." % n)
	return out
