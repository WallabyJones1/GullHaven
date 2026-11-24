extends RefCounted
## A small JSON save in the user folder: Shells, the Logbook and the time of day.
## (On Steam this file will sit under Steam Cloud; see the plan doc.)

const PATH := "user://gullhaven_save.json"
const VERSION := 1


static func load_save() -> Dictionary:
	var data := {"version": VERSION, "shells": 0, "log": {}, "hour": 9.0}
	if not FileAccess.file_exists(PATH):
		return data
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return data
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			data[key] = parsed[key]
	if not (data.log is Dictionary):
		data.log = {}
	return data


static func write(data: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write the save file: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
