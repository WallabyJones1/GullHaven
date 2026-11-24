extends Node
## Your fisher level. Everything you land earns XP (more for harder fish, bigger ones, clean
## fights and anything new to your Logbook); so do townsfolk requests, the Gull's Eye and
## the story. Each level brings a skill point to spend (game menu, Fisher) and opens up new
## gear and ways to fish: crab pots, the cast net, trolling and spearfishing.

const UI := preload("res://scripts/ui_kit.gd")
const Sea := preload("res://scripts/sea.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const MAX_LEVEL := 30
const SKILLS := {
	"steady": {"n": "Steady hands", "d": "Tension builds %d%% slower, and the reel bar's zone is wider", "per": 8, "max": 4},
	"arms": {"n": "Strong arms", "d": "Reel in %d%% faster", "per": 8, "max": 4},
	"patience": {"n": "Patience", "d": "Fish come to your bait %d%% sooner", "per": 10, "max": 4},
	"eye": {"n": "Keen eye", "d": "Uncommon and rarer fish bite %d%% more often", "per": 6, "max": 4},
	"haggle": {"n": "Haggler", "d": "Everything you land is worth %d%% more", "per": 5, "max": 4},
	"sea_legs": {"n": "Sea legs", "d": "Boats go %d%% faster, and crab pots fill sooner", "per": 6, "max": 4},
}
const SKILL_ORDER := ["steady", "arms", "patience", "eye", "haggle", "sea_legs"]
# what opens up at each level
const UNLOCKS := {
	2: "Crab pots at Hale's Tackle (the Kit tab)",
	3: "Glass rods, spin reels and 8 kg line",
	4: "The cast net: throw it over bait schools for live bait and small fish",
	5: "Trolling lines: tow lures behind a moving boat for the fast fish",
	6: "Snorkel and speargun: dive from a stopped boat over clear water",
	7: "Graphite rods and baitcasters",
	8: "15 kg braid",
	10: "Boron rods and deep reels",
	12: "40 kg braid",
	15: "The Gullwing Custom and the electric deep reel",
	20: "Master Fisher of Gullhaven",
	30: "Legend of the coast",
}
# the fisher level each tier of gear needs
const GEAR_LEVEL := {"rod": [1, 3, 7, 10, 15], "reel": [1, 3, 7, 10, 15], "line": [1, 3, 8, 12]}
const KIT_LEVEL := {"pot": 2, "net": 4, "troll": 5, "spear": 6}
const TITLES := [[1, "Beginner"], [3, "Angler"], [6, "Fisher"], [10, "Seasoned fisher"], [15, "Old salt"], [20, "Master fisher"],
	[30, "Legend of the coast"]]

signal levelled(lv: int)

var save: Dictionary
var hud: CanvasLayer
var audio: Node


func setup(sv: Dictionary, h: CanvasLayer, a: Node) -> void:
	save = sv
	hud = h
	audio = a
	hud.set_level(level(), fraction())


func _f() -> Dictionary:
	return save.fisher


func level() -> int:
	return int(_f().get("level", 1))


func points() -> int:
	return int(_f().get("points", 0))


func title() -> String:
	var out := "Beginner"
	for t in TITLES:
		if level() >= int(t[0]):
			out = str(t[1])
	return out


## XP from one level to the next.
static func need(lv: int) -> int:
	return int(round(40.0 * pow(float(lv), 1.4) + 40.0))


## How far through this level you are (0 to 1).
func fraction() -> float:
	if level() >= MAX_LEVEL:
		return 1.0
	return clampf(float(_f().get("xp", 0)) / float(need(level())), 0.0, 1.0)


func rank(skill: String) -> int:
	var sk: Dictionary = _f().get("skills", {})
	return int(sk.get(skill, 0))


## A skill as a multiplier: 1.0 plus its bonus (more), or minus it (less).
func more(skill: String) -> float:
	return 1.0 + float(SKILLS[skill].per) * rank(skill) / 100.0


func less(skill: String) -> float:
	return 1.0 - float(SKILLS[skill].per) * rank(skill) / 100.0


func gear_ok(kind: String, tier: int) -> bool:
	var need_lv: Array = GEAR_LEVEL.get(kind, [])
	return tier >= need_lv.size() or level() >= int(need_lv[tier])


func gear_level(kind: String, tier: int) -> int:
	var need_lv: Array = GEAR_LEVEL.get(kind, [])
	return 1 if tier >= need_lv.size() else int(need_lv[tier])


func kit_ok(what: String) -> bool:
	return level() >= int(KIT_LEVEL.get(what, 1))


## Earn some XP. why shows in a little float-up ("+24 XP") if there's somewhere to show it.
func add(amount: int, why := "") -> void:
	if amount <= 0:
		return
	var f := _f()
	f["total"] = int(f.get("total", 0)) + amount
	if level() < MAX_LEVEL:
		f["xp"] = int(f.get("xp", 0)) + amount
		while level() < MAX_LEVEL and int(f.xp) >= need(level()):
			f["xp"] = int(f.xp) - need(level())
			f["level"] = level() + 1
			f["points"] = points() + 1
			_announce(level())
	hud.set_level(level(), fraction())
	if why != "":
		hud.toast("+%d XP: %s" % [amount, why])


## The XP something you land is worth.
func xp_for(e: Dictionary, cm: float, tier: String, is_new: bool) -> int:
	var cat := str(e.get("cat", ""))
	var base := 3.0
	if cat == "fish" or cat == "legend":
		base = 8.0 * pow(float(Sea.difficulty(e)), 1.6)
		if cm > 0.0:
			base *= 0.8 + 0.4 * Sea.size_frac(e, cm)
		base *= float({"Perfect": 1.3, "Great": 1.15}.get(tier, 1.0))
		if cat == "legend":
			base *= 2.0
	elif cat != "junk":
		base = 6.0 + 4.0 * int(e.get("r", 0))
	if is_new:
		base *= 2.5
	return maxi(1, int(round(base)))


func spend(skill: String) -> bool:
	if points() <= 0 or rank(skill) >= int(SKILLS[skill].max):
		return false
	var f := _f()
	var sk: Dictionary = f.get("skills", {})
	sk[skill] = rank(skill) + 1
	f["skills"] = sk
	f["points"] = points() - 1
	SaveGame.write(save)
	audio.play("lvl", -4.0)
	return true


func _announce(lv: int) -> void:
	audio.play("lvl")
	audio.play("fanfare2", -4.0)
	var sub := "+1 skill point. Spend it in the game menu, under Fisher."
	if UNLOCKS.has(lv):
		sub = "%s.   +1 skill point" % str(UNLOCKS[lv])
	hud.show_banner("Fisher level %d!" % lv, sub)
	if UNLOCKS.has(lv):
		hud.toast("New at level %d: %s." % [lv, str(UNLOCKS[lv])])
	SaveGame.write(save)
	levelled.emit(lv)


## The Fisher page of the game menu: level, XP, skills to spend points on.
func fill_page(box: VBoxContainer, refresh: Callable) -> void:
	var head := UI.label("Level %d   %s" % [level(), title()], 30, UI.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var xp_line := "Level %d of %d" % [level(), MAX_LEVEL]
	if level() < MAX_LEVEL:
		xp_line = "%d / %d XP to level %d" % [int(_f().get("xp", 0)), need(level()), level() + 1]
	var xl := UI.label(xp_line, 20, UI.SKY)
	xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(xl)
	var next := ""
	for lv in range(level() + 1, MAX_LEVEL + 1):
		if UNLOCKS.has(lv):
			next = "Next, at level %d: %s" % [lv, str(UNLOCKS[lv])]
			break
	if next != "":
		var nl := UI.label(next, 18, UI.CREAM)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(600.0, 0.0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nl)
	var pts := UI.label("Skill points to spend: %d" % points(), 22, UI.GOOD if points() > 0 else UI.DIM, true)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pts)
	for k in SKILL_ORDER:
		var sk: Dictionary = SKILLS[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(UI.label("%s   %d/%d" % [str(sk.n), rank(k), int(sk.max)], 20, UI.CREAM, true))
		var now := float(sk.per) * rank(k)
		var d := UI.label(str(sk.d) % int(maxf(now, float(sk.per))) + ("" if rank(k) > 0 else " (first rank)"), 16, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(440.0, 0.0)
		words.add_child(d)
		row.add_child(words)
		var b := UI.button("+", 22)
		b.custom_minimum_size = Vector2(56.0, 0.0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if points() <= 0 or rank(k) >= int(sk.max):
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		else:
			b.pressed.connect(_spend_and.bind(k, refresh))
		row.add_child(b)
		box.add_child(row)


func _spend_and(skill: String, refresh: Callable) -> void:
	if spend(skill):
		refresh.call()
