extends RefCounted
## The shared look for menus: the web game's pixel font, ink panels with a cream edge,
## and buttons that light up gold when focused (keyboard and gamepad friendly).

const CREAM := Color(0.98, 0.95, 0.86)
const GOLD := Color(1.0, 0.84, 0.45)
const SKY := Color(0.72, 0.87, 1.0)
const DIM := Color(0.62, 0.64, 0.72)
const GOOD := Color(0.6, 1.0, 0.7)
const BAD := Color(1.0, 0.55, 0.5)
const PANEL := Color(0.07, 0.09, 0.17, 0.94)
const EDGE := Color(0.96, 0.86, 0.62)
const RARITY_COLORS := [Color(0.86, 0.86, 0.8), Color(0.5, 0.88, 0.52), Color(0.48, 0.72, 1.0), Color(1.0, 0.72, 0.3), Color(1.0, 0.45, 0.62)]

static var _font: Font
static var _bold: Font


static func font(bold := false) -> Font:
	if _font == null:
		_font = load("res://art/fonts/pixelify_sans.woff2")
		_bold = load("res://art/fonts/pixelify_sans_bold.woff2")
	return _bold if bold else _font


static func box(bg: Color, edge: Color, border := 3, pad := 12.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(border)
	b.set_corner_radius_all(6)
	b.corner_detail = 2
	b.content_margin_left = pad + 4.0
	b.content_margin_right = pad + 4.0
	b.content_margin_top = pad * 0.6
	b.content_margin_bottom = pad * 0.6
	return b


static func panel(pad := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PANEL, EDGE, 3, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Give a control the keyboard and pad focus on the next frame, if it's still on screen then
## (a panel can close in the frame it opened).
static func focus_soon(c: Control) -> void:
	if c == null:
		return
	var grab := func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree() and c.focus_mode == Control.FOCUS_ALL:
			c.grab_focus()
	grab.call_deferred()


static func button(text: String, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	var normal := box(Color(0.12, 0.15, 0.26, 0.95), Color(0.3, 0.34, 0.5), 2, 8.0)
	var lit := box(Color(0.16, 0.2, 0.34, 0.98), GOLD, 3, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("disabled", box(Color(0.09, 0.1, 0.17, 0.9), Color(0.2, 0.22, 0.3), 2, 8.0))
	return b
