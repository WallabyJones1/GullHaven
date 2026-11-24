extends RefCounted
## A small JSON save in the user folder: Shells, gear, bait, the Logbook, requests, the
## places you've found, your unlocks and where you were standing, plus a few stats.
## (On Steam this file will sit under Steam Cloud; see the plan doc.)

const PATH := "user://gullhaven_save.json"
const VERSION := 3


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"shells": 0,
		"log": {},  # id -> {count, best, g, a}
		"gear": {"rod": 0, "reel": 0, "line": 0},
		"bait": {},  # bait key -> how many (lures: 1 = owned)
		"bait_sel": "dough",
		"best_streak": 0,
		"requests": [],
		"request_day": -1,
		"thanks": {},  # townsperson -> requests done
		"stats": {"catches": 0, "junk": 0, "finds": 0},
		"clock_offset": 0.0,
		"visited": {},  # place name -> true
		"permits": {},  # unlocks: bridge, permit_ranger, permit_ember...
		"hut_tier": 0,
		"pos": [],  # where you were standing when you quit
	}


static func load_save() -> Dictionary:
	var data := defaults()
	if not FileAccess.file_exists(PATH):
		return data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return data
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return data
	for key in parsed:
		var have: Variant = data.get(key)
		var got: Variant = parsed[key]
		if have is Dictionary and got is Dictionary and key not in ["log", "bait", "thanks", "visited", "permits"]:
			for sub in got:
				have[sub] = got[sub]
		elif have == null or typeof(have) == typeof(got) or (have is float and got is int) or (have is int and got is float):
			data[key] = got
	data.version = VERSION
	return data


static func write(data: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write the save file: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
