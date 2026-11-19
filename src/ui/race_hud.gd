extends Control

signal controls_changed(steer: float, throttle: float, brake: float, handbrake: bool)
signal pause_changed(paused: bool)
signal reset_requested
signal camera_requested
signal withdraw_requested
signal return_requested
signal retry_requested

const Ui = preload("res://src/ui/ui_kit.gd")
const INK := Color(0.066, 0.100, 0.105, 0.87)
const LINE := Color(0.36, 0.45, 0.44, 0.85)
const PAPER := Ui.PAPER
const MUTED := Ui.MUTE
const ACCENT := Ui.ACID
const HOT := Color("#f1a08a")
const MODE_NAMES := {
	"circuit": "CIRCUITO",
	"sprint": "SPRINT",
	"time_trial": "CONTRARRELÓGIO",
	"drag": "ARRANCADA",
	"championship": "CAMPEONATO",
	"practice": "TREINO LIVRE",
}
const TOUCH_KEYS := ["left", "right", "brake", "aux", "throttle"]

var ticket: Dictionary
var telemetry: Dictionary
var course: PackedVector2Array
var modal: Control
var pause_button: Button
var touch_zones: Dictionary
var touches: Dictionary
var paused := false
var finished := false
var confirming_withdrawal := false
var show_touch := false
var text_font: Font = Ui.BODY
var number_font: Font = Ui.MONO
var _panel_styles: Dictionary = {}
var _pedal := Ui.box(Color(0.066, 0.10, 0.105, 0.70), LINE, 1, 13)
var _pedal_primary := Ui.box(Color(0.13, 0.17, 0.13, 0.80), ACCENT, 1, 13)
var _pedal_down := Ui.box(PAPER, PAPER, 1, 13)
var _pedal_primary_down := Ui.box(ACCENT, ACCENT, 1, 13)


func configure(race_ticket: Dictionary, outline: PackedVector2Array) -> void:
	ticket = race_ticket
	course = outline
	var practice := str(ticket.event.get("mode", "")) == "practice"
	telemetry = {"countdown": -1 if practice else 3, "phase": "racing" if practice else "countdown", "laps": int(ticket.event.get("laps", 1))}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_touch = OS.has_feature("mobile") or "--touch-controls" in OS.get_cmdline_user_args()
	pause_button = _button("Ⅱ", _toggle_pause, false)
	pause_button.tooltip_text = "Pausar · Esc"
	pause_button.add_theme_font_size_override("font_size", 25)
	pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(pause_button)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	pause_button.position = Vector2(size.x - 86.0, 22.0)
	pause_button.size = Vector2(60.0, 52.0)

	var bottom := size.y - 126.0
	touch_zones = {
		"left": Rect2(24, bottom, 92, 94),
		"right": Rect2(128, bottom, 92, 94),
		"brake": Rect2(size.x - 294.0, bottom, 94, 94),
		"aux": Rect2(size.x - 188.0, bottom, 66, 94),
		"throttle": Rect2(size.x - 110.0, bottom - 20.0, 86, 114),
	}
	queue_redraw()


func update_telemetry(data: Dictionary) -> void:
	telemetry = data
	queue_redraw()


func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event is InputEventScreenTouch:
		if not show_touch:
			show_touch = true
			queue_redraw()
		var previous: String = touches.get(event.index, "")
		if event.pressed:
			var zone := _touch_key(event.position)
			if zone.is_empty():
				return
			touches[event.index] = zone
		else:
			touches.erase(event.index)
			if previous.is_empty():
				return
		_emit_touch()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = _touch_key(event.position)
		_emit_touch()
		get_viewport().set_input_as_handled()
	elif show_touch and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device >= 0:
		if event.pressed:
			var zone := _touch_key(event.position)
			if zone.is_empty():
				return
			touches[-2] = zone
		elif not touches.has(-2):
			return
		else:
			touches.erase(-2)
		_emit_touch()
		get_viewport().set_input_as_handled()
	elif show_touch and event is InputEventMouseMotion and touches.has(-2):
		touches[-2] = _touch_key(event.position)
		_emit_touch()
		get_viewport().set_input_as_handled()


func _touch_key(at: Vector2) -> String:
	for key in TOUCH_KEYS:
		if touch_zones.has(key) and touch_zones[key].has_point(at):
			return key
	return ""


func _emit_touch() -> void:
	var values := touches.values()
	var steer := float(values.has("right")) - float(values.has("left"))
	controls_changed.emit(steer, float(values.has("throttle")), float(values.has("brake")), values.has("aux"))
	queue_redraw()


func _draw() -> void:
	if finished or ticket.is_empty() or touch_zones.is_empty():
		return

	var event: Dictionary = ticket.get("event", {})
	var mode: String = telemetry.get("mode", event.get("mode", "circuit"))
	_panel(Rect2(24, 24, 302, 95))
	draw_line(Vector2(33, 44), Vector2(33, 75), ACCENT, 2.0, true)
	_txt(Vector2(44, 46), MODE_NAMES.get(mode, mode.to_upper()), 12, ACCENT, number_font)
	_txt(Vector2(43, 74), str(event.get("name", "Corrida")), 23, PAPER, Ui.DISPLAY)
	if mode == "practice":
		_txt(Vector2(44, 102), "PISTA ABERTA", 14, MUTED, number_font)
	elif mode == "time_trial":
		_txt(Vector2(44, 102), "META   " + _clock(int(telemetry.get("target_ms", event.get("target_ms", 0)))), 14, MUTED, number_font)
	else:
		var status := "POS %02d/%02d" % [int(telemetry.get("position", 1)), int(telemetry.get("field_size", 1))]
		if mode in ["circuit", "championship"]:
			status += "     VOLTA %d/%d" % [int(telemetry.get("lap", 1)), int(telemetry.get("laps", 1))]
		_txt(Vector2(44, 102), status, 14, MUTED, number_font)
	if int(telemetry.get("heat_total", 1)) > 1:
		_panel(Rect2(24, 134, 185, 40))
		_txt(Vector2(38, 160), "ETAPA  %d/%d" % [int(telemetry.get("heat", 1)), int(telemetry.get("heat_total", 1))], 16, PAPER, number_font)
	elif bool(ticket.get("pink", false)):
		_panel(Rect2(24, 134, 185, 40))
		_txt(Vector2(38, 160), "APOSTA DE CARRO", 15, HOT, number_font)

	if mode != "practice":
		var right := size.x - 296.0
		_panel(Rect2(right, 22, 199, 70))
		_txt(Vector2(right + 14, 46), "TEMPO", 13, MUTED, number_font)
		_txt(Vector2(right + 14, 75), _clock(int(telemetry.get("time_ms", 0))), 25, PAPER, number_font)
	if not course.is_empty():
		_draw_map(Vector2(size.x - 160.0, 104.0))

	if mode != "practice":
		var progress := clampf(float(telemetry.get("progress", 0.0)), 0.0, 1.0)
		var progress_width := minf(300.0, size.x * 0.24)
		var progress_origin := Vector2((size.x - progress_width) * 0.5, 28.0)
		draw_line(progress_origin, progress_origin + Vector2(progress_width, 0), INK, 4.0, true)
		if progress > 0.0:
			draw_line(progress_origin, progress_origin + Vector2(progress_width * progress, 0), ACCENT, 3.0, true)

	var bottom := size.y - 118.0
	var d := Vector2(size.x * 0.5 - 115, bottom)
	_panel(Rect2(d + Vector2(0, 3), Vector2(230, 91)))
	var speed := int(roundf(absf(float(telemetry.get("speed_kmh", 0)))))
	_txt(d + Vector2(14, 64), "%03d" % speed, 46, PAPER, number_font)
	_txt(d + Vector2(108, 58), "KM/H", 12, MUTED, number_font)
	var gear := int(telemetry.get("gear", 0))
	var gear_label := "R" if gear < 0 else ("N" if gear == 0 else str(gear))
	draw_line(d + Vector2(161, 22), d + Vector2(161, 64), LINE, 1.0, true)
	_txt(d + Vector2(181, 31), "MARCHA", 9, MUTED, number_font)
	_txt(d + Vector2(189, 64), gear_label, 30, ACCENT, number_font)
	var rpm := clampf(float(telemetry.get("rpm", 0.0)), 0.0, 1.0)
	for step in 20:
		var meter_color := LINE
		if float(step) / 20.0 < rpm:
			meter_color = HOT if step >= 17 else ACCENT
		draw_rect(Rect2(d + Vector2(15 + step * 10.1, 77), Vector2(7.7, 4)), meter_color)
	if mode == "drag" and bool(telemetry.get("shift_hint", false)):
		_center_tag("TROQUE A MARCHA", bottom - 11.0, ACCENT)

	var countdown := int(telemetry.get("countdown", -1))
	if countdown >= 0:
		var countdown_label := str(countdown) if countdown > 0 else "VAI!"
		var mid := Vector2(size.x * 0.5, size.y * 0.48)
		draw_circle(mid, 63.0, INK, true, -1.0, true)
		draw_arc(mid, 63.0, 0, TAU, 56, LINE, 1.4, true)
		var arc := float(4 - countdown) / 4.0
		draw_arc(mid, 63.0, -PI * 0.5, -PI * 0.5 + TAU * arc, 48, ACCENT, 2.0, true)
		_center_text(countdown_label, mid.y + 19.0, 57 if countdown > 0 else 43, ACCENT, Ui.DISPLAY)
	elif mode != "practice" and bool(telemetry.get("wrong_way", false)):
		_center_tag("SENTIDO CONTRÁRIO", 139.0, HOT)
	elif bool(telemetry.get("off_track", false)):
		_center_tag("FORA DO ASFALTO", 139.0, PAPER)

	if show_touch:
		_draw_touch(mode)
	elif not paused:
		var controls := "WASD OU SETAS   •   ESPAÇO  %s   •   ESC  PAUSA" % (
			"TROCA DE MARCHA" if mode == "drag" else "FREIO DE MÃO")
		_txt(Vector2(25.0, size.y - 27.0), controls, 12, PAPER, number_font)


func _draw_map(at: Vector2) -> void:
	_panel(Rect2(at, Vector2(134.0, 129.0)))
	var origin := at + Vector2(13, 11)
	var scale_map := 107.0
	var points := PackedVector2Array()
	for point in course:
		points.append(origin + point * scale_map)
	if points.size() < 2:
		return
	draw_polyline(points, LINE, 4.6, true)
	draw_polyline(points, MUTED, 1.35, true)
	draw_circle(points[0], 3.0, PAPER, true, -1, true)
	for point in telemetry.get("map_rivals", PackedVector2Array()):
		draw_circle(origin + point * scale_map, 3.4, HOT, true, -1, true)
	var player: Vector2 = telemetry.get("map_position", course[0])
	draw_circle(origin + player * scale_map, 4.9, ACCENT, true, -1, true)


func _draw_touch(mode: String) -> void:
	var labels := {"brake": "FREIO", "aux": "MARCHA" if mode == "drag" else "MÃO", "throttle": "GÁS"}
	var pressed := touches.values()
	for key in TOUCH_KEYS:
		var zone: Rect2 = touch_zones[key]
		var on := pressed.has(key)
		var primary: bool = key == "throttle"
		var style := (_pedal_primary_down if on else _pedal_primary) if primary else (_pedal_down if on else _pedal)
		var ink_color := Ui.INK if on else (ACCENT if primary else PAPER)
		draw_style_box(style, zone.grow(-3.0))
		if key in ["left", "right"]:
			var direction := -1.0 if key == "left" else 1.0
			var center := zone.get_center()
			draw_polyline(PackedVector2Array([
				center + Vector2(-direction * 6, -12), center + Vector2(direction * 6, 0),
				center + Vector2(-direction * 6, 12),
			]), ink_color, 2.4, true)
			continue
		var font_size := 20 if primary else 13
		var word: String = labels[key]
		var word_width := Ui.DISPLAY.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := zone.get_center() + Vector2(-word_width * 0.5, font_size * 0.34)
		_txt(baseline, word, font_size, ink_color, Ui.DISPLAY)


func _panel(rect: Rect2, edge: Color = LINE) -> void:
	if not _panel_styles.has(edge):
		_panel_styles[edge] = Ui.box(INK, edge, 1, 9)
	draw_style_box(_panel_styles[edge], rect)


func _txt(at: Vector2, value: String, font_size: int, color: Color = PAPER, font: Font = null) -> void:
	draw_string(text_font if font == null else font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _center_text(value: String, y: float, font_size: int, color: Color, font: Font) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_txt(Vector2((size.x - width) * 0.5, y), value, font_size, color, font)


func _center_tag(value: String, y: float, color: Color) -> void:
	var width := number_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 32
	_panel(Rect2((size.x - width) * 0.5, y - 28, width, 38), color)
	_center_text(value, y - 3, 17, color, number_font)


func _clock(ms: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]


func request_pause() -> void:
	if not paused and not finished:
		_toggle_pause()


func _toggle_pause() -> void:
	if finished:
		return
	paused = not paused
	touches.clear()
	_emit_touch()
	pause_changed.emit(paused)
	pause_button.visible = not paused
	if paused:
		confirming_withdrawal = false
		_show_pause()
	else:
		_remove_modal()


func _show_pause() -> void:
	var column := _sheet()
	var practice := str(ticket.event.get("mode", "")) == "practice"
	if confirming_withdrawal:
		column.add_child(_label("Desistir da corrida?", 35, PAPER))
		var text := "Sua desistência será registrada como abandono."
		if bool(ticket.get("pink", false)):
			text += " O carro apostado será entregue ao adversário."
		elif int(ticket.get("wager", 0)) > 0:
			text += " Você perderá a aposta."
		_body(column, text)
		column.add_child(_button("Continuar na corrida", _toggle_pause, true))
		column.add_child(_button("Confirmar desistência", func() -> void: withdraw_requested.emit(), false))
		return
	column.add_child(_label("Treino pausado" if practice else "Corrida pausada", 35, PAPER))
	column.add_child(_button("Continuar", _toggle_pause, true))
	column.add_child(_button("Reposicionar o carro", _reset_and_resume, false))
	column.add_child(_button("Trocar câmera", func() -> void: camera_requested.emit(), false))
	if practice:
		column.add_child(_button("Voltar ao paddock", func() -> void: return_requested.emit(), false))
	else:
		column.add_child(_button("Desistir…", _ask_withdraw, false))


func _reset_and_resume() -> void:
	reset_requested.emit()
	_toggle_pause()


func _ask_withdraw() -> void:
	confirming_withdrawal = true
	_show_pause()


func show_results(result: Dictionary, receipt: Dictionary) -> void:
	finished = true
	paused = false
	touches.clear()
	_emit_touch()
	pause_button.hide()
	queue_redraw()
	var column := _sheet()
	var won := bool(result.get("won", false))
	var completed := bool(result.get("completed", false))
	column.add_child(_label("RESULTADO", 15, ACCENT))
	var headline := "Vitória" if won else ("Bandeirada" if completed else "Corrida encerrada")
	column.add_child(_label(headline, 46, PAPER))
	var position := int(result.get("position", 0))
	var metrics := _clock(int(result.get("time_ms", 0)))
	if completed and position > 0 and str(result.get("mode", "")) != "time_trial":
		metrics = "%dº lugar  ·  %s" % [position, metrics]
	column.add_child(_label(metrics, 23, MUTED))
	var summary := str(receipt.get("message", "Resultado registrado."))
	_body(column, summary)
	if not receipt.get("ok", false):
		column.add_child(_button("Tentar salvar novamente", func() -> void: retry_requested.emit(), true))
		return
	var net := int(receipt.get("net", 0))
	var reputation := int(receipt.get("rep", 0))
	if net != 0 or reputation > 0:
		var gains := "Cr %+d" % net
		if reputation > 0:
			gains += "  ·  %+d reputação" % reputation
		column.add_child(_label(gains, 21, ACCENT if net >= 0 else HOT))
	column.add_child(_button("Voltar aos setores", func() -> void: return_requested.emit(), true))


func _body(column: VBoxContainer, value: String) -> void:
	var description := _label(value, 19, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)


func _label(value: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size_px)
	return label


func _sheet() -> VBoxContainer:
	_remove_modal()
	modal = ColorRect.new()
	modal.color = Color(0.019, 0.026, 0.027, 0.79)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(size.x - 50, 478), 0)
	var background := _style(INK, LINE)
	background.set_content_margin_all(27)
	background.border_width_top = 3
	background.border_color = ACCENT
	panel.add_theme_stylebox_override("panel", background)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	panel.add_child(column)
	return column


func _remove_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
		modal = null


func _button(label: String, action: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 53
	button.add_theme_font_size_override("font_size", 18)
	var fill := ACCENT if primary else INK
	var border := ACCENT if primary else LINE
	button.add_theme_stylebox_override("normal", _style(fill, border))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.13), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.2), PAPER))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, ACCENT))
	var font_color := INK if primary else PAPER
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_key, font_color)
	button.pressed.connect(action)
	return button


func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	return Ui.box(fill, edge, 1, 9, 11, 11)
