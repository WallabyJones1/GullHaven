extends Node3D
## Sea monsters. Out on open water in a boat (the reef, the kelp, the wrecks, the open blue
## and the deep), something big sometimes surfaces and comes for you: a sea serpent, a
## kraken, or, out past the shelf, the leviathan. They're worse at night and in storms.
## While one's up and close, Space throws a harpoon (Delve sells them, or make three at
## Gran's workbench): get the gold line in the green to hit. Hit it enough times before it
## gives up and it flees, leaving scales, ink or teeth to sell, a heap of Shells and often a
## treasure map. Miss, or let it reach you, and it rams the boat.

const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")
const Models := preload("res://scripts/models.gd")

const KINDS := {
	"serpent": {"n": "Sea Serpent", "hp": 3, "zone": 0.16, "speed": 6.0, "shells": [400, 900], "drop": "serpent_scale", "drops": [1, 3],
		"waters": ["reef", "kelp", "wreck", "blue", "lagoon", "seagrass"]},
	"kraken": {"n": "Kraken", "hp": 4, "zone": 0.13, "speed": 4.5, "shells": [700, 1500], "drop": "kraken_ink", "drops": [1, 2],
		"waters": ["wreck", "blue", "deep", "kelp"]},
	"leviathan": {"n": "Leviathan", "hp": 6, "zone": 0.1, "speed": 7.5, "shells": [2500, 5000], "drop": "leviathan_tooth", "drops": [1, 1],
		"waters": ["deep"]},
}
const RANGE := 26.0

var main: Node
var _m: Dictionary = {}  # the monster that's up: {kind, root, parts, pos, hp, state, t, up}
var _wait := 60.0
var _aim := {}
var _layer: CanvasLayer
var _bar: Control
var _label: Label
var _rng := RandomNumberGenerator.new()
var _tex := {}


class Bar:
	extends Control
	var marker := 0.0
	var zone_at := 0.5
	var zone_w := 0.15

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.07, 0.09, 0.17, 0.92))
		draw_rect(Rect2((zone_at - zone_w * 0.5) * size.x, 0.0, zone_w * size.x, size.y), Color(0.95, 0.45, 0.35, 0.85))
		draw_rect(Rect2(marker * size.x - 3.0, -6.0, 6.0, size.y + 12.0), Color(1.0, 0.84, 0.45))
		draw_rect(r, Color(0.96, 0.86, 0.62), false, 3.0)


func setup(m: Node) -> void:
	main = m
	_rng.randomize()
	if not main.save.has("monsters"):
		main.save["monsters"] = {}
	for k in ["serpent_head_0", "serpent_head_1", "serpent_hump", "tentacle_0", "tentacle_1"]:
		_tex[k] = load("res://art/land/sea/%s.png" % k)
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -240.0
	center.offset_bottom = -110.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	var panel := UI.panel(14.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	_label = UI.label("", 22, UI.CREAM, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_label)
	_bar = Bar.new()
	_bar.custom_minimum_size = Vector2(460.0, 26.0)
	col.add_child(_bar)
	col.add_child(UI.label(Glyphs.plain("{action} throw when the gold line's in the red   {cancel} hold off"), 18, UI.DIM))
	_layer.visible = false
	main.town.providers.append(self)


func active() -> bool:
	return not _m.is_empty()


func _process(delta: float) -> void:
	var boats: Node = main.boats
	if _m.is_empty():
		if not bool(boats.aboard) or bool(main.interiors.is_inside()):
			_wait = maxf(_wait, 20.0)
			return
		_wait -= delta * _rate()
		if _wait <= 0.0:
			_wait = _rng.randf_range(100.0, 220.0)
			_try_spawn()
		return
	_step(delta)
	if not _aim.is_empty():
		_update_aim(delta)


## Night and storms bring them out.
func _rate() -> float:
	var e: Dictionary = main.sea.env
	var k := 1.0
	var hour := float(e.get("hour", 12.0))
	if hour < 5.5 or hour > 20.0:
		k *= 1.8
	if str(e.get("sky", "")) == "storm":
		k *= 2.2
	return k


func _try_spawn(force := "") -> bool:
	var p: Vector3 = main.player.global_position
	var zone: String = main.harbour.zone_at(p.x, p.z)
	var pool: Array = []
	for k in KINDS:
		if force == k or (force == "" and zone in KINDS[k].waters):
			pool.append(k)
	if pool.is_empty():
		return false
	var kind: String = pool[_rng.randi() % pool.size()]
	for attempt in 12:
		var a := _rng.randf() * TAU
		var at := p + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(28.0, 40.0)
		if main.harbour.is_water(at.x, at.z) and float(main.harbour.water_depth(at.x, at.z)) > 2.0:
			_spawn(kind, at)
			return true
	return false


func _spawn(kind: String, at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	var parts: Array = []
	if kind == "kraken":
		for i in 6:
			var t := _part3d("tentacle", 1.0, root)
			t.rotation.y = i * TAU / 6.0 + PI
			parts.append({"node": t, "off": Vector3(cos(i * TAU / 6.0) * 2.6, 0.0, sin(i * TAU / 6.0) * 2.6), "ph": i * 0.9, "h": 4.3,
				"turn": i * TAU / 6.0 + PI})
	else:
		var scale := 1.7 if kind == "leviathan" else 1.0
		var head := _part3d("serpent_head", scale, root)
		parts.append({"node": head, "off": Vector3.ZERO, "ph": 0.0, "head": true, "h": 4.2 * scale})
		for i in 4:
			var h := _part3d("serpent_hump", scale, root)
			parts.append({"node": h, "off": Vector3(-3.6 * scale * (i + 1), 0.0, 0.0), "ph": i * 1.1, "h": 2.0 * scale})
	var info: Dictionary = KINDS[kind]
	_m = {"kind": kind, "root": root, "parts": parts, "pos": at, "hp": int(info.hp), "t": 0.0, "up": 0.0, "dive": 0.0,
		"heading": 0.0, "gone": false, "life": 75.0}
	root.global_position = Vector3(at.x, float(main.harbour.water_level_at(at.x, at.z)), at.z)
	main.audio.play("thunder", -10.0, 0.6)
	main.cam.shake(0.6)
	main.hud.show_banner("A %s!" % str(info.n), "Something huge is in the water")
	main.hud.toast("Throw harpoons with %s when it surfaces near you." % Glyphs.key("action"))


func _part3d(kind: String, scale_by: float, parent: Node3D) -> Node3D:
	var n := Models.make("sea", kind)
	n.scale = Vector3.ONE * scale_by
	parent.add_child(n)
	return n


func _part(tex: Texture2D, px: float, parent: Node3D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(s)
	return s


func _step(delta: float) -> void:
	var info: Dictionary = KINDS[str(_m.kind)]
	var p: Vector3 = main.player.global_position
	var pos: Vector3 = _m.pos
	_m.t = float(_m.t) + delta
	_m.life = float(_m.life) - delta
	var to := Vector2(p.x - pos.x, p.z - pos.z)
	var d := to.length()
	if bool(_m.gone) or float(_m.life) <= 0.0 or d > 90.0 or not bool(main.boats.aboard):
		if not bool(_m.gone):
			main.hud.toast("The %s sinks back into the deep." % str(info.n))
		_despawn()
		return
	# circle the boat, closing in; dive now and then
	var target := Vector2(p.x, p.z) - to.normalized().rotated(0.9) * 10.0
	var dir := (target - Vector2(pos.x, pos.z))
	if dir.length() > 0.2 and _aim.is_empty():
		var step := dir.normalized() * float(info.speed) * delta
		if main.harbour.is_water(pos.x + step.x, pos.z + step.y):
			pos.x += step.x
			pos.z += step.y
		_m.heading = atan2(-step.y, step.x)  # the way it's swimming, for a model facing +X
	_m.pos = pos
	_m.dive = float(_m.dive) - delta
	if float(_m.dive) <= 0.0 and _aim.is_empty():
		_m.dive = _rng.randf_range(6.0, 11.0)
	var up := 1.0 if float(_m.dive) > 2.0 or not _aim.is_empty() else 0.0
	_m.up = lerpf(float(_m.up), up, minf(1.0, delta * 2.0))
	var wl := float(main.harbour.water_level_at(pos.x, pos.z))
	var root: Node3D = _m.root
	root.global_position = Vector3(pos.x, wl, pos.z)
	var t := float(_m.t)
	var kraken := str(_m.kind) == "kraken"
	if not kraken:
		root.rotation.y = lerp_angle(root.rotation.y, float(_m.heading), minf(1.0, delta * 2.0))
	for part in _m.parts:
		var node: Node3D = part.node
		var off: Vector3 = part.off
		var h := float(part.h)
		var bob := sin(t * 2.0 + float(part.ph)) * 0.3
		node.position = off + Vector3(0.0, -h + h * float(_m.up) + bob, 0.0)
		if part.has("head"):
			node.rotation.z = sin(t * 1.3) * 0.08
		elif kraken:
			node.rotation = Vector3(sin(t * 1.7 + float(part.ph)) * 0.25, float(part.turn), sin(t * 1.1 + float(part.ph)) * 0.2)
	# too close: it rams you
	if d < 5.0 and float(_m.up) > 0.5 and _aim.is_empty():
		_ram()


func _ram() -> void:
	var info: Dictionary = KINDS[str(_m.kind)]
	main.cam.shake(1.4)
	main.audio.play("thud", 0.0, 0.5)
	main.audio.play("splash", -2.0, 0.6)
	var lost := mini(int(main.save.shells), _rng.randi_range(20, 120))
	main.save.shells = int(main.save.shells) - lost
	main.hud.set_shells(main.save.shells)
	main.hud.toast("The %s rams your boat! %d Shells bounce overboard." % [str(info.n), lost] if lost > 0 else "The %s rams your boat!" % str(info.n))
	var away := Vector3(_m.pos.x - main.player.global_position.x, 0.0, _m.pos.z - main.player.global_position.z).normalized()
	_m.pos = _m.pos + away * 14.0
	_m.dive = 1.0


func _despawn() -> void:
	if _m.has("root"):
		(_m.root as Node3D).queue_free()
	_m = {}
	if not _aim.is_empty():
		_end_aim()


# --- the harpoon ------------------------------------------------------------------------------

func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	if _m.is_empty() or not _aim.is_empty() or float(_m.up) < 0.6:
		return {}
	var mp: Vector3 = _m.pos
	var d := Vector2(mp.x - pos.x, mp.z - pos.z).length()
	if d > RANGE:
		return {}
	var info: Dictionary = KINDS[str(_m.kind)]
	var n := int(main.land.count("harpoon"))
	var text := "Space: Throw a harpoon at the %s (%d left)" % [str(info.n), n] if n > 0 else "The %s! You've no harpoons (Delve sells them)" % str(info.n)
	return {"kind": "harpoon", "dist": 0.5, "text": text}


func use(_it: Dictionary) -> void:
	if int(main.land.count("harpoon")) <= 0:
		main.hud.toast("No harpoons! Delve the smith sells them, or make three at Gran's workbench.")
		main.audio.play("error", -6.0)
		return
	var info: Dictionary = KINDS[str(_m.kind)]
	var mp: Vector3 = _m.pos
	var d := Vector2(mp.x - main.player.global_position.x, mp.z - main.player.global_position.z).length()
	var sloop := str(main.save.get("boat", "")) == "sloop"
	_aim = {"t": 0.0, "speed": 1.2 + d / 15.0, "grace": 0.25, "left": 6.0}
	_bar.zone_at = _rng.randf_range(0.25, 0.75)
	_bar.zone_w = clampf(float(info.zone) * (1.4 if sloop else 1.0) * clampf(1.5 - d / 26.0, 0.7, 1.4), 0.06, 0.4)
	_label.text = "The %s, %d m off. Hits needed: %d   Harpoons: %d" % [str(info.n), int(d), int(_m.hp), int(main.land.count("harpoon"))]
	_layer.visible = true
	main.hud.modal = true
	main.audio.play("crank", -8.0, 0.8)


func _update_aim(delta: float) -> void:
	_aim.t = float(_aim.t) + delta * float(_aim.speed)
	_bar.marker = 0.5 - 0.5 * cos(float(_aim.t) * PI)
	_bar.queue_redraw()
	_aim.grace = float(_aim.grace) - delta
	_aim.left = float(_aim.left) - delta
	if float(_aim.left) <= 0.0 or Input.is_action_just_pressed("cancel"):
		_end_aim()
		return
	if float(_aim.grace) > 0.0 or not Input.is_action_just_pressed("action"):
		return
	_throw(absf(_bar.marker - _bar.zone_at) <= _bar.zone_w * 0.5)


func _throw(hit: bool) -> void:
	main.land.take("harpoon", 1)
	main.audio.play("whoosh", 0.0, 0.8)
	var info: Dictionary = KINDS[str(_m.kind)]
	if hit:
		var dmg := 2 if str(main.save.get("boat", "")) == "sloop" and _rng.randf() < 0.35 else 1
		_m.hp = int(_m.hp) - dmg
		main.audio.play("thud", 0.0, 0.7)
		main.cam.shake(0.5)
		if int(_m.hp) <= 0:
			_end_aim()
			_beaten()
			return
		main.hud.toast("A hit! The %s thrashes. %d more." % [str(info.n), int(_m.hp)])
	else:
		main.audio.play("miss", -4.0)
		main.hud.toast("Missed! The %s lunges." % str(info.n))
		_m.pos = _m.pos.lerp(main.player.global_position, 0.35)
	_end_aim()


func _beaten() -> void:
	var kind := str(_m.kind)
	var info: Dictionary = KINDS[kind]
	var sh: Array = info.shells
	var shells := _rng.randi_range(int(sh[0]), int(sh[1]))
	main.save.shells = int(main.save.shells) + shells
	main.hud.set_shells(main.save.shells)
	var dr: Array = info.drops
	var got: String = main.land.add_item(str(info.drop), _rng.randi_range(int(dr[0]), int(dr[1])))
	var rec: Dictionary = main.save.monsters
	var first := int(rec.get(kind, 0)) == 0
	rec[kind] = int(rec.get(kind, 0)) + 1
	main.progress.add(200 if kind == "serpent" else (350 if kind == "kraken" else 900), "the %s" % str(info.n))
	main.audio.play("fanfare2")
	main.hud.show_banner("You drove off the %s!" % str(info.n), "+%d Shells, %s" % [shells, got])
	if first or _rng.randf() < 0.5:
		main.treasure.give_map("the %s's lair" % str(info.n))
	if main.online and main.online.is_online():
		main.online.announce("drove off a %s!" % str(info.n))
	_m.gone = true
	SaveGame.write(main.save)


func _end_aim() -> void:
	_aim = {}
	_layer.visible = false
	main.hud.modal = false
	main.hud.block_input(0.25)


## For the smoke test and testing by hand: bring one up now.
func force(kind := "serpent") -> bool:
	if not _m.is_empty():
		_despawn()
	return _try_spawn(kind)


func journal_lines() -> Array[String]:
	var out: Array[String] = []
	var rec: Dictionary = main.save.monsters
	for k in KINDS:
		var n := int(rec.get(k, 0))
		out.append("%s: %s" % [str(KINDS[k].n), "driven off %d time%s" % [n, "" if n == 1 else "s"] if n > 0 else "not yet met"])
	return out
