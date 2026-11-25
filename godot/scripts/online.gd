extends Node
## The shared town: play online with friends. Everyone keeps their own save; the server
## (mp-server/ in the repo) relays where people are and what they say, and keeps a copy of
## each hut so friends can visit. Single player is untouched: nothing here runs until you
## choose Play online on the main menu (or Online in the game menu).
## - Other players walk about as themselves, with their name over their head.
## - Enter opens the chat line; what you say shows in the chat log and over your head.
## - The game menu's Online page lists who's here, and lets you visit their huts.

const Character := preload("res://scripts/character.gd")
const Billboard := preload("res://scripts/billboard.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const DEFAULT_SERVER := "ws://localhost:8787"
const SEND_EVERY := 0.1
const HUT_EVERY := 20.0
const LOG_LINES := 7
const LOG_FADE := 14.0
const BUBBLE_TIME := 6.0
const WALK := [0, 1, 0, 2]
# Emotes: keys 1 to 5 (or the touch Wave button). What shows over your head.
const EMOTES := {"wave": "*waves*", "dance": "*dances*", "cheer": "Hooray!", "heart": "<3", "laugh": "Ha ha ha!"}
const EMOTE_KEYS := {KEY_1: "wave", KEY_2: "dance", KEY_3: "cheer", KEY_4: "heart", KEY_5: "laugh"}

signal changed  # connected, disconnected, someone came or went

var main: Node
var ws: WebSocketPeer
var state := "off"  # off, connecting, online
var my_id := -1
var my_name := ""
var server_url := ""
var remotes := {}  # id -> {name, look, node, label, bubble, bubble_t, pos, target, facing, a, walk}
var _send_t := 0.0
var _hut_t := 0.0
var _last_pos := ""
var _last_hut := ""
var _font: Font
var _layer: CanvasLayer
var _log_box: VBoxContainer
var _log: Array = []  # {label, t}
var _line: LineEdit
var _typing := false
var _my_bubble: Label3D
var _my_bubble_t := 0.0
var _wanted_name := ""


func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://art/fonts/pixelify_sans.woff2")
	_build_chat()
	_my_bubble = _label3d(26)
	_my_bubble.modulate = Color(1.0, 0.95, 0.75)
	_my_bubble.visible = false
	main.add_child.call_deferred(_my_bubble)


## In a browser, the page the game came from may be a shared-town server itself (the
## Railway site): it tells the game its address, and the game joins it by itself.
static func page_server() -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("window.GULLHAVEN_SERVER || ''", true)
	return "" if v == null else str(v)


func is_online() -> bool:
	return state == "online"


func status_text() -> String:
	match state:
		"online":
			return "Online at %s as %s. %d other %s here." % [server_url, my_name, remotes.size(), "player" if remotes.size() == 1 else "players"]
		"connecting":
			return "Connecting to %s..." % server_url
	return "Playing on your own. Join a shared town to see and chat with friends."


## Join a shared town at url (ws:// or wss://) as name.
func connect_to(url: String, name: String) -> void:
	leave(true)
	url = url.strip_edges()
	if url == "":
		url = DEFAULT_SERVER
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://" + url
	server_url = url
	_wanted_name = name.strip_edges().substr(0, 16)
	if _wanted_name == "":
		_wanted_name = "Fisher"
	ws = WebSocketPeer.new()
	var err := ws.connect_to_url(url)
	if err != OK:
		state = "off"
		_say_system("Couldn't reach %s (%s)." % [url, error_string(err)])
		changed.emit()
		return
	state = "connecting"
	changed.emit()


func leave(quiet := false) -> void:
	if ws:
		ws.close()
	ws = null
	var was := state
	state = "off"
	my_id = -1
	for id in remotes.keys():
		_drop(int(id))
	if was == "online" and not quiet:
		_say_system("You left the shared town. Back to playing on your own.")
	changed.emit()


func players_list() -> Array:
	var out: Array = []
	for id in remotes:
		out.append({"id": int(id), "name": str(remotes[id].name)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	return out


func request_visit(id: int) -> void:
	_send({"t": "visit", "id": id})


# --- the connection ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_chat(delta)
	_update_remotes(delta)
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if state == "connecting":
			_hello()
		while ws.get_available_packet_count() > 0:
			var raw := ws.get_packet().get_string_from_utf8()
			var msg: Variant = JSON.parse_string(raw)
			if msg is Dictionary:
				_on_message(msg)
		_send_t -= delta
		if _send_t <= 0.0 and state == "online":
			_send_t = SEND_EVERY
			_send_pos()
		_hut_t -= delta
		if _hut_t <= 0.0 and state == "online":
			_hut_t = HUT_EVERY
			_send_hut()
	elif st == WebSocketPeer.STATE_CLOSED:
		var was := state
		ws = null
		state = "off"
		for id in remotes.keys():
			_drop(int(id))
		if was == "connecting":
			_say_system("Couldn't connect to %s. Is the server running?" % server_url)
		elif was == "online":
			_say_system("Lost the connection to the shared town.")
		changed.emit()


func _send(msg: Dictionary) -> void:
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func _look() -> Dictionary:
	var full := Character.default_look()
	full.merge(main.save.look, true)
	return full


func _hut() -> Dictionary:
	var furn: Array = []
	for it in main.save.furniture:
		if it is Dictionary:
			furn.append(it)
	return {"tier": int(main.save.hut_tier), "style": main.save.hut_style, "furniture": furn}


func _hello() -> void:
	state = "online"  # (until the welcome arrives the server just waits for this)
	var p: Vector3 = main.player.global_position
	_send({"t": "hello", "name": _wanted_name, "look": _look(), "x": p.x, "y": p.y, "z": p.z, "hut": _hut(), "v": 1})
	_last_hut = JSON.stringify(_hut())


func _send_pos() -> void:
	var pl: CharacterBody3D = main.player
	var p := pl.global_position
	var f: Vector3 = pl.facing
	var a := 0
	if str(pl.pose) == "cast":
		a = 3
	elif str(pl.pose) == "cheer":
		a = 4
	elif pl.velocity.length() > 0.5:
		a = 1
	var key := "%.2f,%.2f,%.2f,%.2f,%.2f,%d" % [p.x, p.y, p.z, f.x, f.z, a]
	if key == _last_pos:
		return
	_last_pos = key
	_send({"t": "pos", "x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01), "fx": snappedf(f.x, 0.01),
		"fz": snappedf(f.z, 0.01), "a": a, "in": ""})


func _send_hut() -> void:
	var h := _hut()
	var s := JSON.stringify(h)
	if s != _last_hut:
		_last_hut = s
		_send({"t": "hut", "data": h})


## Wave, dance, cheer... (over your head, and everyone else's screen).
func emote(kind: String) -> void:
	if not EMOTES.has(kind):
		return
	_my_bubble.text = str(EMOTES[kind])
	_my_bubble_t = 2.5
	var pl: CharacterBody3D = main.player
	if str(pl.pose) == "":
		pl.pose = "cheer"
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if str(pl.pose) == "cheer" and not (pl.get("_held") as Node3D).visible:
				pl.pose = "")
	_send({"t": "emote", "e": kind})


## Tell everyone your new clothes (the wardrobe calls this after a change).
func send_look() -> void:
	if is_online():
		_send({"t": "look", "look": _look()})


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"welcome":
			my_id = int(msg.id)
			my_name = str(msg.name)
			for p in msg.get("players", []):
				if p is Dictionary:
					_add(p)
			_say_system("You're in the shared town as %s. Enter to chat, 1 to 5 to wave, dance, cheer..." % my_name)
			main.hud.toast("Online: %d other %s here." % [remotes.size(), "player" if remotes.size() == 1 else "players"])
			changed.emit()
		"join":
			_add(msg)
			changed.emit()
		"leave":
			_drop(int(msg.get("id", -1)))
			changed.emit()
		"state":
			for row in msg.get("p", []):
				if row is Array and row.size() >= 7:
					var id := int(row[0])
					if remotes.has(id):
						var r: Dictionary = remotes[id]
						r.target = Vector3(float(row[1]), float(row[2]), float(row[3]))
						var f := Vector3(float(row[4]), 0.0, float(row[5]))
						if f.length() > 0.1:
							r.facing = f.normalized()
						r.a = int(row[6])
		"chat":
			var who := str(msg.get("name", "?"))
			var text := str(msg.get("text", ""))
			_add_log("[color=#ffd24d]%s:[/color] %s" % [_esc(who), _esc(text)])
			var id := int(msg.get("id", -1))
			if id == my_id:
				_my_bubble.text = text
				_my_bubble_t = BUBBLE_TIME
			elif remotes.has(id):
				var r: Dictionary = remotes[id]
				var b: Label3D = r.bubble
				b.text = text
				r.bubble_t = BUBBLE_TIME
			main.audio.play("pin", -14.0, 1.3)
		"look":
			var id2 := int(msg.get("id", -1))
			if remotes.has(id2):
				var r2: Dictionary = remotes[id2]
				r2.look = msg.get("look", {})
				var node: Sprite3D = r2.node
				node.texture = _texture(r2.look)
		"hut":
			var data: Dictionary = msg.get("data", {})
			data["owner"] = str(msg.get("owner", "A friend"))
			main.interiors.visit_hut(data)
		"emote":
			var eid := int(msg.get("id", -1))
			var kind := str(msg.get("e", ""))
			if remotes.has(eid) and EMOTES.has(kind):
				var re: Dictionary = remotes[eid]
				var eb: Label3D = re.bubble
				eb.text = str(EMOTES[kind])
				re.bubble_t = 2.5
				re.emote_t = 1.5
		"sys":
			_say_system(str(msg.get("text", "")))
		"full":
			_say_system(str(msg.get("text", "The town is full.")))


func _esc(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")


# --- other players ------------------------------------------------------------------------

func _texture(look: Variant) -> Texture2D:
	var full := Character.default_look()
	if look is Dictionary:
		full.merge(look, true)
	var tex := Character.texture(full)
	if tex == null:
		tex = load("res://art/chars2/player.png")
	return tex


func _label3d(size: int) -> Label3D:
	var l := Label3D.new()
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.0011  # with fixed_size, the same size on screen however far away
	l.outline_size = 10
	l.outline_modulate = Color(0.04, 0.05, 0.1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.width = 520.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _add(p: Dictionary) -> void:
	var id := int(p.get("id", -1))
	if id < 0 or id == my_id:
		return
	if remotes.has(id):
		_drop(id)
	var node := Billboard.sprite(_texture(p.get("look", {})), 1.0 / 26.0, 5, 4, 46.0)
	main.add_child(node)
	var pos := Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0)))
	node.global_position = pos
	var label := _label3d(22)
	label.text = str(p.get("name", "?"))
	label.modulate = Color(0.75, 0.9, 1.0)
	node.add_child(label)
	label.position = Vector3(0.0, 2.05, 0.0)
	var bubble := _label3d(24)
	bubble.modulate = Color(1.0, 0.98, 0.9)
	bubble.visible = false
	node.add_child(bubble)
	bubble.position = Vector3(0.0, 2.45, 0.0)
	remotes[id] = {"name": str(p.get("name", "?")), "look": p.get("look", {}), "node": node, "label": label, "bubble": bubble,
		"bubble_t": 0.0, "pos": pos, "target": pos, "facing": Vector3(float(p.get("fx", 0.0)), 0.0, float(p.get("fz", 1.0))),
		"a": int(p.get("a", 0)), "walk": 0.0}


func _drop(id: int) -> void:
	if not remotes.has(id):
		return
	var r: Dictionary = remotes[id]
	var node: Sprite3D = r.node
	if is_instance_valid(node):
		node.queue_free()
	remotes.erase(id)


func _update_remotes(delta: float) -> void:
	var cam: Camera3D = main.cam
	var me: Vector3 = main.player.global_position
	for id in remotes:
		var r: Dictionary = remotes[id]
		var node: Sprite3D = r.node
		var pos: Vector3 = r.pos
		var target: Vector3 = r.target
		if pos.distance_to(target) > 12.0:
			pos = target  # a jump (a door, a sleep): snap
		else:
			pos = pos.lerp(target, minf(1.0, delta * 10.0))
		r.pos = pos
		node.global_position = pos
		node.visible = absf(pos.y - me.y) < 60.0
		var row := Billboard.row_for(r.facing, cam)
		var col := 0
		r.emote_t = float(r.get("emote_t", 0.0)) - delta
		var a := 4 if float(r.emote_t) > 0.0 else int(r.a)
		match a:
			1:
				r.walk = float(r.walk) + delta * 8.0
				col = WALK[int(r.walk) % 4]
			3:
				col = 3
			4:
				col = 4
				row = Billboard.DOWN
		node.frame = row * 5 + col
		r.bubble_t = float(r.bubble_t) - delta
		var b: Label3D = r.bubble
		b.visible = float(r.bubble_t) > 0.0
	_my_bubble_t -= delta
	_my_bubble.visible = _my_bubble_t > 0.0 and is_online()
	if _my_bubble.visible:
		_my_bubble.global_position = me + Vector3(0.0, 2.45, 0.0)


# --- chat -----------------------------------------------------------------------------------

func _build_chat() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.offset_left = 20.0
	root.offset_bottom = -110.0
	root.offset_top = -110.0
	root.custom_minimum_size = Vector2(560.0, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	_layer.add_child(root)
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 1)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_log_box)
	_line = LineEdit.new()
	_line.placeholder_text = "Say something (Enter to send, Esc to cancel)"
	_line.max_length = 140
	_line.custom_minimum_size = Vector2(560.0, 0.0)
	_line.add_theme_font_override("font", UI.font())
	_line.add_theme_font_size_override("font_size", 20)
	_line.add_theme_stylebox_override("normal", UI.box(UI.PANEL, UI.GOLD, 2, 8.0))
	_line.add_theme_stylebox_override("focus", UI.box(UI.PANEL, UI.GOLD, 2, 8.0))
	_line.visible = false
	_line.text_submitted.connect(_submit)
	root.add_child(_line)


func _add_log(bb: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(560.0, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", UI.font())
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_color_override("default_color", UI.CREAM)
	r.add_theme_constant_override("outline_size", 6)
	r.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
	r.text = bb
	_log_box.add_child(r)
	_log.append({"label": r, "t": LOG_FADE})
	while _log.size() > LOG_LINES:
		var old: Dictionary = _log.pop_front()
		(old.label as Node).queue_free()


func _say_system(text: String) -> void:
	_add_log("[color=#8fd3ff]%s[/color]" % _esc(text))


func _update_chat(delta: float) -> void:
	for e in _log:
		e.t = float(e.t) - delta
		var lab: RichTextLabel = e.label
		lab.modulate.a = 1.0 if _typing else clampf(float(e.t) / 2.0, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_online() or _typing:
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	var hud: CanvasLayer = main.hud
	if hud.modal or str(main.menus.mode) != "" or bool(main.dialogue.is_open) or get_tree().paused:
		return
	if EMOTE_KEYS.has(k):
		get_viewport().set_input_as_handled()
		emote(str(EMOTE_KEYS[k]))
		return
	if k != KEY_ENTER and k != KEY_KP_ENTER:
		return
	get_viewport().set_input_as_handled()
	_open_line()


func _open_line() -> void:
	_typing = true
	_line.text = ""
	_line.visible = true
	_line.grab_focus()
	main.hud.modal = true
	main.player.can_move = false


func _close_line() -> void:
	_typing = false
	_line.visible = false
	_line.release_focus()
	main.hud.modal = false
	main.player.can_move = true
	main.hud.block_input(0.25)


func _submit(text: String) -> void:
	text = text.strip_edges()
	if text != "":
		_send({"t": "chat", "text": text})
	_close_line()


func _input(event: InputEvent) -> void:
	if _typing and event.is_action_pressed("cancel") and not (event is InputEventKey and (event as InputEventKey).keycode == KEY_BACKSPACE):
		get_viewport().set_input_as_handled()
		_close_line()
