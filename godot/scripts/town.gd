extends Node
## The people (and cats) of the harbour. Walk up and press E:
## - Hale runs the tackle stall (the shop).
## - Old Marlo (on the dock), Pip (on the beach) and Juniper (by the lane) each ask for a
##   fish. Catch one that fits and it's kept for them; bring it over for a reward. Between
##   requests they pass on tips about what's biting right now.
## - The cats can be petted. They purr.
## - Sparkles on the sand are finds to dig up: shells, sea glass, the odd treasure.
##   Low tide uncovers more beach, and more of them.

const Sea := preload("res://scripts/sea.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TALK_RANGE := 1.9
const CAT_RANGE := 1.3
const COMB_RANGE := 1.3
const COMB_SPOTS := 3
const COMB_W := [30.0, 12.0, 4.5, 1.2, 0.2]
# Who asks for what: the fishing ground they care about.
const ASKERS := {"Old Marlo": "harbour", "Pip": "shallows", "Juniper": ""}
const QUIPS := {
	"Old Marlo": [
		"Big shadow, big fish. Cast just past it and let it come to you.",
		"Reel while it rests. When it runs, steer against it. When it dives, let it.",
		"Calamari won't touch bread. Hale sells a squid jig.",
		"Luderick eat weed, and nothing else. Stubborn fish.",
	],
	"Pip": [
		"I caught a rubber duck once! It fought like a shark.",
		"Tailor jump like crazy. Let go when they're in the air!",
		"The sand side's the Sandy Shallows. Different fish over here!",
		"Low tide's best for flathead. They sit right on the bottom.",
	],
	"Juniper": [
		"A golden fish? My nan saw one once. One in four hundred, she said.",
		"Worms from Hale beat my bread for bream, I'll admit it.",
		"Storms bring the big sharks in close. Mind yourself out there.",
		"Weather turns every four hours or so. Keep an eye on the sky.",
	],
}

var harbour: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var shop: CanvasLayer
var _bubbles := {}  # name -> Label3D
var _bubble_t := {}
var _heart_tex: ImageTexture
var _sparkle_tex: ImageTexture
var _comb: Array[Sprite3D] = []
var _comb_wait := 3.0
var _rng := RandomNumberGenerator.new()
var _day := -1


func setup(h: Node3D, p: CharacterBody3D, u: CanvasLayer, a: Node, s: Node, sv: Dictionary, sh: CanvasLayer) -> void:
	harbour = h
	player = p
	hud = u
	audio = a
	sea = s
	save = sv
	shop = sh
	_rng.randomize()
	_heart_tex = _make_heart()
	_sparkle_tex = _make_sparkle()
	for who in harbour.folk:
		var b := Label3D.new()
		b.font = load("res://art/fonts/pixelify_sans.woff2")
		b.font_size = 40
		b.pixel_size = 0.0055
		b.outline_size = 12
		b.modulate = Color(0.98, 0.95, 0.86)
		b.outline_modulate = Color(0.05, 0.06, 0.12)
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.no_depth_test = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.width = 520.0
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		b.visible = false
		add_child(b)
		_bubbles[who] = b
		_bubble_t[who] = 0.0
	_refresh_requests()
	hud.set_requests(save.requests)


func _process(delta: float) -> void:
	_refresh_requests()
	_update_comb(delta)
	for who in _bubbles:
		var b: Label3D = _bubbles[who]
		_bubble_t[who] = float(_bubble_t[who]) - delta
		var node: Sprite3D = harbour.folk[who].node
		b.global_position = node.global_position + Vector3(0.0, 2.25, 0.0)
		b.visible = float(_bubble_t[who]) > 0.0
		var fade := clampf(float(_bubble_t[who]) / 0.3, 0.0, 1.0)
		b.modulate.a = fade
		b.outline_modulate.a = fade


## The closest thing you could interact with here, or {} if nothing's in reach.
## You have to be facing it (or right next to it), so you can still fish beside
## Old Marlo on the dock. Returns {kind, who/node, text}.
func nearest(pos: Vector3, facing := Vector3.ZERO) -> Dictionary:
	var best := {}
	var best_d := 99.0
	var stall: Vector3 = harbour.stall_point
	var to_stall := Vector2(pos.x - stall.x, pos.z - stall.z).length()
	if to_stall < TALK_RANGE and _facing(pos, stall, facing):
		best = {"kind": "shop", "who": "Hale", "text": "Space: Shop at Hale's Tackle"}
		best_d = to_stall
	for who in harbour.folk:
		var node: Sprite3D = harbour.folk[who].node
		var d := Vector2(pos.x - node.position.x, pos.z - node.position.z).length()
		if d < TALK_RANGE and d < best_d and _facing(pos, node.position, facing):
			best_d = d
			if who == "Hale":
				best = {"kind": "shop", "who": who, "text": "Space: Shop at Hale's Tackle"}
			else:
				var req := _request_of(who)
				var text := "Space: Talk to %s" % who
				if not req.is_empty() and req.held:
					text = "Space: Give %s the %s" % [who, _name_of(req.id)]
				best = {"kind": "folk", "who": who, "text": text}
	for c in harbour.cats:
		var d := Vector2(pos.x - c.position.x, pos.z - c.position.z).length()
		if d < CAT_RANGE and d < best_d and _facing(pos, c.position, facing):
			best_d = d
			best = {"kind": "cat", "node": c, "text": "Space: Pet the cat"}
	for spot in _comb:
		var d := Vector2(pos.x - spot.position.x, pos.z - spot.position.z).length()
		if d < COMB_RANGE and d < best_d and _facing(pos, spot.position, facing):
			best_d = d
			best = {"kind": "comb", "node": spot, "text": "Space: Dig in the sand"}
	return best


func _facing(pos: Vector3, target: Vector3, facing: Vector3) -> bool:
	var to := Vector2(target.x - pos.x, target.z - pos.z)
	if facing == Vector3.ZERO or to.length() < 0.8:
		return true
	return Vector2(facing.x, facing.z).normalized().dot(to.normalized()) > 0.3


func interact(it: Dictionary) -> void:
	match it.get("kind", ""):
		"shop":
			harbour.folk_face("Hale", player.global_position)
			audio.play("click")
			shop.open()
		"cat":
			_pet(it.node)
		"comb":
			_dig(it.node)
		"folk":
			_talk(str(it.who))


## Called when you land something. If it fills a request, it's kept for that person
## and their name comes back ("" otherwise).
func claim_catch(e: Dictionary, cm: float) -> String:
	for req in save.requests:
		if req.held or req.id != e.id:
			continue
		if cm < float(req.get("min", 0.0)):
			continue
		req.held = true
		req.cm = cm
		hud.set_requests(save.requests)
		return str(req.who)
	return ""


func _talk(who: String) -> void:
	harbour.folk_face(who, player.global_position)
	var req := _request_of(who)
	if not req.is_empty() and req.held:
		var reward := int(req.reward)
		save.shells = int(save.shells) + reward
		var thanks: Dictionary = save.thanks
		thanks[who] = int(thanks.get(who, 0)) + 1
		save.requests.erase(req)
		save[_cooldown_key(who)] = sea.now() + 180.0  # a new request in about three town hours
		SaveGame.write(save)
		hud.set_shells(save.shells)
		hud.set_requests(save.requests)
		audio.play("lvl")
		audio.play("coin", -2.0)
		_say(who, "%s Here's %d Shells. Thank you!" % [_thank_line(who), reward])
		return
	if not req.is_empty():
		var need := "a %s" % _name_of(req.id)
		if float(req.get("min", 0.0)) > 0.0:
			need += " of at least %d cm" % int(req.min)
		_say(who, "Could you catch me %s? I'll pay %d Shells. %s" % [need, int(req.reward), _hint_line(str(req.id))])
		return
	_say(who, _tip(who))


func _say(who: String, line: String) -> void:
	var b: Label3D = _bubbles[who]
	b.text = "%s: %s" % [who, line]
	_bubble_t[who] = clampf(2.5 + line.length() * 0.05, 3.0, 8.0)
	audio.play("pin", -6.0, 1.0, 0.1)


## A live tip: something biting right now in this person's patch, and how to find it.
func _tip(who: String) -> String:
	if _rng.randf() < 0.45:
		var lines: Array = QUIPS.get(who, ["Lovely day for it."])
		return str(lines[_rng.randi() % lines.size()])
	var zone: String = ASKERS.get(who, "")
	if zone == "":
		zone = "harbour" if _rng.randf() < 0.5 else "shallows"
	var now: Array = []
	for e in sea.items:
		if e.cat == "fish" and e.z == zone and e.how != "pot" and int(e.r) >= 1 and sea.cond_ok(e, sea.env):
			now.append(e)
	if now.is_empty():
		return "Quiet out there for anything special. Commons are still biting."
	var pick: Dictionary = now[_rng.randi() % now.size()]
	var where := "off the beach" if zone == "shallows" else "in the harbour"
	return "%s are about %s right now. %s" % [pick.n, where, sea.hint_for(pick)]


func _hint_line(id: String) -> String:
	var e: Dictionary = sea.by_id.get(id, {})
	if e.is_empty():
		return ""
	var where := "Off the beach." if e.z == "shallows" else "In the harbour."
	return "%s %s" % [where, sea.hint_for(e)]


func _thank_line(who: String) -> String:
	match who:
		"Old Marlo":
			return "Now that's a fish."
		"Pip":
			return "Whoa, it's huge!"
	return "Perfect for tonight's pie."


func _pet(cat: Sprite3D) -> void:
	audio.play("purr", -2.0, 1.0, 0.1)
	var heart := Sprite3D.new()
	heart.texture = _heart_tex
	heart.pixel_size = 1.0 / 16.0
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	heart.no_depth_test = true
	add_child(heart)
	heart.global_position = cat.global_position + Vector3(0.0, 1.0, 0.0)
	var tw := heart.create_tween()
	tw.set_parallel(true)
	tw.tween_property(heart, "global_position:y", heart.global_position.y + 0.9, 1.0)
	tw.tween_property(heart, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(heart.queue_free)


# --- requests ------------------------------------------------------------------

func _request_of(who: String) -> Dictionary:
	for req in save.requests:
		if req.who == who:
			return req
	return {}


func _cooldown_key(who: String) -> String:
	return "next_request_" + who.to_lower().replace(" ", "_")


## Hand out requests: one per asker, fresh each town day, and a new one a few town
## hours after you fill one.
func _refresh_requests() -> void:
	var day := int(floor(sea.now() / 1440.0))
	var changed := false
	if day != int(save.get("request_day", -1)):
		save.request_day = day
		# Unfilled requests expire with the day; ones you're holding a fish for stay.
		var keep: Array = []
		for req in save.requests:
			if req.held:
				keep.append(req)
		save.requests = keep
		changed = true
	for who in ASKERS:
		if not _request_of(who).is_empty():
			continue
		if sea.now() < float(save.get(_cooldown_key(who), 0.0)):
			continue
		var req := _new_request(who)
		if not req.is_empty():
			save.requests.append(req)
			changed = true
	if changed:
		SaveGame.write(save)
		if hud:
			hud.set_requests(save.requests)


func _new_request(who: String) -> Dictionary:
	var zone: String = ASKERS[who]
	var pool: Array = []
	for e in sea.items:
		if e.cat != "fish" or e.how == "pot" or int(e.r) > 2:
			continue
		if zone != "" and e.z != zone:
			continue
		if e.z != "harbour" and e.z != "shallows":
			continue
		var p: Dictionary = e.cp
		if p.get("season") != null and p.season != sea.env.season:
			continue  # only ask for fish you can catch this week
		if p.get("moon") != null or p.get("sky") in ["storm", "fog", "afterstorm"]:
			continue
		var taken := false
		for other in save.requests:
			if other.id == e.id:
				taken = true
		if not taken:
			pool.append([e, [6.0, 3.0, 1.0][int(e.r)]])
	var choice: Variant = Sea.pick_w(pool, _rng.randf())
	if choice == null:
		return {}
	var min_cm := 0.0
	var sz: Array = choice.sz
	if _rng.randf() < 0.3:
		min_cm = snappedf(float(sz[0]) + (float(sz[1]) - float(sz[0])) * 0.5, 1.0)
	var reward := int(round(float(choice.price) * (3.0 if min_cm > 0.0 else 2.2) + 15.0))
	return {"who": who, "id": choice.id, "min": min_cm, "reward": reward, "held": false, "cm": 0.0}


func _name_of(id: String) -> String:
	var e: Dictionary = sea.by_id.get(id, {})
	return str(e.get("n", id))


# --- beachcombing ------------------------------------------------------------------

func _update_comb(delta: float) -> void:
	var sea_y: float = harbour.sea_level
	for spot in _comb.duplicate():
		if harbour.beach_y(spot.position.z) < sea_y + 0.05:
			_comb.erase(spot)  # the tide came in over it
			spot.queue_free()
	for spot in _comb:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + spot.position.x)
		spot.modulate.a = 0.45 + k * 0.55
		spot.pixel_size = (1.0 / 16.0) * (0.7 + k * 0.4)
	if _comb.size() >= COMB_SPOTS:
		return
	_comb_wait -= delta
	if _comb_wait > 0.0:
		return
	_comb_wait = _rng.randf_range(20.0, 40.0)
	# Somewhere on dry sand: from the grass edge down to just above the waterline.
	var wet_z := (0.6 - (sea_y + 0.12)) / 0.12 - 4.0  # inverse of harbour.beach_y()
	if wet_z < -3.3:
		return
	var z := _rng.randf_range(-3.4, wet_z)
	var x := _rng.randf_range(-34.0, -14.0)
	var spot := Sprite3D.new()
	spot.texture = _sparkle_tex
	spot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spot.shaded = false
	spot.no_depth_test = false
	spot.position = Vector3(x, harbour.beach_y(z) + 0.15, z)
	add_child(spot)
	_comb.append(spot)


func _dig(spot: Sprite3D) -> void:
	_comb.erase(spot)
	spot.queue_free()
	var E: Dictionary = sea.env
	var low: bool = float(E.tide) < 0.1
	var table: Array = []
	for e in sea.items:
		if e.how != "comb" or e.z != "beach" or not sea.cond_ok(e, E):
			continue
		table.append([e, float(COMB_W[mini(int(e.r), 4)]) * (1.0 if low else 0.35)])
	if sea.by_id.has("seaweed_clump"):
		table.append([sea.by_id.seaweed_clump, 4.0])
	var found: Variant = Sea.pick_w(table, _rng.randf())
	if found == null:
		audio.play("thud", -6.0)
		hud.toast("Just sand.")
		return
	var book: Dictionary = save.log
	var entry: Dictionary = book.get(found.id, {})
	var is_new := entry.is_empty()
	entry["count"] = int(entry.get("count", 0)) + 1
	book[found.id] = entry
	var value := int(found.price)
	save.shells = int(save.shells) + value
	var stats: Dictionary = save.stats
	stats["finds"] = int(stats.get("finds", 0)) + 1
	SaveGame.write(save)
	hud.set_shells(save.shells)
	audio.play("crank", -4.0)
	if int(found.r) >= 2:
		audio.play("fanfare2", -4.0)
	elif is_new:
		audio.play("fanfare1", -4.0)
	else:
		audio.play("coin", -4.0)
	var line := "Dug up %s! +%d Shells" % [_with_article(str(found.n)), value]
	if is_new:
		line += "  New in your Logbook!"
	hud.toast(line)


func _with_article(n: String) -> String:
	if n.begins_with("The "):
		return n
	var first := n.substr(0, 1).to_lower()
	return ("an " if "aeiou".contains(first) else "a ") + n


func _make_sparkle() -> ImageTexture:
	var rows := ["...X...", "...X...", ".X.X.X.", "XXXXXXX", ".X.X.X.", "...X...", "...X..."]
	var img := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "X":
				img.set_pixel(x, y, Color(1.0, 1.0, 0.85) if (x == 3 or y == 3) else Color(1.0, 0.9, 0.5, 0.8))
	return ImageTexture.create_from_image(img)


func _make_heart() -> ImageTexture:
	var rows := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
	var img := Image.create_empty(7, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "X":
				img.set_pixel(x, y, Color(1.0, 0.42, 0.55) if y > 0 or x % 3 != 1 else Color(1.0, 0.75, 0.82))
	return ImageTexture.create_from_image(img)
