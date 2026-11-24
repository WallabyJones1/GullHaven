extends Node
## The people (and cats) of every town. Face someone and press Space:
## - Shopkeepers open their shop. Other systems (the tackle shop, the boatyard, the
##   carpenter, the fishmonger...) register what their kind of shop does.
## - Anyone with an "ask" role wants a fish from their patch of water. Catch one that fits
##   and it's kept for them; bring it over for a reward. Between requests they, and the
##   locals with tips, tell you what's biting nearby right now.
## - Cats can be petted. They purr.
## - Sparkles on dry sandy shores are finds to dig up: shells, sea glass, the odd
##   treasure. Low tide uncovers more beach.

const Sea := preload("res://scripts/sea.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TALK_RANGE := 2.0
const CAT_RANGE := 1.3
const COMB_RANGE := 1.3
const COMB_SPOTS := 3
const COMB_W := [30.0, 12.0, 4.5, 1.2, 0.2]
# The water each town knows best, for tips.
const TOWN_ZONE := {"gullhaven": "harbour", "willowford": "estuary", "mirrorlake": "lake", "tideglass": "shallows",
	"mossbank": "reef", "kelpwood": "kelp", "lantern": "kelp", "cove": "wreck", "ember": "blue"}
const QUIPS := {
	"Old Marlo": [
		"Big shadow, big fish. Cast just past it and let it come to you.",
		"Reel while it rests. When it runs, steer against it. When it dives, let it.",
		"Calamari won't touch bread. Hale sells a squid jig.",
		"The further out you go, the stranger the fish. You'll want a bigger boat.",
	],
	"Pip": [
		"I caught a rubber duck once! It fought like a shark.",
		"Tailor jump like crazy. Let go when they're in the air!",
		"Low tide's best for flathead. They sit right on the bottom.",
		"Dig where the sand sparkles! I found a ship in a bottle once.",
	],
	"Juniper": [
		"A golden fish? My nan saw one once. One in four hundred, she said.",
		"Worms from Hale beat my bread for bream, I'll admit it.",
		"Storms bring the big sharks in close. Mind yourself out there.",
	],
}
const GENERIC := [
	"Lovely day for it.",
	"The weather turns every few hours. Keep an eye on the sky.",
	"Have you been up the river to Willowford? The mill's worth seeing.",
	"They say there's a lake up in the hills that's clear as glass.",
	"Fog hangs round Kelpwood. Folk say you need a lamp to find it.",
]

var harbour: Node3D  # the world
var player: CharacterBody3D
var hud: CanvasLayer
var audio: Node
var sea: Node
var save: Dictionary
var shop: CanvasLayer
var services := {}  # shop kind -> Callable(keeper: String, title: String, kind: String)
var _bubbles := {}  # name -> Label3D
var _bubble_t := {}
var _heart_tex: ImageTexture
var _sparkle_tex: ImageTexture
var _comb: Array[Sprite3D] = []
var _comb_wait := 3.0
var _rng := RandomNumberGenerator.new()
var _font: Font


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
	_font = load("res://art/fonts/pixelify_sans.woff2")
	for kind in ["tackle", "general", "baittea", "kelptea"]:
		services[kind] = shop.open
	_refresh_requests()
	hud.set_requests(save.requests)


## Let another system handle a kind of shop (boatyard, carpenter, fishmonger...).
func register_service(kind: String, handler: Callable) -> void:
	services[kind] = handler


func _process(delta: float) -> void:
	_refresh_requests()
	_update_comb(delta)
	for who in _bubbles.keys():
		var b: Label3D = _bubbles[who]
		_bubble_t[who] = float(_bubble_t[who]) - delta
		if not harbour.folk.has(who):
			continue
		var node: Sprite3D = harbour.folk[who].node
		b.global_position = node.global_position + Vector3(0.0, 2.25, 0.0)
		b.visible = float(_bubble_t[who]) > 0.0
		var fade := clampf(float(_bubble_t[who]) / 0.3, 0.0, 1.0)
		b.modulate.a = fade
		b.outline_modulate.a = fade


## The closest thing you could interact with, or {} if nothing's in reach. You have to be
## facing it (or right next to it), so you can still fish beside someone on a dock.
func nearest(pos: Vector3, facing := Vector3.ZERO) -> Dictionary:
	var best := {}
	var best_d := 99.0
	for who in harbour.folk:
		var f: Dictionary = harbour.folk[who]
		var node: Sprite3D = f.node
		if not node.visible:
			continue
		var np := node.global_position
		var d := Vector2(pos.x - np.x, pos.z - np.z).length()
		if d < TALK_RANGE and d < best_d and absf(pos.y - np.y) < 2.0 and _facing(pos, np, facing):
			best_d = d
			var role := str(f.role)
			var text := "Space: Talk to %s" % who
			if role.begins_with("shop:"):
				text = "Space: %s" % _shop_title(who, f)
			var req := _request_of(who)
			if not req.is_empty() and req.held:
				text = "Space: Give %s the %s" % [who, _name_of(req.id)]
			best = {"kind": "folk", "who": who, "text": text}
	for c: Sprite3D in harbour.cats:
		var cp := c.global_position
		var d := Vector2(pos.x - cp.x, pos.z - cp.z).length()
		if d < CAT_RANGE and d < best_d and _facing(pos, cp, facing):
			best_d = d
			best = {"kind": "cat", "node": c, "text": "Space: Pet the cat"}
	for spot in _comb:
		var sp := spot.global_position
		var d := Vector2(pos.x - sp.x, pos.z - sp.z).length()
		if d < COMB_RANGE and d < best_d and _facing(pos, sp, facing):
			best_d = d
			best = {"kind": "comb", "node": spot, "text": "Space: Dig in the sand"}
	return best


func interact(it: Dictionary) -> void:
	match str(it.get("kind", "")):
		"cat":
			_pet(it.node)
		"comb":
			_dig(it.node)
		"folk":
			_talk(str(it.who))


## Called when you land something. If it fills a request, it's kept for that person and
## their name comes back ("" otherwise).
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


func _facing(pos: Vector3, target: Vector3, facing: Vector3) -> bool:
	var to := Vector2(target.x - pos.x, target.z - pos.z)
	if facing == Vector3.ZERO or to.length() < 0.8:
		return true
	return Vector2(facing.x, facing.z).normalized().dot(to.normalized()) > 0.3


func _shop_title(who: String, f: Dictionary) -> String:
	var kind := str(f.role).substr(5)
	for b in harbour.buildings:
		if b.role == kind and b.town == f.town:
			return "Visit %s" % b.name
	return "Talk to %s" % who


func _talk(who: String) -> void:
	harbour.folk_face(who, player.global_position)
	var f: Dictionary = harbour.folk[who]
	var role := str(f.role)
	var req := _request_of(who)
	if not req.is_empty() and req.held:
		_deliver(who, req)
		return
	if role.begins_with("shop:"):
		var kind := role.substr(5)
		var title := _shop_title(who, f).trim_prefix("Visit ")
		if services.has(kind):
			audio.play("click")
			services[kind].call(who, title, kind)
			return
		_say(who, _closed_line(kind))
		return
	if not req.is_empty():
		var need := "a %s" % _name_of(req.id)
		if float(req.get("min", 0.0)) > 0.0:
			need += " of at least %d cm" % int(req.min)
		_say(who, "Could you catch me %s? I'll pay %d Shells. %s" % [need, int(req.reward), _hint_line(str(req.id))])
		return
	_say(who, _tip(who, f))


func _deliver(who: String, req: Dictionary) -> void:
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
	var lines := ["Now that's a fish.", "Whoa, it's huge!", "Perfect for tonight's supper.", "Just what I needed!"]
	_say(who, "%s Here's %d Shells. Thank you!" % [lines[_rng.randi() % lines.size()], reward])


func _closed_line(kind: String) -> String:
	match kind:
		"boatyard", "boatworks":
			return "Boats are my trade. Come back soon and we'll talk hulls."
		"carpenter", "home":
			return "I can build you anything, given planks and time. Soon!"
		"fishmonger", "salvager":
			return "Bring your catch by any time. We'll sort a fair price."
		"museum":
			return "The aquarium will want every fish in the sea, one day."
		"ranger":
			return "The hills past the gate are closed for now. Ask me again later."
		"tavern", "inn", "lodge":
			return "Sit, rest your arms. The fish will still be there."
		"harbourmaster":
			return "Mind the channel markers, and the weather."
		"forge":
			return "Hot work, this. What do you need?"
	return "Welcome!"


func _say(who: String, line: String) -> void:
	if not _bubbles.has(who):
		var b := Label3D.new()
		b.font = _font
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
		add_child(b)
		_bubbles[who] = b
	var label: Label3D = _bubbles[who]
	label.text = "%s: %s" % [who, line]
	_bubble_t[who] = clampf(2.5 + line.length() * 0.05, 3.0, 8.0)
	audio.play("pin", -6.0, 1.0, 0.1)


## A live tip: something special biting in this person's patch right now.
func _tip(who: String, f: Dictionary) -> String:
	if _rng.randf() < 0.4:
		var lines: Array = QUIPS.get(who, GENERIC)
		return str(lines[_rng.randi() % lines.size()])
	var zone := _zone_for(f)
	var now: Array = []
	for e in sea.items:
		if e.cat == "fish" and e.z == zone and e.how != "pot" and int(e.r) >= 1 and sea.cond_ok(e, sea.env):
			now.append(e)
	if now.is_empty():
		return "Quiet out there for anything special. The common fish are still biting."
	var pick: Dictionary = now[_rng.randi() % now.size()]
	return "%s are about in the %s right now. %s" % [pick.n, _zone_name(zone), sea.hint_for(pick)]


func _zone_for(f: Dictionary) -> String:
	var role := str(f.role)
	if role.begins_with("ask:"):
		var z := role.substr(4)
		if z != "any":
			return z
	return str(TOWN_ZONE.get(str(f.town), "harbour"))


func _zone_name(zone: String) -> String:
	var z: Dictionary = sea.zones.get(zone, {})
	return str(z.get("n", zone))


func _hint_line(id: String) -> String:
	var e: Dictionary = sea.by_id.get(id, {})
	if e.is_empty():
		return ""
	return "Try the %s. %s" % [_zone_name(str(e.z)), sea.hint_for(e)]


func _pet(cat: Sprite3D) -> void:
	audio.play("purr", -2.0, 1.0, 0.1)
	_float_icon(_heart_tex, cat.global_position + Vector3(0.0, 1.0, 0.0))


func _float_icon(tex: Texture2D, at: Vector3) -> void:
	var icon := Sprite3D.new()
	icon.texture = tex
	icon.pixel_size = 1.0 / 16.0
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	icon.no_depth_test = true
	add_child(icon)
	icon.global_position = at
	var tw := icon.create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "global_position:y", at.y + 0.9, 1.0)
	tw.tween_property(icon, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(icon.queue_free)


# --- requests ------------------------------------------------------------------

func _request_of(who: String) -> Dictionary:
	for req in save.requests:
		if req.who == who:
			return req
	return {}


func _cooldown_key(who: String) -> String:
	return "next_request_" + who.to_lower().replace(" ", "_").replace(".", "")


func _askers() -> Array:
	var out: Array = []
	for who in harbour.folk:
		if str(harbour.folk[who].role).begins_with("ask:"):
			out.append(who)
	return out


## Hand out requests: one per asker, fresh each town day, and a new one a few town hours
## after you fill one.
func _refresh_requests() -> void:
	var day := int(floor(sea.now() / 1440.0))
	var changed := false
	if day != int(save.get("request_day", -1)):
		save.request_day = day
		var keep: Array = []
		for req in save.requests:
			if req.held:
				keep.append(req)
		save.requests = keep
		changed = true
	for who in _askers():
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
	var zone := str(harbour.folk[who].role).substr(4)
	var zones: Array = ["harbour", "shallows"] if zone == "any" else [zone]
	var pool: Array = []
	for e in sea.items:
		if e.cat != "fish" or e.how == "pot" or int(e.r) > 2 or not zones.has(e.z):
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
	var here := player.global_position
	for spot: Sprite3D in _comb.duplicate():
		var sp := spot.global_position
		var covered: bool = harbour.height_at(sp.x, sp.z) < float(harbour.sea_level) + 0.05
		if covered or sp.distance_to(here) > 60.0:
			_comb.erase(spot)
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
	_comb_wait = _rng.randf_range(8.0, 18.0)
	# somewhere on dry sand near you
	var comb_flag := int(harbour.F.comb)
	for attempt in 24:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, 26.0)
		var x := here.x + cos(a) * r
		var z := here.z + sin(a) * r
		if not (harbour.flags_at(x, z) & comb_flag):
			continue
		var h: float = harbour.height_at(x, z)
		if h < float(harbour.sea_level) + 0.12:
			continue
		var spot := Sprite3D.new()
		spot.texture = _sparkle_tex
		spot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spot.shaded = false
		add_child(spot)
		spot.global_position = Vector3(x, h + 0.15, z)
		_comb.append(spot)
		return


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
