extends Node3D
## Your boat. Buy one at the Boatyard in Gullhaven (or Lantern Boatworks out east), walk up
## to it at the dock and press Space to board. Steer with the move keys (the boat turns
## toward the way you push, relative to the camera), fish straight off the side, and press
## Esc beside a dock or a beach to step ashore. She stays where you leave her.
## Bigger hulls reach rougher water: a Rowboat keeps to the bay, the river and Tideglass
## Cay; a Dinghy reaches Mossbank and Kelpwood; a Skiff, Lantern Key and the Atoll; a
## Trawler gets through the breakers round Wrecker's Cove; and only a Deep-sea Cutter goes
## out to the Deep. Kelpwood hides in a fog bank that turns you round without a deck lamp.

const SaveGame := preload("res://scripts/save_game.gd")

const BOATS := [
	{"k": "row", "n": "Rowboat", "price": 600, "tier": 1, "hold": 6, "spd": 1.0, "len": 3.4, "hull": "#c86a3a",
		"d": "Oars and patience. The bay, the river and Tideglass Cay."},
	{"k": "dinghy", "n": "Dinghy", "price": 3200, "tier": 2, "hold": 10, "spd": 1.08, "len": 4.0, "hull": "#e8e2d0",
		"d": "A little sail. Out past Gull Rock to Mossbank and Kelpwood."},
	{"k": "skiff", "n": "Skiff", "price": 12500, "tier": 3, "hold": 16, "spd": 1.2, "len": 4.8, "hull": "#3f86bd",
		"d": "An outboard and a cuddy. Lantern Key, the Atoll and the reef."},
	{"k": "sloop", "n": "Corsair Sloop", "price": 28000, "tier": 3, "hold": 20, "spd": 1.5, "len": 5.6, "hull": "#4a2a5a",
		"d": "Black sails and a harpoon at the bow: the fastest thing afloat, and made for monster hunting."},
	{"k": "trawler", "n": "Trawler", "price": 42000, "tier": 4, "hold": 24, "spd": 1.15, "len": 6.2, "hull": "#c84a3a",
		"d": "Heavy and steady. Through the breakers to Wrecker's Cove."},
	{"k": "cutter", "n": "Deep-sea Cutter", "price": 125000, "tier": 5, "hold": 34, "spd": 1.35, "len": 7.2, "hull": "#2a3a5a",
		"d": "Built for the open ocean. All the way out to the Deep."},
]
const PAINT := ["#c86a3a", "#e8e2d0", "#3f86bd", "#c84a3a", "#2a3a5a", "#5fae6a", "#f0c040", "#8a5ac8", "#e88aa8", "#3a3a40"]
const PARTS := {
	"lamp": {"n": "Deck lamp", "price": 900, "d": "A bright lantern at the bow. Finds the way through fog, and lights the water at night."},
	"benches": {"n": "Passenger benches", "price": 1500,
		"d": "Seats for friends. In the shared town, fishers without a boat can climb aboard yours and ride along."},
}
const BASE_SPEED := 6.0
const TURN := 1.9  # radians per second at full lock
const MIN_DEPTH := 0.45
const BOARD_RANGE := 2.6

var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var save: Dictionary
var sea: Node
var fishing: Node
var boat: Node3D  # the model
var info := {}  # the BOATS entry for your boat
var aboard := false
var heading := 0.0  # 0 points north (-Z)
var speed := 0.0
var progress: Node  # fisher skills (sea legs)
var _lamp_light: OmniLight3D
var _oars: Array[Node3D] = []
var _row_t := 0.0
var _bob_t := 0.0
var _warn_t := 0.0
var _wake: Array[MeshInstance3D] = []
var _wake_i := 0
var _wake_t := 0.0
var _wake_mat: StandardMaterial3D
var _mats := {}
var _deck_y := 0.5
var _land_t := 0.0
var _land := Vector3.INF


func setup(w: Node3D, p: CharacterBody3D, c: Camera3D, h: CanvasLayer, a: Node, sv: Dictionary, se: Node) -> void:
	world = w
	player = p
	cam = c
	hud = h
	audio = a
	save = sv
	sea = se
	_wake_mat = StandardMaterial3D.new()
	_wake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wake_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.0)
	for i in 28:
		var q := PlaneMesh.new()
		q.size = Vector2(0.9, 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _wake_mat.duplicate()
		mi.visible = false
		mi.set_meta("t", 0.0)
		add_child(mi)
		_wake.append(mi)
	if str(save.boat) != "":
		var pos: Array = save.boat_pos
		if pos.size() == 3:
			spawn(Vector3(float(pos[0]), 0.0, float(pos[1])), float(pos[2]))
		else:
			spawn_at_dock(Vector3(430.0, 0.0, 577.0))


static func boat_info(k: String) -> Dictionary:
	for b in BOATS:
		if b.k == k:
			return b
	return {}


## How many friends can ride along (online): none without the passenger benches.
func seats() -> int:
	if not has_part("benches") or info.is_empty():
		return 0
	return clampi(int(float(info.len) / 1.5), 1, 4)


func tier() -> int:
	return int(info.get("tier", 0))


func has_part(k: String) -> bool:
	var parts: Dictionary = save.boat_parts
	return parts.has(k)


# --- the boat in the world -----------------------------------------------------------

## Put your current boat in the water at a spot, pointing a given way.
func spawn(at: Vector3, head: float) -> void:
	if boat:
		boat.queue_free()
	info = boat_info(str(save.boat))
	if info.is_empty():
		boat = null
		return
	heading = head
	speed = 0.0
	boat = _make_boat(info)
	add_child(boat)
	boat.global_position = Vector3(at.x, float(world.sea_level), at.z)
	boat.rotation.y = heading
	remember()


## Tie your boat up at the dock nearest a spot (where the boatyard puts a new one).
func spawn_at_dock(near: Vector3) -> void:
	var best: Dictionary = {}
	var best_d := INF
	for d in world.docks:
		var r: Rect2 = d.rect
		var dist := r.get_center().distance_to(Vector2(near.x, near.z))
		if dist < best_d:
			best_d = dist
			best = d
	if best.is_empty():
		spawn(near, 0.0)
		return
	var m := _moor_for(best)
	spawn(Vector3(m.x, 0.0, m.y), m.z)


## Where a boat can tie up alongside a dock: near its outer end, on its deeper side.
## Returns x, z and the heading (pointing out along the dock).
func _moor_for(d: Dictionary) -> Vector3:
	var r: Rect2 = d.rect
	var c := r.get_center()
	var long_x := r.size.x >= r.size.y
	var axis := Vector2(1.0, 0.0) if long_x else Vector2(0.0, 1.0)
	var half := (r.size.x if long_x else r.size.y) * 0.5
	var side := Vector2(0.0, 1.0) if long_x else Vector2(1.0, 0.0)
	var width := (r.size.y if long_x else r.size.x) * 0.5
	# the outer end is the one standing in deeper water
	var a_end := c + axis * half
	var b_end := c - axis * half
	if world.water_depth(b_end.x - axis.x * 2.0, b_end.y - axis.y * 2.0) > world.water_depth(a_end.x + axis.x * 2.0, a_end.y + axis.y * 2.0):
		axis = -axis
	var spot := c + axis * (half - 2.8)
	var left := spot + side * (width + 1.5)
	var right := spot - side * (width + 1.5)
	var p := left if world.water_depth(left.x, left.y) >= world.water_depth(right.x, right.y) else right
	return Vector3(p.x, p.y, atan2(-axis.x, -axis.y))


func remember() -> void:
	if boat:
		save.boat_pos = [boat.global_position.x, boat.global_position.z, heading]


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


# --- getting on and off -----------------------------------------------------------------

## The boat, if you're standing by it on a dock or the shore, as something to use.
func near(pos: Vector3, facing: Vector3) -> Dictionary:
	if aboard or not boat:
		return {}
	var bp := boat.global_position
	var to := Vector2(bp.x - pos.x, bp.z - pos.z)
	var d := to.length()
	if d > float(info.len) * 0.5 + BOARD_RANGE:
		return {}
	if d > 1.2 and Vector2(facing.x, facing.z).normalized().dot(to.normalized()) < 0.2:
		return {}
	return {"kind": "board", "dist": maxf(0.0, d - float(info.len) * 0.4), "text": "Space: Board the %s" % info.n}


func use(it: Dictionary) -> void:
	if str(it.get("kind", "")) == "board":
		board()


func board() -> void:
	if not boat:
		return
	aboard = true
	speed = 0.0
	player.riding = true
	player.can_move = false
	audio.play("step_wood", -2.0)
	audio.play("splash", -14.0)
	_place_player()
	hud.toast("Aboard the %s. Steer with the move keys, cast as usual, Esc by a dock or beach to step ashore." % info.n)


## A dry spot (or a dock) within reach of the boat to step onto, or Vector3.INF.
func landing_spot() -> Vector3:
	if not boat:
		return Vector3.INF
	var bp := boat.global_position
	var best := Vector3.INF
	var best_d := INF
	for ring in [1.6, 2.4, 3.2, 4.0]:
		for i in 16:
			var a := TAU * float(i) / 16.0
			var x: float = bp.x + cos(a) * ring
			var z: float = bp.z + sin(a) * ring
			var on_dock := false
			for d in world.docks:
				var r: Rect2 = d.rect
				if r.grow(-0.3).has_point(Vector2(x, z)):
					on_dock = true
			if not on_dock:
				if world.is_water(x, z) or not world.walkable(x, z):
					continue
				if world.height_at(x, z) > float(world.sea_level) + 2.5:
					continue  # a cliff
			var dist: float = ring
			if dist < best_d:
				best_d = dist
				best = Vector3(x, world.stand_height(x, z), z)
		if best != Vector3.INF:
			break
	return best


func go_ashore() -> void:
	var spot := landing_spot()
	if spot == Vector3.INF:
		hud.toast("Nowhere to step ashore here. Bring her in beside a dock or a beach.")
		return
	aboard = false
	speed = 0.0
	player.riding = false
	player.can_move = true
	player.global_position = spot + Vector3(0.0, 0.15, 0.0)
	player.velocity = Vector3.ZERO
	audio.play("step_wood", -2.0)
	remember()
	SaveGame.write(save)


func _place_player() -> void:
	var seat := boat.global_transform * Vector3(0.0, _deck_y, float(info.len) * 0.12)
	player.global_position = seat


## Somewhere to step ashore right now (checked a few times a second), or Vector3.INF.
func can_land() -> bool:
	return _land != Vector3.INF


# --- sailing ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_warn_t = maxf(0.0, _warn_t - delta)
	_bob_t += delta
	_update_wake(delta)
	if not boat:
		return
	var busy: bool = fishing != null and int(fishing.state) != 0
	var input := Vector2.ZERO
	if aboard and not busy and not hud.input_blocked():
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var top := BASE_SPEED * float(info.spd)
	if progress:
		top *= progress.more("sea_legs")
	if input.length() > 0.1:
		var right: Vector3 = cam.ground_right()
		var fwd: Vector3 = cam.ground_forward()
		var want := (right * input.x + fwd * (-input.y)).normalized()
		var want_heading := atan2(-want.x, -want.z)
		var diff := wrapf(want_heading - heading, -PI, PI)
		heading += clampf(diff, -TURN * delta, TURN * delta) * clampf(0.35 + absf(speed) / top, 0.35, 1.0)
		var align := maxf(0.0, cos(diff))
		speed = move_toward(speed, top * input.length() * align, delta * top * 0.7)
	else:
		speed = move_toward(speed, 0.0, delta * top * (1.2 if busy else 0.45))
	if absf(speed) > 0.01:
		var step := forward() * speed * delta
		var bow := boat.global_position + forward() * (float(info.len) * 0.5 + 0.4) * signf(speed) + step
		var why := _blocked(bow.x, bow.z)
		if why != "":
			if absf(speed) > 1.5:
				audio.play("thud", -6.0, 0.8)
				cam.shake(0.3)
			speed = -speed * 0.2
			if why != "shallow" and _warn_t <= 0.0 and aboard:
				_warn_t = 5.0
				hud.toast(why)
			if why.begins_with("You lose your way"):
				heading = wrapf(heading + PI * 0.85, -PI, PI)
				speed = top * 0.4
		else:
			boat.global_position += step
	# bob on the swell, lean into turns
	var wl := float(world.water_level_at(boat.global_position.x, boat.global_position.z))
	boat.global_position.y = wl + sin(_bob_t * 1.6) * 0.05
	boat.rotation = Vector3(sin(_bob_t * 1.3) * 0.025 - speed * 0.006, heading, sin(_bob_t * 1.1) * 0.03)
	if aboard:
		_land_t -= delta
		if _land_t <= 0.0:
			_land_t = 0.25
			_land = landing_spot() if absf(speed) < 2.0 else Vector3.INF
		_place_player()
		if not busy:
			if absf(speed) > 0.3:
				player.face(forward())
			if Input.is_action_just_pressed("cancel") and not hud.input_blocked():
				go_ashore()
	for o in _oars:
		if aboard and absf(speed) > 0.2:
			_row_t += delta * 3.0
		o.rotation.x = sin(_row_t) * 0.5
	if _lamp_light:
		var dark: float = 1.0 - clampf(smoothstep(5.5, 7.0, float(world_hour())) - smoothstep(18.0, 19.5, float(world_hour())), 0.0, 1.0)
		_lamp_light.light_energy = 1.2 * maxf(dark, 0.4 if _in_fog() else 0.0)


func world_hour() -> float:
	return float(sea.env.hour) if sea else 12.0


func _in_fog() -> bool:
	if not boat:
		return false
	return bool(world.flags_at(boat.global_position.x, boat.global_position.z) & int(world.F.fog))


## Why the boat can't go here: "" if it can, "shallow" for the shore, or a message.
func _blocked(x: float, z: float) -> String:
	if not world.is_water(x, z) or world.water_depth(x, z) < MIN_DEPTH:
		return "shallow"
	if world.zone_at(x, z) == "lake":
		return "shallow"
	var need: int = world.tier_at(x, z)
	if need > tier():
		var next := boat_info(_tier_key(need))
		return "The sea's too rough out there for a %s. You'll need a %s." % [info.n, next.get("n", "bigger boat")]
	if world.flags_at(x, z) & int(world.F.fog) and not has_part("lamp"):
		return "You lose your way in the fog and drift back out. A deck lamp would help."
	return ""


func _tier_key(t: int) -> String:
	for b in BOATS:
		if int(b.tier) >= t:
			return str(b.k)
	return "cutter"


func _update_wake(delta: float) -> void:
	for w in _wake:
		if not w.visible:
			continue
		var t := float(w.get_meta("t")) + delta
		w.set_meta("t", t)
		var m: StandardMaterial3D = w.material_override
		m.albedo_color.a = maxf(0.0, 0.5 * (1.0 - t / 1.6))
		w.scale = Vector3.ONE * (1.0 + t * 1.5)
		w.global_position.y = float(world.sea_level) + 0.03
		if t > 1.6:
			w.visible = false
	if not boat or absf(speed) < 1.0:
		return
	_wake_t -= delta
	if _wake_t > 0.0:
		return
	_wake_t = 0.08
	var w := _wake[_wake_i]
	_wake_i = (_wake_i + 1) % _wake.size()
	var stern := boat.global_position - forward() * float(info.len) * 0.45
	w.global_position = Vector3(stern.x + randf_range(-0.3, 0.3), float(world.sea_level) + 0.03, stern.z + randf_range(-0.3, 0.3))
	w.set_meta("t", 0.0)
	w.scale = Vector3.ONE
	w.visible = true


# --- building the boat model -----------------------------------------------------------

## A boat model for someone else (the boats sailing about the bay): its own colour, no
## effect on yours.
func build_model(b: Dictionary, paint: Color, lamp: bool) -> Node3D:
	var keep_oars := _oars
	var keep_lamp := _lamp_light
	var keep_deck := _deck_y
	var root := _make_boat(b, paint, 1 if lamp else 0)
	_oars = keep_oars
	_lamp_light = keep_lamp
	_deck_y = keep_deck
	return root


func _make_boat(b: Dictionary, paint_over := Color(0, 0, 0, 0), lamp_over := -1) -> Node3D:
	var root := Node3D.new()
	root.name = "Boat"
	var length := float(b.len)
	var width := length * 0.38
	var depth := 0.55 + length * 0.04
	var paint_i := int(save.boat_paint)
	var paint := Color.html(str(PAINT[paint_i])) if paint_i >= 0 and paint_i < PAINT.size() else Color.html(str(b.hull))
	if paint_over.a > 0.0:
		paint = paint_over
	_deck_y = depth * 0.62 + 0.03
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(length, width, depth)
	hull.material_override = _flat(paint)
	root.add_child(hull)
	# deck boards and a rail
	var deck := _box(Vector3(width * 0.78, 0.06, length * 0.72), Vector3(0.0, depth * 0.62, length * 0.08), _tex("planks"))
	root.add_child(deck)
	var rail := _flat(paint.lightened(0.45))
	for s in [-1.0, 1.0]:
		var r := _box(Vector3(0.08, 0.1, length * 0.7), Vector3(s * width * 0.47, depth * 0.9, length * 0.08), rail)
		root.add_child(r)
	var wood := _tex("timber")
	_oars = []
	match str(b.k):
		"row":
			root.add_child(_box(Vector3(width * 0.9, 0.08, 0.3), Vector3(0.0, depth * 0.75, 0.0), wood))
			for s in [-1.0, 1.0]:
				var pivot := Node3D.new()
				pivot.position = Vector3(s * width * 0.5, depth * 0.85, 0.0)
				var oar := _box(Vector3(0.06, 0.06, 1.8), Vector3(s * 0.5, -0.15, 0.0), wood)
				oar.rotation.y = s * 0.5
				pivot.add_child(oar)
				root.add_child(pivot)
				_oars.append(pivot)
		"dinghy":
			_mast(root, Vector3(0.0, depth * 0.6, -length * 0.12), 3.2, length * 0.55)
		"skiff":
			root.add_child(_box(Vector3(width * 0.7, 0.6, length * 0.25), Vector3(0.0, depth * 0.62 + 0.3, -length * 0.18), _flat(Color("#e8e2d0"))))
			root.add_child(_box(Vector3(width * 0.66, 0.3, 0.05), Vector3(0.0, depth * 0.62 + 0.75, -length * 0.05), _glass()))
			root.add_child(_box(Vector3(0.3, 0.5, 0.35), Vector3(0.0, depth * 0.5, length * 0.5), _flat(Color("#3a3a40"))))
		"trawler":
			root.add_child(_box(Vector3(width * 0.72, 1.4, length * 0.28), Vector3(0.0, depth * 0.62 + 0.7, -length * 0.08), _flat(Color("#f0ece0"))))
			root.add_child(_box(Vector3(width * 0.74, 0.35, 0.05), Vector3(0.0, depth * 0.62 + 1.05, length * 0.06 + 0.02), _glass()))
			root.add_child(_box(Vector3(width * 0.8, 0.12, length * 0.32), Vector3(0.0, depth * 0.62 + 1.45, -length * 0.08), _flat(paint.darkened(0.2))))
			root.add_child(_cyl(0.06, 3.0, Vector3(0.0, depth * 0.62 + 2.4, -length * 0.08), wood))
			var boom := _box(Vector3(0.06, 0.06, 2.6), Vector3(0.0, depth * 0.62 + 2.2, length * 0.18), wood)
			boom.rotation.x = 0.5
			root.add_child(boom)
			root.add_child(_box(Vector3(width * 0.5, 0.3, 0.8), Vector3(0.0, depth * 0.75, length * 0.33), _flat(Color("#4a7a6a"))))
		"cutter":
			root.add_child(_box(Vector3(width * 0.7, 1.0, length * 0.3), Vector3(0.0, depth * 0.62 + 0.5, -length * 0.05), _flat(Color("#f0ece0"))))
			root.add_child(_box(Vector3(width * 0.72, 0.3, 0.05), Vector3(0.0, depth * 0.62 + 0.75, length * 0.1 + 0.02), _glass()))
			_mast(root, Vector3(0.0, depth * 0.62 + 1.0, -length * 0.08), 4.6, length * 0.5)
	if (lamp_over == -1 and has_part("lamp")) or lamp_over == 1:
		root.add_child(_cyl(0.04, 1.0, Vector3(0.0, depth * 0.62 + 0.5, -length * 0.36), _flat(Color("#3a3a44"))))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.85, 0.5)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.75, 0.4)
		glow.emission_energy_multiplier = 3.0
		root.add_child(_box(Vector3(0.22, 0.26, 0.22), Vector3(0.0, depth * 0.62 + 1.1, -length * 0.36), glow))
		_lamp_light = OmniLight3D.new()
		_lamp_light.light_color = Color(1.0, 0.78, 0.48)
		_lamp_light.omni_range = 9.0
		_lamp_light.position = Vector3(0.0, depth * 0.62 + 1.2, -length * 0.36)
		root.add_child(_lamp_light)
	else:
		_lamp_light = null
	return root


func _mast(root: Node3D, base: Vector3, height: float, sail_len: float) -> void:
	root.add_child(_cyl(0.06, height, base + Vector3(0.0, height * 0.5, 0.0), _tex("timber")))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := base + Vector3(0.0, height - 0.1, 0.0)
	var foot := base + Vector3(0.0, 0.5, 0.0)
	var clew := base + Vector3(0.0, 0.5, sail_len)
	for v in [top, foot, clew, top, clew, foot]:
		st.add_vertex(v)
	st.generate_normals()
	var sail := MeshInstance3D.new()
	sail.mesh = st.commit()
	var cloth := _flat(Color("#f4f0e4"))
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = cloth
	root.add_child(sail)
	root.add_child(_box(Vector3(0.05, 0.05, sail_len), base + Vector3(0.0, 0.5, sail_len * 0.5), _tex("timber")))


## A rounded hull: pointed at the bow (-Z), square at the stern.
func _hull_mesh(length: float, width: float, depth: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var rings: Array = []
	for i in n + 1:
		var t := float(i) / n  # 0 stern, 1 bow
		var z := length * 0.5 - t * length
		var hw := width * 0.5 * pow(maxf(0.0, 1.0 - pow(t, 2.6)), 0.55)
		var sheer := depth * (0.62 + 0.25 * t * t)  # the bow rises
		var keel := -depth * 0.38 * (1.0 - 0.5 * t)
		rings.append([Vector3(-hw, sheer, z), Vector3(-hw * 0.8, keel * 0.35, z), Vector3(0.0, keel, z),
			Vector3(hw * 0.8, keel * 0.35, z), Vector3(hw, sheer, z)])
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in 4:
			var p0: Vector3 = a[k]
			var p1: Vector3 = a[k + 1]
			var p2: Vector3 = b[k + 1]
			var p3: Vector3 = b[k]
			for v in [p0, p1, p2, p0, p2, p3]:
				st.add_vertex(v)
	# the transom
	var s: Array = rings[0]
	for k in 3:
		for v in [s[0], s[k + 2], s[k + 1]]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.45, 0.6)
	m.metallic = 0.3
	m.roughness = 0.1
	return m


func _tex(tex_name: String) -> StandardMaterial3D:
	if _mats.has(tex_name):
		return _mats[tex_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://art/tex/%s.png" % tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_mats[tex_name] = m
	return m
