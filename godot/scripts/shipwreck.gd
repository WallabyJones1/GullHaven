extends Node3D
## The shipwreck opening. You were sailing to Gullhaven to take on Gran's hut when a storm
## wrecked your boat on Gull Rock, a little island out in the bay. You wake on the shingle
## with Gran's letter, soggy, in your pocket. To get to town you learn the game by doing it:
##   1. gather driftwood and rope from the wreckage
##   2. rig Gran's old rod at the wreck
##   3. catch two fish
##   4. light a campfire and cook them
##   5. patch up the ship's dinghy
##   6. row to the lights of Gullhaven
## Then Old Marlo meets you on the docks and the story carries on as before. A new game asks
## whether to start shipwrecked or in Gullhaven.

const SaveGame := preload("res://scripts/save_game.gd")
const Models := preload("res://scripts/models.gd")

const ROCK := Vector3(572.0, 0.0, 470.0)
const WAKE := Vector3(566.0, 0.0, 476.0)
const WRECK := Vector3(577.0, 0.0, 478.0)
const FIRE := Vector3(569.0, 0.0, 470.0)
const TOWN := Vector3(468.0, 0.0, 577.0)
const NEED_WOOD := 6
const NEED_ROPE := 3
const STEPS := [
	"Gather driftwood and rope from the wreckage (%d/%d wood, %d/%d rope)",
	"Rig Gran's old rod at the wreck",
	"Catch two fish from the rocks (%d/2)",
	"Light a campfire and cook your catch (3 wood)",
	"Patch up the ship's dinghy at the wreck (%d/%d wood, %d/%d rope)",
	"Row to the lights of Gullhaven, south-west",
]

var main: Node
var _root: Node3D
var _piles: Array = []  # {node, wood, rope}
var _wreck: Node3D
var _fire: Node3D
var _beacon: Node3D
var _tick := 0.0
var auto := ""  # the smoke test answers the question itself ("town" or "wreck")


func setup(m: Node) -> void:
	main = m
	main.town.providers.append(self)
	main.fishing.catch_hooks.append(_on_catch)
	if active():
		_build()


func W() -> Dictionary:
	if not main.save.has("wreck") or not (main.save.wreck is Dictionary):
		main.save["wreck"] = {}
	return main.save.wreck


func active() -> bool:
	return W().has("stage") and int(W().stage) < STEPS.size()


func stage() -> int:
	return int(W().get("stage", 99))


## A new game: shipwrecked, or straight into town?
func ask(then_town: Callable) -> void:
	_morning()
	if auto == "town":
		then_town.call()
		return
	if auto == "wreck":
		begin()
		return
	main.dialogue.say("How does your story begin?", [
		"Gran's left you her fishing hut in Gullhaven. You set sail to claim it...",
		"Choose how you arrive."], null,
		["Shipwrecked on Gull Rock (learn the ropes on the way)", "Safe in Gullhaven's harbour"], func(c: int) -> void:
			if c == 0:
				begin()
			else:
				then_town.call())


## A new game starts in the morning, not in the dark (the town clock runs a day every 24 minutes).
func _morning() -> void:
	var h := fposmod(float(main.sea.env.get("hour", 12.0)), 24.0)
	if h < 6.0 or h > 18.5:
		main.sea.skip_hours(fposmod(7.5 - h, 24.0))
		main.save["clock_offset"] = float(main.sea.offset)


func begin() -> void:
	W()["stage"] = 0
	W()["wood"] = 0
	W()["rope"] = 0
	W()["fish"] = 0
	_build()
	var p: CharacterBody3D = main.player
	p.global_position = Vector3(WAKE.x, float(main.harbour.stand_height(WAKE.x, WAKE.z)) + 0.3, WAKE.z)
	p.velocity = Vector3.ZERO
	main.audio.play("thunder", -6.0)
	main.cam.shake(0.5)
	main.hud.show_banner("Gull Rock", "Washed ashore")
	main.dialogue.say("Washed ashore", [
		"The storm took the boat. You wake on cold shingle, soaked through, gulls shouting overhead.",
		"In your coat pocket, Gran's letter, soggy but readable:",
		"\"My dear, if you're reading this, the hut on the point is yours now, and so is my old rod.\"",
		"\"Find Old Marlo down on the docks. He'll show you the ropes. Love, Gran.\"",
		"Across the water you can see the lights of Gullhaven. First, though: you'll need a boat."], null, [], func(_c: int) -> void:
			main.hud.toast("Walk with {move}. Things you can use show a prompt: press {action}.")
			_refresh())
	SaveGame.write(main.save)


func _hold(on: bool) -> void:
	if main.story:
		main.story.hold = on
	if main.land_story:
		main.land_story.hold = on


func _build() -> void:
	_hold(true)
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Shipwreck"
	add_child(_root)
	var w: Node3D = main.harbour
	# the wreck: the broken hull of your boat, ribs and all, and its dinghy upside down beside it
	_wreck = Node3D.new()
	_root.add_child(_wreck)
	_wreck.global_position = Vector3(WRECK.x, float(w.stand_height(WRECK.x, WRECK.z)), WRECK.z)
	var hull := Models.make("town", "rowboat")
	if hull:
		_wreck.add_child(hull)
		hull.scale = Vector3(2.2, 1.6, 1.6)
		hull.rotation = Vector3(0.35, 0.6, 0.5)
		hull.position = Vector3(0.0, 0.2, -1.0)
	var dinghy := Models.make("town", "rowboat")
	if dinghy:
		_wreck.add_child(dinghy)
		dinghy.name = "Dinghy"
		dinghy.rotation = Vector3(PI, 1.2, 0.0)
		dinghy.position = Vector3(-2.6, 0.55, 1.6)
	# wreckage to gather: planks, rope, a crate or two
	_piles.clear()
	var spots := [[562.0, 472.0, 1, 0], [565.0, 466.0, 1, 1], [572.0, 465.0, 2, 0], [579.0, 470.0, 1, 1], [581.0, 475.0, 1, 0],
		[574.0, 482.0, 2, 1], [567.0, 480.0, 1, 1], [560.0, 476.0, 1, 0], [576.0, 474.0, 0, 1]]
	if stage() == 0 or stage() == 4:
		for s in spots:
			var x := float(s[0])
			var z := float(s[1])
			if not w.walkable(x, z) or w.is_water(x, z):
				continue
			var n := Models.make("outdoor", "crates") if int(s[3]) > 0 and int(s[2]) == 0 else Models.make("town", "rope_coil") if int(s[3]) > 0 else Models.make("outdoor", "stump")
			if n == null:
				continue
			_root.add_child(n)
			n.global_position = Vector3(x, float(w.stand_height(x, z)), z)
			n.rotation.y = randf() * TAU
			n.scale = Vector3.ONE * 0.6
			_piles.append({"node": n, "wood": int(s[2]) + 1, "rope": int(s[3])})
	# the campfire ring
	_fire = Node3D.new()
	_root.add_child(_fire)
	_fire.global_position = Vector3(FIRE.x, float(w.stand_height(FIRE.x, FIRE.z)), FIRE.z)
	for i in 8:
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.22
		stone.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.55, 0.6)
		stone.material_override = mat
		_fire.add_child(stone)
		stone.position = Vector3(cos(i * TAU / 8.0) * 0.55, 0.06, sin(i * TAU / 8.0) * 0.55)
	if bool(W().get("lit", false)):
		_light_fire()
	# a beam where to go
	_beacon = Node3D.new()
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 40.0
	beam.mesh = cyl
	beam.position.y = 20.0
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.82, 0.35, 0.28)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(beam)
	add_child(_beacon)
	_refresh()


func _light_fire() -> void:
	if _fire.get_node_or_null("Flames"):
		return
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 24
	flames.lifetime = 0.8
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.initial_velocity_min = 0.8
	flames.initial_velocity_max = 1.4
	flames.gravity = Vector3(0, 0.6, 0)
	flames.scale_amount_min = 0.4
	flames.scale_amount_max = 0.8
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	q.material = m
	flames.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flames.color_ramp = g
	flames.position.y = 0.15
	_fire.add_child(flames)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.position.y = 0.8
	_fire.add_child(light)


func _goal() -> String:
	var st := stage()
	var w := W()
	match st:
		0, 4:
			var need_w := NEED_WOOD if st == 0 else NEED_WOOD
			return STEPS[st] % [mini(int(w.wood), need_w), need_w, mini(int(w.rope), NEED_ROPE), NEED_ROPE]
		2:
			return STEPS[2] % int(w.fish)
	return str(STEPS[st]) if st < STEPS.size() else ""


func _target() -> Vector3:
	match stage():
		0:
			for p in _piles:
				if is_instance_valid(p.node):
					return (p.node as Node3D).global_position
			return WRECK
		1, 4:
			return _wreck.global_position
		2:
			return Vector3.INF
		3:
			return _fire.global_position
		5:
			return Vector3(TOWN.x, float(main.harbour.water_level_at(TOWN.x, TOWN.z)), TOWN.z)
	return Vector3.INF


func _refresh() -> void:
	if not active():
		return
	var text := _goal()
	var at := _target()
	var me: Vector3 = main.player.global_position
	if at != Vector3.INF:
		var to := Vector2(at.x - me.x, at.z - me.z)
		if to.length() > 14.0:
			var dirs := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
			text += "\n%d m %s" % [int(to.length()), dirs[posmod(int(round(atan2(to.x, -to.y) / (PI * 0.25))), 8)]]
	main.hud.set_objective("Washed Ashore", text)
	main.hud.set_objective2("", "")


func _process(delta: float) -> void:
	if not active():
		if _beacon:
			_beacon.visible = false
		return
	var at := _target()
	var me: Vector3 = main.player.global_position
	if _beacon:
		_beacon.visible = at != Vector3.INF and Vector2(at.x - me.x, at.z - me.z).length() > 3.0
		if at != Vector3.INF:
			_beacon.global_position = at
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.4
	_refresh()
	if stage() == 5 and Vector2(me.x - TOWN.x, me.z - TOWN.z).length() < 26.0:
		_arrive()


# --- using things ----------------------------------------------------------------------------------

func near(pos: Vector3, _facing: Vector3) -> Dictionary:
	if not active() or main.interiors.is_inside():
		return {}
	var st := stage()
	for p in _piles:
		var n: Node3D = p.node
		if not is_instance_valid(n):
			continue
		var d := Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
		if d < 1.8 and (st == 0 or st == 4):
			return {"kind": "wreck_pile", "pile": p, "dist": d * 0.5, "text": "Space: Gather from the wreckage"}
	var dw := Vector2(_wreck.global_position.x - pos.x, _wreck.global_position.z - pos.z).length()
	if dw < 4.0:
		if st == 1:
			return {"kind": "wreck_rod", "dist": 0.6, "text": "Space: Rig Gran's old rod with rope from the wreck"}
		if st == 4:
			var ready := int(W().wood) >= NEED_WOOD and int(W().rope) >= NEED_ROPE
			return {"kind": "wreck_boat", "dist": 0.6, "text": "Space: Patch up the dinghy" if ready else "The dinghy needs %d wood and %d rope" % [NEED_WOOD, NEED_ROPE]}
	var df := Vector2(_fire.global_position.x - pos.x, _fire.global_position.z - pos.z).length()
	if df < 2.0 and st == 3:
		return {"kind": "wreck_fire", "dist": 0.6, "text": "Space: Light a fire and cook your fish"}
	return {}


func use(it: Dictionary) -> void:
	var w := W()
	match str(it.kind):
		"wreck_pile":
			var p: Dictionary = it.pile
			w["wood"] = int(w.wood) + int(p.wood)
			w["rope"] = int(w.rope) + int(p.rope)
			main.town.add_materials({"wood": int(p.wood), "rope": int(p.rope)})
			main.audio.play("step_wood", -2.0)
			var bits: Array[String] = []
			if int(p.wood) > 0:
				bits.append("+%d driftwood" % int(p.wood))
			if int(p.rope) > 0:
				bits.append("+%d rope" % int(p.rope))
			main.hud.toast(", ".join(bits))
			(p.node as Node3D).queue_free()
			_piles.erase(p)
			if int(w.wood) >= NEED_WOOD and int(w.rope) >= NEED_ROPE and stage() == 0:
				_next("You've plenty of wood and rope. Now, Gran's rod: it's in the wreck somewhere.")
			elif stage() == 4 and int(w.wood) >= NEED_WOOD and int(w.rope) >= NEED_ROPE:
				main.hud.toast("That's enough to patch the dinghy. Back to the wreck!")
		"wreck_rod":
			main.audio.play("reel", -2.0)
			main.dialogue.say("The wreck", ["Under a split plank: Gran's old rod, still in one piece.", "You thread it with fresh line from the rope. Good as new."],
				null, [], func(_c: int) -> void:
					main.hud.toast("Face the water and hold {action} to cast. When the float dips and the ! shows, press {action} to strike. Hold it to reel in.")
					_next(""))
		"wreck_fire":
			if int((main.save.materials as Dictionary).get("wood", 0)) < 3:
				main.hud.toast("You need 3 driftwood for a fire. There's more on the shore.")
				return
			main.save.materials["wood"] = int(main.save.materials.wood) - 3
			W()["lit"] = true
			_light_fire()
			main.audio.play("burstsoft", -2.0)
			main.dialogue.say("Campfire", ["The driftwood catches. You grill your fish on a stick.", "Hot food, a warm fire, and the lights of Gullhaven across the water. Not so bad.",
				"Now: that dinghy by the wreck. With a bit more wood and rope you could patch her up."], null, [], func(_c: int) -> void:
					W()["wood"] = 0
					W()["rope"] = 0
					_next("")
					_build())
		"wreck_boat":
			if int(w.wood) < NEED_WOOD or int(w.rope) < NEED_ROPE:
				main.hud.toast("You need %d wood and %d rope: gather more from the wreckage." % [NEED_WOOD, NEED_ROPE])
				return
			main.save.materials["wood"] = maxi(0, int(main.save.materials.get("wood", 0)) - NEED_WOOD)
			main.save.materials["rope"] = maxi(0, int(main.save.materials.get("rope", 0)) - NEED_ROPE)
			if not (main.save.boats as Array).has("row"):
				(main.save.boats as Array).append("row")
			main.save.boat = "row"
			var d := _wreck.get_node_or_null("Dinghy")
			if d:
				d.queue_free()
			var launch := _launch_spot()
			main.boats.spawn(launch, 0.0)
			main.audio.play("fanfare1")
			main.hud.show_banner("A boat!", "The dinghy floats")
			main.hud.toast("She floats! Walk up to her and press {action} to climb in. Steer with {move}.")
			_next("")


func _launch_spot() -> Vector3:
	var w: Node3D = main.harbour
	var me: Vector3 = main.player.global_position
	for r in [4.0, 6.0, 8.0, 10.0, 13.0]:
		for i in 16:
			var a := i * TAU / 16.0
			var x: float = me.x + cos(a) * r
			var z: float = me.z + sin(a) * r
			if w.is_water(x, z) and float(w.water_depth(x, z)) > 0.6:
				return Vector3(x, 0.0, z)
	return Vector3(ROCK.x - 16.0, 0.0, ROCK.z + 8.0)


func _next(say: String) -> void:
	W()["stage"] = stage() + 1
	if say != "":
		main.hud.toast(say)
	main.audio.play("pin", -2.0)
	_refresh()
	SaveGame.write(main.save)


func _on_catch(id: String, _cm: float, _variant: String) -> void:
	if stage() != 2:
		return
	var e: Dictionary = main.sea.by_id.get(id, {})
	if str(e.get("cat", "")) != "fish" and str(e.get("cat", "")) != "legend":
		return
	W()["fish"] = int(W().fish) + 1
	if int(W().fish) >= 2:
		_next("Two fish! Supper. Now, a fire by the camp stones.")


func _arrive() -> void:
	W()["stage"] = 99
	_hold(false)
	if _beacon:
		_beacon.visible = false
	main.hud.show_banner("Gullhaven", "You made it")
	main.audio.play("fanfare2")
	main.dialogue.say("Old Marlo (shouting from the dock)", [
		"Ahoy there! Washed up in last night's blow, were you? In that leaky thing?",
		"Tie her up and come and find me on the docks. Old Marlo. You've Gran's look about you..."], null, [], func(_c: int) -> void:
			if main.story:
				main.story._intro_done(0)
			if main.land_story and main.land_story.has_method("_refresh"):
				main.land_story.call("_refresh"))
	SaveGame.write(main.save)
	if _root:
		var r := _root
		get_tree().create_timer(30.0).timeout.connect(func() -> void:
			if is_instance_valid(r):
				r.queue_free())


func journal_lines() -> Array[String]:
	if not active():
		return []
	return ["Washed ashore on Gull Rock: " + _goal()]
