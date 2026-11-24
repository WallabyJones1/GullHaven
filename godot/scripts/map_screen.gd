extends CanvasLayer
## The world map (M, or Start on a gamepad). It fills in as you explore: everywhere you've
## been within about 60 m is uncovered, and climbing the lighthouse shows the whole bay.
## Marks you, your boat, your hut, every town you've found, and what's still locked.

const UI := preload("res://scripts/ui_kit.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const CELL := 32.0  # metres per fog cell
const SEE := 64.0  # how far around you the map uncovers


## The pins and labels drawn over the map.
class Marks extends Control:
	const UIK := preload("res://scripts/ui_kit.gd")

	var screen: CanvasLayer

	func _draw() -> void:
		var s: CanvasLayer = screen
		var font: Font = UIK.font(true)
		# towns you've found
		for t in s.world.meta.towns:
			var p: Vector2 = s.to_map(float(t.x), float(t.z))
			if not s.seen_at(float(t.x), float(t.z)):
				continue
			draw_circle(p, 6.0, Color(0.98, 0.9, 0.65))
			draw_arc(p, 6.0, 0.0, TAU, 16, Color(0.25, 0.16, 0.1), 2.0)
			var label := str(t.name)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string_outline(font, p + Vector2(-w * 0.5, -12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0.1, 0.08, 0.06))
			draw_string(font, p + Vector2(-w * 0.5, -12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.98, 0.94, 0.82))
		# locked places
		for g in s.world.meta.gates:
			if not s.world.permits.has(str(g.needs)) and s.seen_at(float(g.x), float(g.z)):
				_cross(s.to_map(float(g.x), float(g.z)), Color(0.9, 0.3, 0.25))
		var b: Dictionary = s.world.meta.bridge
		if not s.world.permits.has("bridge") and s.seen_at(float(b.x), float(b.z)):
			_cross(s.to_map(float(b.x), float(b.z)), Color(0.9, 0.3, 0.25))
		# your hut
		var hut: Dictionary = s.world.meta.hut
		var hp: Vector2 = s.to_map(float(hut.x), float(hut.z))
		draw_colored_polygon(PackedVector2Array([hp + Vector2(-7, 2), hp + Vector2(0, -7), hp + Vector2(7, 2), hp + Vector2(5, 2),
			hp + Vector2(5, 7), hp + Vector2(-5, 7), hp + Vector2(-5, 2)]), Color(0.95, 0.6, 0.3))
		# your boat
		if s.boats and s.boats.boat and not s.boats.aboard:
			var bp: Vector3 = s.boats.boat.global_position
			var m: Vector2 = s.to_map(bp.x, bp.z)
			draw_colored_polygon(PackedVector2Array([m + Vector2(-7, -2), m + Vector2(7, -2), m + Vector2(4, 4), m + Vector2(-4, 4)]), Color(0.45, 0.75, 1.0))
			draw_line(m + Vector2(0, -2), m + Vector2(0, -10), Color(0.95, 0.95, 0.9), 2.0)
		# you
		var pp: Vector3 = s.player.global_position
		if s.interiors and s.interiors.is_inside():
			pp = s.interiors.inside.door
		var me: Vector2 = s.to_map(pp.x, pp.z)
		var f: Vector3 = s.player.facing
		var fwd := Vector2(f.x, f.z).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.008)
		draw_colored_polygon(PackedVector2Array([me + fwd * 11.0 * pulse, me - fwd * 6.0 + side * 7.0, me - fwd * 3.0, me - fwd * 6.0 - side * 7.0]),
			Color(1.0, 0.85, 0.2))
		draw_polyline(PackedVector2Array([me + fwd * 11.0 * pulse, me - fwd * 6.0 + side * 7.0, me - fwd * 3.0, me - fwd * 6.0 - side * 7.0,
			me + fwd * 11.0 * pulse]), Color(0.2, 0.1, 0.05), 2.0)

	func _cross(p: Vector2, c: Color) -> void:
		draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), c, 3.0)
		draw_line(p + Vector2(6, -6), p + Vector2(-6, 6), c, 3.0)


var world: Node3D
var player: CharacterBody3D
var boats: Node3D
var interiors: Node3D
var hud: CanvasLayer
var audio: Node
var save: Dictionary
var is_open := false
var _cols := 40
var _rows := 32
var _seen := PackedByteArray()
var _frame: Control
var _map_rect: TextureRect
var _fog_rect: TextureRect
var _fog_img: Image
var _fog_tex: ImageTexture
var _marks: Marks
var _count: Label
var _dirty := false  # the fog picture needs redrawing
var _unsaved := false  # the save needs the new uncovered cells


func setup(w: Node3D, p: CharacterBody3D, h: CanvasLayer, a: Node, sv: Dictionary) -> void:
	world = w
	player = p
	hud = h
	audio = a
	save = sv
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cols = int(ceil(float(world.W) / CELL))
	_rows = int(ceil(float(world.H) / CELL))
	_seen.resize(_cols * _rows)
	var stored := str(save.get("seen", ""))
	for i in mini(stored.length(), _seen.size()):
		_seen[i] = 1 if stored[i] == "1" else 0
	_fog_img = Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UI.panel(14.0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_child(UI.label("Map of the coast", 30, UI.GOLD, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_count = UI.label("", 20, UI.SKY)
	top.add_child(_count)
	col.add_child(top)
	_frame = Control.new()
	col.add_child(_frame)
	_map_rect = TextureRect.new()
	_map_rect.texture = load("res://world/map.png")
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_frame.add_child(_map_rect)
	_fog_rect = TextureRect.new()
	_fog_rect.texture = _fog_tex
	_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_frame.add_child(_fog_rect)
	_marks = Marks.new()
	_marks.screen = self
	_frame.add_child(_marks)
	col.add_child(UI.label("Yellow arrow: you   Blue: your boat   Orange: your hut   Red cross: locked   M or Esc to close", 17, UI.DIM))


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var aspect := float(world.W) / float(world.H)
	var h := minf(view.y * 0.78, view.x * 0.86 / aspect)
	var size := Vector2(h * aspect, h)
	_frame.custom_minimum_size = size
	for c in [_map_rect, _fog_rect, _marks]:
		c.position = Vector2.ZERO
		c.size = size


func to_map(x: float, z: float) -> Vector2:
	return Vector2(x / float(world.W), z / float(world.H)) * _frame.custom_minimum_size


func seen_at(x: float, z: float) -> bool:
	var cx := int(x / CELL)
	var cz := int(z / CELL)
	if cx < 0 or cz < 0 or cx >= _cols or cz >= _rows:
		return false
	return _seen[cz * _cols + cx] == 1


## Uncover the map in a circle (metres).
func reveal(x: float, z: float, radius: float) -> void:
	var r := int(ceil(radius / CELL))
	var cx := int(x / CELL)
	var cz := int(z / CELL)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var ix := cx + dx
			var iz := cz + dz
			if ix < 0 or iz < 0 or ix >= _cols or iz >= _rows:
				continue
			var c := Vector2((ix + 0.5) * CELL - x, (iz + 0.5) * CELL - z)
			if c.length() <= radius + CELL * 0.5 and _seen[iz * _cols + ix] == 0:
				_seen[iz * _cols + ix] = 1
				_dirty = true
				_unsaved = true


## Called a couple of times a second with where you are.
func mark(at: Vector3) -> void:
	reveal(at.x, at.z, SEE)
	if _unsaved:
		_unsaved = false
		var s := ""
		for v in _seen:
			s += "1" if v == 1 else "0"
		save.seen = s


func open() -> void:
	_layout()
	_update_fog()
	var n := 0
	for v in _seen:
		n += int(v)
	_count.text = "%d%% explored" % int(round(100.0 * n / maxf(1.0, float(_seen.size()))))
	is_open = true
	visible = true
	get_tree().paused = true
	audio.play("cardflip", -6.0)
	_marks.queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	get_tree().set_deferred("paused", false)
	hud.block_input(0.25)
	audio.play("click")
	SaveGame.write(save)


func _process(_delta: float) -> void:
	if is_open:
		_marks.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()


func _update_fog() -> void:
	for iz in _rows:
		for ix in _cols:
			var on := _seen[iz * _cols + ix] == 1
			_fog_img.set_pixel(ix, iz, Color(0.0, 0.0, 0.0, 0.0) if on else Color(0.16, 0.13, 0.1, 0.94))
	_fog_tex.update(_fog_img)
	_dirty = false
