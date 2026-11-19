extends RefCounted

const INK := Color("#11181b")
const SHELL := Color("#152024")
const PANEL := Color("#1d2a2e")
const PANEL_HIGH := Color("#28383b")
const EDGE := Color("#47595a")
const PAPER := Color("#f4eddb")
const MUTE := Color("#afbfbc")
const ACID := Color("#dae690")
const SOFT_ACID := Color("#303b2c")
const GOLD := Color("#efbd83")
const FAIL := Color("#ff9b94")

const BODY = preload("res://src/ui/fonts/DejaVuSansCondensed.ttf")
const DISPLAY = preload("res://src/ui/fonts/DejaVuSansCondensed-BoldOblique.ttf")
const MONO = preload("res://src/ui/fonts/DejaVuSansMono.ttf")


static func skin() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PAPER)
	for type_name in ["Button", "OptionButton", "CheckButton"]:
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			theme.set_color(state, type_name, PAPER)
		theme.set_color("font_disabled_color", type_name, Color("#79838e"))
		theme.set_stylebox("normal", type_name, box(PANEL, EDGE, 1, 5, 12, 7))
		theme.set_stylebox("hover", type_name, box(PANEL_HIGH, MUTE, 1, 5, 12, 7))
		theme.set_stylebox("pressed", type_name, box(SOFT_ACID, ACID, 1, 5, 12, 7))
		theme.set_stylebox("disabled", type_name, box(SHELL, EDGE, 1, 5, 12, 7))
		theme.set_stylebox("focus", type_name, box(Color.TRANSPARENT, ACID, 2, 5))
	theme.set_stylebox("normal", "LineEdit", box(INK, EDGE, 1, 4, 12, 8))
	theme.set_stylebox("focus", "LineEdit", box(INK, ACID, 1, 4, 12, 8))
	theme.set_color("font_color", "LineEdit", PAPER)
	theme.set_color("selection_color", "LineEdit", SOFT_ACID)
	theme.set_color("font_color", "PopupMenu", PAPER)
	theme.set_font_size("font_size", "PopupMenu", 17)
	theme.set_constant("v_separation", "PopupMenu", 12)
	theme.set_stylebox("panel", "PopupMenu", box(SHELL, EDGE, 1, 4, 10, 8))
	theme.set_stylebox("hover", "PopupMenu", box(SOFT_ACID, ACID, 1, 4, 10, 8))
	theme.set_stylebox("slider", "HSlider", box(EDGE, Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("grabber_area", "HSlider", box(ACID, Color.TRANSPARENT, 0, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color.TRANSPARENT, 0, 2))
	for axis in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", axis, box(INK, Color.TRANSPARENT, 0, 2, 4, 4))
		theme.set_stylebox("grabber", axis, box(EDGE, Color.TRANSPARENT, 0, 2, 4, 4))
		theme.set_stylebox("grabber_highlight", axis, box(MUTE, Color.TRANSPARENT, 0, 2, 4, 4))
		theme.set_stylebox("grabber_pressed", axis, box(ACID, Color.TRANSPARENT, 0, 2, 4, 4))
	return theme


static func box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6, h_pad: int = 0, v_pad: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = h_pad
	style.content_margin_right = h_pad
	style.content_margin_top = v_pad
	style.content_margin_bottom = v_pad
	style.anti_aliasing = radius > 0
	style.anti_aliasing_size = 1.0
	return style


static func panel(fill: Color = PANEL, border: Color = EDGE, h_pad: int = 16, v_pad: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(fill, border, 1, 9, h_pad, v_pad))
	return node


static func label(content: String, points: int = 17, tint: Color = PAPER, face: Font = BODY) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_override("font", face)
	node.add_theme_font_size_override("font_size", points)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func meta(content: String, tint: Color = MUTE, points: int = 12) -> Label:
	return label(content, points, tint, MONO)


static func paragraph(content: String, points: int = 17, tint: Color = MUTE) -> Label:
	var node := label(content, points, tint)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func button(content: String, primary: bool = false, height: int = 44) -> Button:
	var node := Button.new()
	node.text = content
	node.custom_minimum_size.y = height
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", DISPLAY)
	node.add_theme_font_size_override("font_size", 16)
	if primary:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(state, INK)
		node.add_theme_stylebox_override("normal", box(ACID, ACID, 1, 8, 13, 8))
		node.add_theme_stylebox_override("hover", box(Color("#ebf2b5"), Color("#ebf2b5"), 1, 8, 13, 8))
		node.add_theme_stylebox_override("pressed", box(Color("#b0bd71"), ACID, 1, 8, 13, 8))
		node.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, PAPER, 2, 8))
	return node


static func row(gap: int = 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node


static func column(gap: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node


static func stretch(vertical: bool = false) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var node := MarginContainer.new()
	node.add_theme_constant_override("margin_left", left)
	node.add_theme_constant_override("margin_top", top)
	node.add_theme_constant_override("margin_right", right)
	node.add_theme_constant_override("margin_bottom", bottom)
	return node


static func line(tint: Color = EDGE, vertical: bool = false) -> ColorRect:
	var node := ColorRect.new()
	node.color = tint
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		node.custom_minimum_size.x = 1
	else:
		node.custom_minimum_size.y = 1
	return node


static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += "."
		formatted += digits[index]
	return ("−Cr " if amount < 0 else "Cr ") + formatted


class Glyph extends Control:
	var kind := ""
	var ink := PAPER

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		visibility_changed.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y) / 24.0
		draw_set_transform((size - Vector2.ONE * 24.0 * s) * 0.5, 0.0, Vector2.ONE * s)
		match kind:
			"logo":
				for index in 3:
					var x := float(index) * 6.0
					draw_colored_polygon(PackedVector2Array([Vector2(x + 6, 4), Vector2(x + 11, 4), Vector2(x + 5, 20), Vector2(x, 20)]), ink)
			"garage":
				_path([Vector2(3, 11), Vector2(12, 4), Vector2(21, 11), Vector2(21, 20), Vector2(3, 20), Vector2(3, 11)])
				_path([Vector2(7, 20), Vector2(7, 12), Vector2(17, 12), Vector2(17, 20)])
				_path([Vector2(8, 16), Vector2(16, 16)])
			"flag":
				_path([Vector2(5, 21), Vector2(5, 4), Vector2(20, 4), Vector2(20, 14), Vector2(5, 14)])
				for grid in [Vector2(5, 4), Vector2(10, 9), Vector2(15, 4)]:
					draw_rect(Rect2(grid, Vector2(5, 5)), ink)
			"meet":
				_path([Vector2(3, 18), Vector2(7, 14), Vector2(11, 14), Vector2(15, 8), Vector2(21, 8)])
				_path([Vector2(3, 12), Vector2(7, 8), Vector2(11, 8), Vector2(15, 14), Vector2(21, 14)])
				_path([Vector2(18, 5), Vector2(21, 8), Vector2(18, 11)])
			"market":
				_path([Vector2(3, 9), Vector2(12, 3), Vector2(21, 9), Vector2(21, 20), Vector2(3, 20), Vector2(3, 9)])
				_path([Vector2(7, 13), Vector2(17, 13)])
				_path([Vector2(7, 16), Vector2(14, 16)])
			"trophy":
				_path([Vector2(7, 4), Vector2(17, 4), Vector2(17, 10), Vector2(14, 14), Vector2(10, 14), Vector2(7, 10), Vector2(7, 4)])
				_path([Vector2(7, 6), Vector2(3, 6), Vector2(3, 9), Vector2(7, 11)])
				_path([Vector2(17, 6), Vector2(21, 6), Vector2(21, 9), Vector2(17, 11)])
				_path([Vector2(12, 14), Vector2(12, 19), Vector2(8, 21), Vector2(16, 21), Vector2(12, 19)])
			"gear":
				draw_arc(Vector2(12, 12), 7.0, 0, TAU, 16, ink, 1.5, true)
				draw_arc(Vector2(12, 12), 2.4, 0, TAU, 12, ink, 1.5, true)
				for index in 8:
					var direction := Vector2.from_angle(TAU * index / 8.0)
					draw_line(Vector2(12, 12) + direction * 7.0, Vector2(12, 12) + direction * 9.6, ink, 2.0, true)
			"car":
				_path([Vector2(3, 17), Vector2(3, 11), Vector2(7, 9), Vector2(9, 5), Vector2(16, 5), Vector2(20, 9), Vector2(21, 12), Vector2(21, 17), Vector2(3, 17)])
				_path([Vector2(7, 10), Vector2(19, 10)])
				draw_circle(Vector2(7, 17), 2.6, ink)
				draw_circle(Vector2(17, 17), 2.6, ink)
			"arrow":
				_path([Vector2(4, 12), Vector2(20, 12), Vector2(14, 6)])
				_path([Vector2(20, 12), Vector2(14, 18)])
			"chevron":
				_path([Vector2(9, 6), Vector2(15, 12), Vector2(9, 18)])
			"paint":
				_path([Vector2(12, 3), Vector2(20, 13), Vector2(19, 18), Vector2(15, 21), Vector2(9, 21), Vector2(5, 18), Vector2(4, 13), Vector2(12, 3)])
				_path([Vector2(8, 16), Vector2(10, 18), Vector2(13, 18)])
			"close":
				_path([Vector2(6, 6), Vector2(18, 18)])
				_path([Vector2(18, 6), Vector2(6, 18)])

	func _path(points: Array[Vector2]) -> void:
		draw_polyline(PackedVector2Array(points), ink, 1.65, true)


static func glyph(kind: String, pixels: int = 22, tint: Color = PAPER) -> Control:
	var node := Glyph.new()
	node.kind = kind
	node.ink = tint
	node.custom_minimum_size = Vector2.ONE * pixels
	return node
