extends Control
## A small map HUD with independent movement and camera touches.

signal movement_changed(vector: Vector2)
signal looked(delta: Vector2)
signal interact_pressed
signal settings_pressed

const Ui = preload("res://src/ui/ui_kit.gd")
const INK := Color(0.05, 0.08, 0.10, 0.91)
const STROKE := Color(0.24, 0.32, 0.34, 0.92)
const JOYSTICK_RADIUS := 55.0

var action_button: Button
var settings_button: Button
var stick_center := Vector2.ZERO
var show_touch := false

var _sector_name := ""
var _money := 0
var _rep := 0
var _target_title := ""
var _action := ""
var _blocked := false
var _move_finger := -1
var _look_finger := -1
var _command_finger := -1
var _command_button: Button
var _mouse_looking := false
var _move_vector := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Ui.skin()
	show_touch = OS.has_feature("mobile") or "--touch-controls" in OS.get_cmdline_user_args()
	action_button = Ui.button("", true, 58)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(func() -> void: interact_pressed.emit())
	add_child(action_button)
	settings_button = Ui.button("")
	settings_button.tooltip_text = "Configurações · Esc"
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings_button)
	var gear := Ui.glyph("gear", 24)
	settings_button.add_child(gear)
	gear.set_anchors_preset(Control.PRESET_CENTER)
	gear.offset_left = -12
	gear.offset_top = -12
	gear.offset_right = 12
	gear.offset_bottom = 12
	resized.connect(_layout)
	_layout()
	set_context("", "")


func set_location(place: String) -> void:
	_sector_name = place
	queue_redraw()


func set_account(credits: int, reputation: int) -> void:
	_money = credits
	_rep = reputation
	queue_redraw()


func set_context(title: String, action: String) -> void:
	if _target_title == title and _action == action and action_button.visible == (not _blocked and not action.is_empty()):
		return
	_target_title = title
	_action = action
	action_button.text = action if show_touch else "E    " + action
	action_button.visible = not _blocked and not action.is_empty()
	queue_redraw()


func block_input(blocked: bool) -> void:
	_blocked = blocked
	clear_input()
	action_button.visible = not blocked and not _action.is_empty()
	settings_button.visible = not blocked
	queue_redraw()


func clear_input() -> void:
	_move_finger = -1
	_look_finger = -1
	_command_finger = -1
	_command_button = null
	_mouse_looking = false
	_set_stick(Vector2.ZERO)


func _layout() -> void:
	stick_center = Vector2(105, size.y - 103)
	action_button.position = Vector2(size.x - 294, size.y - 89)
	action_button.size = Vector2(269, 58)
	settings_button.position = Vector2(size.x - 81, 26)
	settings_button.size = Vector2(56, 54)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _blocked or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if not show_touch:
			show_touch = true
			action_button.text = _action
			queue_redraw()
		if _screen_touch(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _move_finger:
			_stick_at(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == _look_finger:
			looked.emit(event.relative)
			get_viewport().set_input_as_handled()
		elif event.index == _command_finger:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_looking = event.pressed
			get_viewport().set_input_as_handled()
		elif show_touch and event.button_index == MOUSE_BUTTON_LEFT:
			var on_stick: bool = event.position.distance_to(stick_center) < JOYSTICK_RADIUS + 23.0
			if event.pressed and on_stick:
				_move_finger = -2
				_stick_at(event.position)
				get_viewport().set_input_as_handled()
			elif not event.pressed and _move_finger == -2:
				_move_finger = -1
				_set_stick(Vector2.ZERO)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_looking:
			looked.emit(event.relative)
			get_viewport().set_input_as_handled()
		elif _move_finger == -2:
			_stick_at(event.position)
			get_viewport().set_input_as_handled()


func _screen_touch(event: InputEventScreenTouch) -> bool:
	if not event.pressed or event.canceled:
		if event.index == _move_finger:
			_move_finger = -1
			_set_stick(Vector2.ZERO)
			return true
		if event.index == _look_finger:
			_look_finger = -1
			return true
		if event.index == _command_finger:
			var button := _command_button
			_command_finger = -1
			_command_button = null
			if not event.canceled and is_instance_valid(button) and button.visible and button.get_global_rect().has_point(event.position):
				button.pressed.emit()
			return true
		return false

	for button in [action_button, settings_button]:
		if _command_finger < 0 and button.visible and button.get_global_rect().has_point(event.position):
			_command_finger = event.index
			_command_button = button
			return true
	if _move_finger < 0 and event.position.distance_to(stick_center) < JOYSTICK_RADIUS + 24.0:
		_move_finger = event.index
		_stick_at(event.position)
		return true
	if _look_finger < 0 and event.position.x > size.x * 0.5 and event.position.y > 89:
		_look_finger = event.index
		return true
	return false


func _stick_at(at: Vector2) -> void:
	var strength := ((at - stick_center) / JOYSTICK_RADIUS).limit_length(1.0)
	_set_stick(strength if strength.length_squared() > 0.011 else Vector2.ZERO)


func _set_stick(value: Vector2) -> void:
	_move_vector = value
	movement_changed.emit(value)
	queue_redraw()


func _draw() -> void:
	if _blocked or size.x < 100:
		return
	var label_width := maxf(211, Ui.DISPLAY.get_string_size(_sector_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x + 37)
	_card(Rect2(24, 24, label_width, 72), Ui.ACID)
	_text(Vector2(42, 50), "BAÍA DO SAL", 12, Ui.ACID, Ui.MONO)
	_text(Vector2(41, 80), _sector_name, 29, Ui.PAPER, Ui.DISPLAY)
	var credits := Ui.money(_money)
	var account_width := maxf(205, Ui.DISPLAY.get_string_size(credits, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 112)
	var at := Vector2(size.x - 93 - account_width, 26)
	_card(Rect2(at, Vector2(account_width, 54)), STROKE)
	_text(at + Vector2(12, 20), "CAIXA", 10, Ui.MUTE, Ui.MONO)
	_text(at + Vector2(12, 43), credits, 22, Ui.PAPER, Ui.DISPLAY)
	_text(at + Vector2(account_width - 74, 20), "RESPEITO", 10, Ui.MUTE, Ui.MONO)
	_text(at + Vector2(account_width - 74, 43), "%03d" % _rep, 20, Ui.ACID, Ui.DISPLAY)

	if show_touch:
		draw_circle(stick_center, JOYSTICK_RADIUS + 5.0, Color(0.045, 0.073, 0.079, 0.74), true, -1, true)
		draw_circle(stick_center, JOYSTICK_RADIUS + 5.0, STROKE.lightened(0.14), false, 1.5, true)
		var thumb := stick_center + _move_vector * JOYSTICK_RADIUS * 0.67
		draw_circle(thumb, 23, Ui.ACID if _move_vector.length_squared() > 0.01 else Color(0.38, 0.47, 0.45, 0.8), true, -1, true)
		_text(stick_center + Vector2(-21, 82), "MOVER", 13, Ui.PAPER, Ui.MONO)
		if _target_title.is_empty():
			_text(Vector2(size.x - 224, size.y - 41), "ARRASTE PARA OLHAR", 14, Ui.PAPER, Ui.MONO)
	else:
		var instructions := "WASD OU SETAS  ·  ANDAR     BOTÃO DIREITO  ·  OLHAR"
		var width := Ui.MONO.get_string_size(instructions, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 26.0
		_card(Rect2(24, size.y - 64, width, 40), STROKE)
		_text(Vector2(37, size.y - 39), instructions, 13, Ui.PAPER, Ui.MONO)

	if not _target_title.is_empty():
		var target_box := Rect2(size.x - 294, size.y - 139, 269, 44)
		_card(target_box, STROKE)
		_text(target_box.position + Vector2(14, 28), _target_title, 17, Ui.PAPER, Ui.BODY, 242)


func _card(rect: Rect2, edge: Color) -> void:
	draw_rect(rect, INK)
	draw_rect(rect, edge, false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(24, 2)), edge)


func _text(at: Vector2, words: String, font_size: int, tint: Color, font: Font, width: int = -1) -> void:
	draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, tint)
