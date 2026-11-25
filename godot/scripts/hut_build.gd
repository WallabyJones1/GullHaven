extends Node3D
## Arranging your hut. Inside your hut press B (or use "Arrange your furniture") to start:
## a ghost shows where the chosen piece will go. Move it with the move keys, Q / E to pick
## a piece from what you own, R to turn it, Space to put it down (or, over something
## already placed, to pick that up again), and Esc or B when you're done.
## Wall pieces (paintings, the rod rack, the fireplace...) snap to the nearest wall.

const Furniture := preload("res://scripts/furniture.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Glyphs := preload("res://scripts/input_glyphs.gd")

const REPEAT := 0.13

var interiors: Node3D
var player: CharacterBody3D
var cam: Camera3D
var hud: CanvasLayer
var audio: Node
var save: Dictionary
var active := false
var _cursor := Vector2.ZERO  # room-local x, z
var _rot := 0
var _sel := 0
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _bar: CanvasLayer
var _bar_label: Label
var _hint: Label
var _repeat_t := 0.0
var _held := false
var _fresh := false  # skip the frame you opened it on (that Space press isn't for us)


func setup(i: Node3D, p: CharacterBody3D, c: Camera3D, h: CanvasLayer, a: Node, sv: Dictionary) -> void:
	interiors = i
	player = p
	cam = c
	hud = h
	audio = a
	save = sv
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.6, 0.35)
	_ghost_mat.no_depth_test = true
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	add_child(_ghost)
	_bar = CanvasLayer.new()
	_bar.layer = 12
	_bar.visible = false
	add_child(_bar)
	var row := CenterContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -120.0
	row.offset_bottom = -20.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)
	var panel := UI.panel(12.0)
	row.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	_bar_label = UI.label("", 26, UI.GOLD, true)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_bar_label)
	_hint = Glyphs.bind(UI.label("", 18, UI.DIM), "{move} shift it   {rotate_left}/{rotate_right} choose   {bait} turn   {action} put down / pick up   {cancel} done")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)


func begin() -> void:
	if active or not interiors.can_arrange():
		return
	active = true
	hud.modal = true
	player.can_move = false
	cam.lock_turn = true
	var o: Vector3 = interiors.origin()
	var p := player.global_position - o
	_cursor = Vector2(snappedf(p.x, Furniture.CELL), snappedf(p.z - 1.0, Furniture.CELL))
	_sel = 0
	_rot = 0
	_ghost.visible = true
	_bar.visible = true
	_fresh = true
	cam.target = _ghost
	hud.set_prompt("")
	audio.play("click")
	_refresh()


func finish() -> void:
	if not active:
		return
	active = false
	hud.modal = false
	hud.block_input(0.25)
	player.can_move = true
	cam.lock_turn = false
	cam.target = player
	_ghost.visible = false
	_bar.visible = false
	SaveGame.write(save)
	audio.play("click")


func _process(delta: float) -> void:
	if not interiors:
		return
	if not active:
		if interiors.can_arrange() and Input.is_action_just_pressed("build") and not hud.input_blocked():
			begin()
		return
	if not interiors.can_arrange():
		finish()
		return
	if _fresh:
		_fresh = false
		_refresh()
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("build"):
		finish()
		return
	var owned := _owned()
	if Input.is_action_just_pressed("rotate_left") and not owned.is_empty():
		_sel = (_sel + owned.size() - 1) % owned.size()
		audio.play("click", -8.0)
	if Input.is_action_just_pressed("rotate_right") and not owned.is_empty():
		_sel = (_sel + 1) % owned.size()
		audio.play("click", -8.0)
	if Input.is_action_just_pressed("bait"):
		_rot = (_rot + 1) % 4
		audio.play("click", -8.0)
	# step the ghost a cell at a time, repeating while held
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_repeat_t -= delta
	var go := false
	if input.length() > 0.5:
		if not _held:
			_held = true
			go = true
			_repeat_t = 0.3
		elif _repeat_t <= 0.0:
			go = true
			_repeat_t = REPEAT
	else:
		_held = false
	if go:
		var step := Vector2(roundf(input.x), roundf(input.y)) * Furniture.CELL
		var size: Vector2 = interiors.room_size()
		_cursor.x = clampf(_cursor.x + step.x, -size.x * 0.5 + 0.25, size.x * 0.5 - 0.25)
		_cursor.y = clampf(_cursor.y + step.y, -size.y * 0.5 + 0.25, size.y * 0.5 - 0.25)
		audio.play("step_wood", -16.0, 1.4)
	if Input.is_action_just_pressed("action"):
		_act()
	_refresh()


## What you own and haven't placed, as a list of ids.
func _owned() -> Array:
	var out: Array = []
	var inv: Dictionary = save.furniture_inv
	for id in Furniture.ITEMS:  # the hut's own pieces first, then catalogue pieces you've bought
		if int(inv.get(id, 0)) > 0:
			out.append(id)
	var extra: Array = []
	for id in inv:
		if not Furniture.ITEMS.has(id) and int(inv[id]) > 0 and not Furniture.data(str(id)).is_empty():
			extra.append(str(id))
	extra.sort()
	out.append_array(extra)
	if _sel >= out.size():
		_sel = 0
	return out


func _selected() -> String:
	var owned := _owned()
	return str(owned[_sel]) if not owned.is_empty() else ""


func _act() -> void:
	var hit := _placed_under()
	if hit >= 0:
		var placed: Array = interiors.placed_list()
		var item: Dictionary = placed[hit]
		placed.remove_at(hit)
		Furniture.give(save, str(item.id))
		audio.play("thud", -6.0)
		interiors.refresh()
		return
	var id := _selected()
	if id == "":
		hud.toast("Nothing to put down. The Home Catalogue by the door sells furniture." if interiors.in_home()
			else "Nothing to put down. Tess the carpenter, Fern at Home Goods and the salvager sell furniture.")
		audio.play("error", -6.0)
		return
	var item := _candidate(id)
	if item.is_empty():
		audio.play("error", -6.0)
		return
	var placed: Array = interiors.placed_list()
	placed.append(item)
	var inv: Dictionary = save.furniture_inv
	inv[id] = int(inv[id]) - 1
	if int(inv[id]) <= 0:
		inv.erase(id)
	audio.play("step_wood", -2.0)
	interiors.refresh()


## The piece of furniture under the ghost, as an index into the placed list (interiors.placed_list()), or -1.
func _placed_under() -> int:
	var placed: Array = interiors.placed_list()
	var size: Vector2 = interiors.room_size()
	var wall := _nearest_wall()
	for i in placed.size():
		var item: Dictionary = placed[i]
		var data: Dictionary = Furniture.data(str(item.id))
		if data.is_empty():
			continue
		if str(data.kind) == "wall":
			if str(item.side) != str(wall.side):
				continue
			var half := Furniture.wall_width(str(item.id)) * 0.5
			if absf(float(wall.along) - float(item.along)) <= half and _dist_to_wall(wall, size) < 1.2:
				return i
		else:
			if _rect_of(item).has_point(_cursor):
				return i
	return -1


## The item that would be placed at the ghost, or {} if it doesn't fit there.
func _candidate(id: String) -> Dictionary:
	var data: Dictionary = Furniture.data(id)
	var size: Vector2 = interiors.room_size()
	var fixed: Dictionary = interiors.arrange_fixed()
	var placed: Array = interiors.placed_list()
	if str(data.kind) == "wall":
		var wall := _nearest_wall()
		var half := Furniture.wall_width(id) * 0.5
		var limit: float = (size.x if wall.side == "back" else size.y) * 0.5 - 0.15
		var along := clampf(float(wall.along), -limit + half, limit - half)
		for f in fixed.walls:
			if f.side == wall.side and along + half > float(f.from) and along - half < float(f.to):
				return {}
		for other in placed:
			var od: Dictionary = Furniture.data(str(other.id))
			if od.is_empty() or str(od.kind) != "wall" or str(other.side) != str(wall.side):
				continue
			var oh := Furniture.wall_width(str(other.id)) * 0.5
			if absf(along - float(other.along)) < half + oh:
				return {}
		return {"id": id, "side": str(wall.side), "along": snappedf(along, 0.05)}
	var item := {"id": id, "x": _cursor.x, "z": _cursor.y, "rot": _rot}
	var r := _rect_of(item)
	var room := Rect2(-size.x * 0.5 + 0.1, -size.y * 0.5 + 0.1, size.x - 0.2, size.y - 0.2)
	if not room.encloses(r):
		return {}
	var is_rug := str(data.kind) == "rug"
	if not is_rug:
		for f: Rect2 in fixed.floor:
			if f.intersects(r):
				return {}
	for other in placed:
		var od: Dictionary = Furniture.data(str(other.id))
		if od.is_empty() or str(od.kind) == "wall":
			continue
		if (str(od.kind) == "rug") != is_rug:
			continue  # rugs lie under things
		if _rect_of(other).grow(-0.01).intersects(r):
			return {}
	return item


func _rect_of(item: Dictionary) -> Rect2:
	var fp := Furniture.footprint(str(item.id), int(item.get("rot", 0)))
	return Rect2(float(item.x) - fp.x * 0.5, float(item.z) - fp.y * 0.5, fp.x, fp.y)


## The wall nearest the ghost: {side, along}.
func _nearest_wall() -> Dictionary:
	var size: Vector2 = interiors.room_size()
	var d_back := _cursor.y + size.y * 0.5
	var d_left := _cursor.x + size.x * 0.5
	var d_right := size.x * 0.5 - _cursor.x
	if d_back <= d_left and d_back <= d_right:
		return {"side": "back", "along": _cursor.x}
	if d_left < d_right:
		return {"side": "left", "along": _cursor.y}
	return {"side": "right", "along": _cursor.y}


func _dist_to_wall(wall: Dictionary, size: Vector2) -> float:
	match str(wall.side):
		"back":
			return _cursor.y + size.y * 0.5
		"left":
			return _cursor.x + size.x * 0.5
	return size.x * 0.5 - _cursor.x


## Move the ghost and colour it: green where the piece fits, red where it doesn't, gold
## over something you could pick up.
func _refresh() -> void:
	var o: Vector3 = interiors.origin()
	var size: Vector2 = interiors.room_size()
	var id := _selected()
	var mesh: BoxMesh = _ghost.mesh
	var under := _placed_under()
	var ok := false
	if under >= 0:
		_ghost_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.4)
	if id != "" and str(Furniture.data(id).kind) == "wall" and under < 0:
		var wall := _nearest_wall()
		var w := Furniture.wall_width(id)
		var y := float(Furniture.data(id).get("y", 1.2)) + 0.6
		match str(wall.side):
			"back":
				mesh.size = Vector3(w, 1.2, 0.1)
				_ghost.global_position = o + Vector3(float(wall.along), y, -size.y * 0.5 + 0.1)
			"left":
				mesh.size = Vector3(0.1, 1.2, w)
				_ghost.global_position = o + Vector3(-size.x * 0.5 + 0.1, y, float(wall.along))
			_:
				mesh.size = Vector3(0.1, 1.2, w)
				_ghost.global_position = o + Vector3(size.x * 0.5 - 0.1, y, float(wall.along))
		ok = not _candidate(id).is_empty()
	else:
		var fp := Furniture.footprint(id, _rot) if id != "" else Vector2(0.5, 0.5)
		mesh.size = Vector3(fp.x, 0.08, fp.y)
		_ghost.global_position = o + Vector3(_cursor.x, 0.05, _cursor.y)
		ok = id != "" and not _candidate(id).is_empty()
	if under < 0:
		_ghost_mat.albedo_color = Color(0.4, 1.0, 0.6, 0.38) if ok else Color(1.0, 0.35, 0.3, 0.38)
	var owned := _owned()
	var inv: Dictionary = save.furniture_inv
	if under >= 0:
		var placed: Array = interiors.placed_list()
		var it: Dictionary = placed[under]
		_bar_label.text = "Space: pick up the %s" % str(Furniture.data(str(it.id)).n).to_lower()
	elif id == "":
		_bar_label.text = "You haven't any furniture to put down"
	else:
		_bar_label.text = "<  %s  x%d  >   (%d of %d)" % [Furniture.data(id).n, int(inv.get(id, 0)), _sel + 1, owned.size()]
