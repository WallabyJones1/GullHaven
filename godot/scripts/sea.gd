extends Node
## The sea's rules, ported from the web game (src/js/m04e_env.js) so both games agree.
## Time, tide, weather, moon and season all come from the real clock:
## - one real second is one town minute, so a town day lasts 24 real minutes
## - tides turn every 6 town hours; the weather changes every 4 town hours
## - the moon runs a full cycle each real week, and each season lasts one real week
## Also holds the catalogue, bait and gear tables exported from the web game
## (data/catalog.json, made by tools/export_godot_assets.py).

const SEASONS := ["spring", "summer", "autumn", "winter"]
const SKIES := ["calm", "windy", "rain", "fog", "storm"]
const SKY_WEIGHTS := [
	[0.42, 0.2, 0.18, 0.12, 0.08],  # spring
	[0.52, 0.2, 0.12, 0.06, 0.1],  # summer
	[0.4, 0.26, 0.14, 0.1, 0.1],  # autumn
	[0.34, 0.2, 0.18, 0.1, 0.18],  # winter
]
const SNAG_W := [3.0, 1.4, 0.55, 0.18, 0.05]
const HOOK_W := [1.6, 0.7, 0.3, 0.1]
const JUNK_W := [2.2, 0.6, 0.2]
const CLASS_LEN := [0.45, 0.8, 1.3, 1.8]  # shadow length (m) for each size class

var items: Array = []
var by_id := {}
var bait := {}
var bait_order: Array = []
var gear := {}
var rarity: Array = []
var rarw: Array = []
var zones := {}
var epoch_ms := 0.0
var offset := 0.0  # seconds added to the real clock (T skips ahead an hour)
var env := {}  # conditions right now, refreshed every frame


func setup(clock_offset: float) -> void:
	offset = clock_offset
	var f := FileAccess.open("res://data/catalog.json", FileAccess.READ)
	if f == null:
		push_error("Missing res://data/catalog.json (run tools/export_godot_assets.py)")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	items = data.get("items", [])
	# the Godot build's own additions (new fish, legends and finds)
	var fx := FileAccess.open("res://data/catalog_extra.json", FileAccess.READ)
	if fx:
		var extra: Variant = JSON.parse_string(fx.get_as_text())
		if extra is Dictionary:
			items.append_array(extra.get("items", []))
	for e in items:
		by_id[e.id] = e
	bait = data.get("bait", {})
	bait_order = data.get("bait_order", [])
	gear = data.get("gear", {})
	rarity = data.get("rarity", [])
	rarw = data.get("rarw", [60, 25, 10, 3.6, 0.2])
	zones = data.get("zones", {})
	epoch_ms = float(data.get("epoch", 1767571200000.0))
	env = env_at(now())


func _process(_delta: float) -> void:
	env = env_at(now())


func now() -> float:
	return Time.get_unix_time_from_system() + offset


## Skip the town clock ahead (one town hour = 60 real seconds).
func skip_hours(h: float) -> void:
	offset += h * 60.0
	env = env_at(now())


# --- conditions ------------------------------------------------------------------

func env_at(t: float) -> Dictionary:
	var sec := int(floor(t))
	var hour := fposmod(t, 1440.0) / 60.0
	var weeks := (t * 1000.0 - epoch_ms) / (7.0 * 86400000.0)
	var si := posmod(int(floor(weeks)), 4)
	var phase := fposmod(weeks, 1.0)
	var moon := ""
	if phase < 1.0 / 14.0 or phase > 13.0 / 14.0:
		moon = "newmoon"
	elif absf(phase - 0.5) < 1.0 / 14.0:
		moon = "fullmoon"
	# High tide at 00:00 and 12:00, low at 06:00 and 18:00 (town time).
	var ang := hour / 12.0 * TAU
	var tide := cos(ang)
	var rising := sin(ang) < 0.0
	var tide_state := "high" if tide > 0.6 else ("low" if tide < -0.6 else ("rising" if rising else "falling"))
	var block := int(floor(sec / 240.0))
	var sky := sky_at(block, si)
	var prev := sky_at(block - 1, si)
	var wind := 0.2
	match sky:
		"storm":
			wind = 1.0
		"windy":
			wind = 0.7
		"rain":
			wind = 0.45
		"fog":
			wind = 0.05
	return {
		"t": t, "hour": hour, "season": SEASONS[si], "si": si, "moon": moon, "moon_phase": phase,
		"tide": tide, "rising": rising, "tide_state": tide_state,
		"king": moon == "fullmoon" and tide > 0.6,
		"sky": sky, "after": sky != "storm" and prev == "storm", "next_sky": sky_at(block + 1, si),
		"block_left": 240 - posmod(sec, 240), "wind": wind,
	}


func sky_at(block: int, season: int) -> String:
	var x := hsh(block, 77, season)
	var w: Array = SKY_WEIGHTS[season]
	for i in 5:
		if x < float(w[i]):
			return SKIES[i]
		x -= float(w[i])
	return "calm"


static func time_ok(w: String, h: float) -> bool:
	match w:
		"day":
			return h >= 6.5 and h < 17.5
		"night":
			return h >= 19.0 or h < 5.5
		"dawn":
			return h >= 4.5 and h < 7.5
		"dusk":
			return h >= 16.5 and h < 19.5
		"dawn/dusk":
			return (h >= 4.5 and h < 7.5) or (h >= 16.5 and h < 19.5)
		"dusk/night":
			return h >= 16.5 or h < 5.5
		"midnight":
			return h >= 23.0 or h < 1.0
	return true


static func tide_ok(w: String, E: Dictionary) -> bool:
	match w:
		"rising":
			return E.rising
		"falling":
			return not E.rising
		"high":
			return E.tide > 0.45
		"low":
			return E.tide < -0.45
		"kingtide":
			return E.king
	return true


static func sky_ok(w: String, E: Dictionary) -> bool:
	if w == "":
		return true
	if w == "afterstorm":
		return E.after
	return E.sky == w


## Can this entry turn up right now? (Bait is a preference, never a gate.)
func cond_ok(e: Dictionary, E: Dictionary) -> bool:
	var p: Dictionary = e.cp
	if p.get("time") != null and not time_ok(str(p.time), E.hour):
		return false
	if p.get("tide") != null and not tide_ok(str(p.tide), E):
		return false
	if p.get("sky") != null and not sky_ok(str(p.sky), E):
		return false
	if p.get("season") != null and E.season != p.season:
		return false
	if p.get("moon") != null and E.moon != p.moon:
		return false
	var method: Array = p.get("method", [])
	if method.has("deepreel") or method.has("lamp"):
		return false  # needs gear this harbour doesn't sell yet
	if p.get("where") != null:
		return false
	var flags: Array = p.get("flags", [])
	if flags.has("oddone") or flags.has("gift") or flags.has("quest"):
		return false  # these turn up some other way (the mystery hands out its own)
	if flags.has("spawn"):
		return E.moon == "fullmoon" and E.season == "summer" and time_ok("night", E.hour)
	return true


# --- what bites ------------------------------------------------------------------

func bait_mul(bk: String, e: Dictionary) -> float:
	var b: Dictionary = bait.get(bk, bait.get("dough", {}))
	var rr: Array = b.get("r", [1, 1, 1, 1])
	var m := float(rr[mini(3, int(e.r))])
	var like: Array = b.get("like", [])
	if like.has(e.art):
		m *= 1.5
	var bz: Dictionary = b.get("z", {})
	if bz.has(e.z):
		m *= float(bz[e.z])
	var want: Variant = e.cp.get("bait")
	if want != null:
		m *= 4.0 if want == bk else 0.35
	if bk == "weedbait" and want != "weedbait":
		m *= 0.3
	return m


static func size_class(e: Dictionary) -> int:
	var sz: Variant = e.get("sz")
	if sz == null:
		return 0
	var top := float(sz[1])
	if top < 32.0:
		return 0
	if top < 90.0:
		return 1
	if top < 220.0:
		return 2
	return 3


const DIFFICULTY_NAMES := ["", "Easy", "Steady", "Tricky", "Tough", "Fearsome"]
const STRONG_SHAPES := ["torp", "gar", "squid", "cuttle", "octo", "shark", "tuna", "marlin", "sail", "mahi", "wobbe"]
const GENTLE_SHAPES := ["seahorse", "dragon", "crab", "puffer", "clown", "idol", "lantern", "flying", "lobster"]


## How hard something fights, 1 (easy) to 5 (fearsome): rarer, bigger and faster fish fight
## harder; seahorses and their kin never really fight. Legends are always 5.
static func difficulty(e: Dictionary) -> int:
	var cat := str(e.get("cat", ""))
	if cat == "legend":
		return 5
	if cat != "fish":
		return 1
	if e.has("diff"):
		return clampi(int(e.diff), 1, 5)
	var r := int(e.get("r", 0))
	var d := 1 + r
	var cls := size_class(e)
	if cls >= 2:
		d += 1
	var art := str(e.get("art", ""))
	if art in STRONG_SHAPES and cls >= 1:
		d += 1
	if art in GENTLE_SHAPES:
		d = mini(d, 2 + (1 if r >= 2 else 0))
	return clampi(d, 1, 5)


## Everything that could take the hook on this cast, as [entry, weight] pairs.
## shadow_r is the size class of the shadow that came to the bait (-1 for any).
## rare_boost multiplies the odds of uncommon and better fish (feeding frenzies).
func hook_table(zone: String, bk: String, rod_t: int, shadow_r := -1, rare_boost := 1.0) -> Array:
	var E := env
	var out: Array = []
	var b: Dictionary = bait.get(bk, {})
	var night := time_ok("night", E.hour)
	for e in items:
		var cat: String = e.cat
		var how: String = e.how
		var r := int(e.r)
		if cat == "fish":
			if e.z != zone or how == "pot" or not cond_ok(e, E):
				continue
			var w: float = float(rarw[mini(r, rarw.size() - 1)]) * (1.0 + rod_t * 0.12 * r) * bait_mul(bk, e)
			if shadow_r >= 0:
				var sc := size_class(e)
				w *= 3.0 if sc == shadow_r else (0.5 if absi(sc - shadow_r) == 1 else 0.15)
			if b.has("night") and night:
				w *= float(b.night)
			if r >= 1:
				w *= rare_boost
			out.append([e, w])
		elif cat == "legend":
			if rod_t < 2 or (e.z != zone and e.z != "unknown") or not cond_ok(e, E):
				continue
			out.append([e, (0.6 if bk == "livebait" else 0.3) * (1.0 + rod_t * 0.25)])
		elif how == "snag":
			if e.z != zone or not cond_ok(e, E):
				continue
			out.append([e, float(SNAG_W[mini(r, 4)])])
		elif how == "hook" and cat != "junk":
			if e.z != zone or not cond_ok(e, E):
				continue
			out.append([e, float(HOOK_W[mini(r, 3)])])
		elif cat == "junk":
			var zw := 1.6 if zone == "harbour" else 0.8
			out.append([e, float(JUNK_W[mini(r, 2)]) * zw * (1.4 if bk == "dough" else 1.0)])
	# Junk is about 6-10% of what bites (more in the harbour), never most of it.
	var fw := 0.0
	var jw := 0.0
	for x in out:
		var c: String = x[0].cat
		if c == "junk":
			jw += float(x[1])
		elif c == "fish":
			fw += float(x[1])
	var relic := clampf(fw / 40.0, 0.15, 1.0)
	var want := maxf(1.2, fw * (0.1 if zone == "harbour" else 0.06))
	for x in out:
		var c: String = x[0].cat
		if c == "junk":
			if jw > 0.0:
				x[1] = float(x[1]) * want / jw
		elif c != "fish" and c != "legend":
			x[1] = float(x[1]) * relic
	return out


static func pick_w(list: Array, r: float) -> Variant:
	var tot := 0.0
	for x in list:
		tot += float(x[1])
	if tot <= 0.0:
		return null
	var v := r * tot
	for x in list:
		v -= float(x[1])
		if v <= 0.0:
			return x[0]
	return list[list.size() - 1][0]


## The size class of a fish that might be swimming here now (for its shadow).
func roll_shadow(zone: String, bk: String, rod_t: int, r: float) -> int:
	var fish: Array = []
	for x in hook_table(zone, bk, rod_t):
		var c: String = x[0].cat
		if c == "fish" or c == "legend":
			fish.append(x)
	var e: Variant = pick_w(fish, r)
	return size_class(e) if e != null else 0


static func roll_size(e: Dictionary, r: float) -> float:
	var sz: Variant = e.get("sz")
	if sz == null:
		return 0.0
	var a := float(sz[0])
	var b := float(sz[1])
	return snappedf(a + (b - a) * pow(r, 1.7), 0.1)


## "g" golden (1 in 400), "a" albino (1 in 250), or "" for a normal catch.
# Rare colours a fish can come in: name, value multiplier, and odds (1 in N) when they can happen.
const VARIANTS := {
	"g": {"n": "Golden", "mult": 3.0, "odds": 400},
	"a": {"n": "Albino", "mult": 2.0, "odds": 250},
	"m": {"n": "Moonlit", "mult": 2.5, "odds": 40},  # night, full moon
	"s": {"n": "Storm-touched", "mult": 2.5, "odds": 60},  # in a storm
	"p": {"n": "Ghostly", "mult": 2.5, "odds": 60},  # in fog
	"r": {"n": "Rainbow", "mult": 6.0, "odds": 300},  # after a storm
}


## A rare colour for this catch, or "" (most of the time). Some only happen in the right
## weather or moon.
static func roll_variant(e: Dictionary, r: float, E: Dictionary = {}) -> String:
	if e.cat != "fish" or e.get("release", false):
		return ""
	var can: Array[String] = ["g", "a"]
	if not E.is_empty():
		if E.moon == "fullmoon" and time_ok("night", float(E.hour)):
			can.append("m")
		if E.sky == "storm":
			can.append("s")
		if E.sky == "fog":
			can.append("p")
		if bool(E.get("after", false)):
			can.append("r")
	var acc := 0.0
	for v in can:
		acc += 1.0 / float(VARIANTS[v].odds)
		if r < acc:
			return v
	return ""


static func size_frac(e: Dictionary, cm: float) -> float:
	var sz: Variant = e.get("sz")
	if sz == null or float(sz[1]) <= float(sz[0]):
		return 0.5
	return clampf((cm - float(sz[0])) / (float(sz[1]) - float(sz[0])), 0.0, 1.0)


## A short "when and how to find it" line for the Logbook.
func hint_for(e: Dictionary) -> String:
	var p: Dictionary = e.cp
	var parts: Array[String] = []
	if p.get("time") != null:
		parts.append({"day": "by day", "night": "at night", "dawn": "at dawn", "dusk": "at dusk",
			"dawn/dusk": "at dawn or dusk", "dusk/night": "from dusk", "midnight": "around midnight"}.get(str(p.time), str(p.time)))
	if p.get("tide") != null:
		parts.append({"rising": "on a rising tide", "falling": "on a falling tide", "high": "at high tide",
			"low": "at low tide", "kingtide": "on a king tide"}.get(str(p.tide), str(p.tide)))
	if p.get("sky") != null:
		parts.append({"calm": "in calm weather", "windy": "when it's windy", "rain": "in the rain",
			"fog": "in fog", "storm": "in a storm", "afterstorm": "after a storm"}.get(str(p.sky), str(p.sky)))
	if p.get("season") != null:
		parts.append("in " + str(p.season))
	if p.get("bait") != null:
		var b: Dictionary = bait.get(str(p.bait), {})
		parts.append("on " + str(b.get("n", p.bait)).to_lower())
	if e.cat == "legend":
		parts.append("needs a Graphite Rod or better")
	var verb := "Bites"
	if str(e.get("how", "")) == "pot":
		verb = "Crawls into crab pots"
	if parts.is_empty():
		return str(e.get("hint", "Any time.")) if verb == "Bites" else verb + " any time."
	return verb + " " + ", ".join(PackedStringArray(parts)) + "."


# --- the web game's integer hash (Math.imul semantics), so weather matches -------

static func _i32(x: int) -> int:
	x = x & 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x


static func _u32(x: int) -> int:
	return x & 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	return _i32(_i32(a) * _i32(b))


static func hsh(a: int, b := 0, c := 0) -> float:
	var h := _imul(a, 374761393) + _imul(b, 668265263) + _imul(c, 1442695041)
	h = _i32(_i32(h) ^ (_u32(h) >> 13))
	h = _imul(h, 1274126177)
	return float(_u32(h ^ (_u32(h) >> 16))) / 4294967296.0
