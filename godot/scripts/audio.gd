extends Node
## Sound: effects, music that follows the time and weather, and ambience layers.
## All of it is the web game's own synthesized sound, rendered to OGG by
## tools/export_godot_audio.py (audio/sfx, audio/music, audio/amb).

const POOL := 14
const MUSIC_DB := -15.0
const FADE := 3.0
# Base level of each ambience loop when fully on.
const AMB_DB := {"waves": -11.0, "rain": -9.0, "wind": -12.0, "crickets": -16.0, "bubbles": -10.0}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music: Array[AudioStreamPlayer] = []
var _music_name := ""
var _music_cur := 0
var _amb := {}  # name -> AudioStreamPlayer
var _amb_goal := {}  # name -> 0..1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	for k in AMB_DB:
		var a := AudioStreamPlayer.new()
		a.stream = _load("amb", k, true)
		a.volume_db = -80.0
		a.bus = "Effects"
		add_child(a)
		_amb[k] = a
		_amb_goal[k] = 0.0


## Set a bus's volume, 0 (silent) to 1 (full).
static func set_volume(bus: String, amount: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(amount, 0.0001)))
		AudioServer.set_bus_mute(i, amount <= 0.001)


## Play an effect. pitch_spread randomises pitch a little so repeats don't sound robotic.
func play(sound: String, volume_db := 0.0, pitch := 1.0, pitch_spread := 0.0) -> void:
	var stream := _load("sfx", sound, false)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_spread, pitch_spread))
	p.play()


## Crossfade to a music loop ("day", "night", "storm"), or "" for silence.
func set_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	_music_cur = 1 - _music_cur
	var p := _music[_music_cur]
	if track != "":
		p.stream = _load("music", track, true)
		p.volume_db = -40.0
		p.play()


## How much of an ambience loop to hear, 0..1. It fades there smoothly.
func set_amb(layer: String, amount: float) -> void:
	if _amb_goal.has(layer):
		_amb_goal[layer] = clampf(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	for i in 2:
		var p := _music[i]
		var on := i == _music_cur and _music_name != ""
		var goal := MUSIC_DB if on else -60.0
		p.volume_db = move_toward(p.volume_db, goal, delta * 40.0 / FADE)
		if not on and p.playing and p.volume_db <= -59.0:
			p.stop()
	for k in _amb:
		var a: AudioStreamPlayer = _amb[k]
		var amount: float = _amb_goal[k]
		var goal := -60.0 if amount <= 0.01 else float(AMB_DB[k]) + linear_to_db(amount)
		a.volume_db = move_toward(a.volume_db, goal, delta * 20.0)
		if amount > 0.01 and not a.playing:
			a.play()
		elif amount <= 0.01 and a.playing and a.volume_db <= -59.0:
			a.stop()


func _load(folder: String, file: String, loop: bool) -> AudioStream:
	var key := folder + "/" + file
	if _cache.has(key):
		return _cache[key]
	var path := "res://audio/%s.ogg" % key
	if not ResourceLoader.exists(path):
		push_warning("Missing sound: " + path)
		_cache[key] = null
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_cache[key] = s
	return s
